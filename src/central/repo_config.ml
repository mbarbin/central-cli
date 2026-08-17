(*********************************************************************************)
(*  central - Manage history between sub-repos and their monorepo                *)
(*  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*  SPDX-License-Identifier: MIT                                                 *)
(*********************************************************************************)

type t = { root_repo_name : string }

let root_repo_name t = t.root_repo_name
let default = { root_repo_name = "central" }
let create ?(root_repo_name = default.root_repo_name) () = { root_repo_name }
let to_json t : Json.t = `Assoc [ "rootRepoName", `String t.root_repo_name ]
let path_in_repo = Vcs.Path_in_repo.v ".central/repo-config.json"

let of_json json ~loc : t =
  match (json : Json.t) with
  | `Assoc fields ->
    let root_repo_name_ref = ref None in
    List.iter fields ~f:(fun (field_name, value) ->
      match field_name with
      | "$schema" ->
        (* This allows [$schema] to be present without causing an error. *)
        ()
      | "rootRepoName" ->
        (match value with
         | `String s -> root_repo_name_ref := Some s
         | _ ->
           Err.raise
             ~loc
             [ Pp.text "Field \"rootRepoName\" expected to be a json string." ])
      | _ -> Err.raise ~loc [ Pp.textf "Unknown config field \"%s\"." field_name ]);
    { root_repo_name = Option.value !root_repo_name_ref ~default:default.root_repo_name }
  | _ -> Err.raise ~loc [ Pp.text "Config expected to be a json object." ]
;;

let load_exn ~path =
  let loc = Loc.of_file ~path in
  match Yojson.Basic.from_file (Fpath.to_string path) with
  | json -> of_json json ~loc
  | exception Yojson.Json_error msg ->
    Err.raise ~loc [ Pp.text "Not a valid json file."; Pp.text msg ]
;;

let find_and_load ~repo_root =
  let path = (Vcs.Repo_root.append repo_root path_in_repo :> Fpath.t) in
  if Sys.file_exists (Fpath.to_string path) then load_exn ~path else default
;;
