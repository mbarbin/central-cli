(*********************************************************************************)
(*  central - Manage history between sub-repos and their monorepo                *)
(*  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*  SPDX-License-Identifier: MIT                                                 *)
(*********************************************************************************)

type t = unit

let create () = ()
let to_json (() : t) : Json.t = `Assoc []
let xdg = lazy (Xdg.create ~env:Stdlib.Sys.getenv_opt ())

let config_path =
  lazy
    (let config_dir = Xdg.config_dir (Lazy.force xdg) in
     Fpath.(v config_dir / "central" / "user-config.json"))
;;

let of_json json ~loc : t =
  match (json : Json.t) with
  | `Assoc fields ->
    List.iter fields ~f:(fun (field_name, _) ->
      match field_name with
      | "$schema" ->
        (* This allows [$schema] to be present without causing an error. *)
        ()
      | _ -> Err.raise ~loc [ Pp.textf "Unknown config field \"%s\"." field_name ])
  | _ -> Err.raise ~loc [ Pp.text "Config expected to be a json object." ]
;;

let load_exn ~path =
  let loc = Loc.of_file ~path in
  match Yojson.Basic.from_file (Fpath.to_string path) with
  | json -> of_json json ~loc
  | exception Yojson.Json_error msg ->
    Err.raise ~loc [ Pp.text "Not a valid json file."; Pp.text msg ]
;;

let default =
  lazy
    (let path = Lazy.force config_path in
     if Sys.file_exists (Fpath.to_string path) then load_exn ~path else create ())
;;
