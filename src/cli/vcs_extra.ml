(*********************************************************************************)
(*  central - Manage history between sub-repos and their monorepo                *)
(*  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*  SPDX-License-Identifier: MIT                                                 *)
(*********************************************************************************)

(* This is a trimmed copy of a [vcs_extra] library maintained elsewhere by
   the same author, relicensed here as MIT. See vcs_extra.mli. *)

let branch_tracking vcs ~repo_root ~branch_name =
  Vcs.Result.git
    vcs
    ~repo_root
    ~args:
      [ "rev-parse"
      ; "--abbrev-ref"
      ; "--symbolic-full-name"
      ; Printf.sprintf "%s@{u}" (Vcs.Branch_name.to_string branch_name)
      ]
    ~f:(fun output ->
      Result.bind
        (Vcs.Git.Result.exit_code output ~accept:[ 0, `Tracking; 128, `No_tracking ])
        (function
          | `No_tracking -> Ok None
          | `Tracking ->
            (match Vcs.Remote_branch_name.of_string (String.strip output.stdout) with
             | Ok ok -> Ok (Some ok)
             | Error (`Msg m) -> Error (Err.create [ Pp.verbatim m ]))))
;;

let branch_tracking_opt_exn vcs ~repo_root ~branch_name =
  match branch_tracking vcs ~repo_root ~branch_name with
  | Ok info -> info
  | Error err ->
    Err.raise
      Pp.O.
        [ Pp.text "Error computing remote tracking information for "
          ++ Pp_tty.kwd (module Vcs.Branch_name) branch_name
          ++ Pp.text "."
        ; Err.dyn (err |> Err.to_dyn)
        ; Pp.text "Repo: " ++ Pp_tty.path (module Vcs.Repo_root) repo_root
        ]
;;

let branch_tracking_exn vcs ~repo_root ~branch_name =
  match branch_tracking_opt_exn vcs ~repo_root ~branch_name with
  | Some remote -> remote
  | None ->
    Err.raise
      Pp.O.
        [ Pp.text "No remote tracking information for "
          ++ Pp_tty.kwd (module Vcs.Branch_name) branch_name
          ++ Pp.text "."
        ; Pp.text "Repo: " ++ Pp_tty.path (module Vcs.Repo_root) repo_root
        ]
      ~hints:
        [ Pp.text "Tracking information was obtained with:"
        ; Pp_tty.simple_quotes
            (Pp.verbatim
               (Printf.sprintf
                  "git rev-parse --abbrev-ref --symbolic-full-name %s@{u}"
                  (Vcs.Branch_name.to_string branch_name)))
        ; Pp.text "You may set it using:"
        ; Pp_tty.simple_quotes
            (Pp.verbatim
               (Printf.sprintf
                  "git branch --set-upstream-to=<remote>/<branch> %s"
                  (Vcs.Branch_name.to_string branch_name)))
        ]
;;

let find_local_branch_exn ~repo_root ~graph ~branch_name =
  match Vcs.Graph.find_ref graph ~ref_kind:(Local_branch { branch_name }) with
  | Some node -> node
  | None ->
    Err.raise
      Pp.O.
        [ Pp.text "Cannot find branch "
          ++ Pp_tty.kwd (module Vcs.Branch_name) branch_name
          ++ Pp.text " in "
          ++ Pp_tty.path (module Vcs.Repo_root) repo_root
          ++ Pp.text "."
        ]
;;

let find_remote_tracking_node_exn vcs ~repo_root ~graph ~branch_name =
  let remote_branch_name = branch_tracking_exn vcs ~repo_root ~branch_name in
  match Vcs.Graph.find_ref graph ~ref_kind:(Remote_branch { remote_branch_name }) with
  | Some node -> node
  | None ->
    Err.raise
      Pp.O.
        [ Pp.text "Cannot find remote tracking branch "
          ++ Pp_tty.kwd (module Vcs.Remote_branch_name) remote_branch_name
          ++ Pp.text " in "
          ++ Pp_tty.path (module Vcs.Repo_root) repo_root
          ++ Pp.text "."
        ]
;;
