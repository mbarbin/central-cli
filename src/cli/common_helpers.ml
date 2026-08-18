(*********************************************************************************)
(*  central - Manage history between sub-repos and their monorepo                *)
(*  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*  SPDX-License-Identifier: MIT                                                 *)
(*********************************************************************************)

let find_enclosing_repo_root vcs ~from =
  match Vcs.find_enclosing_git_repo_root vcs ~from with
  | Some repo_root -> repo_root
  | None ->
    Err.raise
      Pp.O.
        [ Pp.text "Failed to locate enclosing repo root from '"
          ++ Pp_tty.path (module Absolute_path) from
          ++ Pp.text "'."
        ]
;;

let resolve_in_path ~prog =
  if Filename.is_relative prog
  then (
    let path =
      match Sys.getenv_opt "PATH" with
      | Some p -> Stdlib.String.split_on_char ':' p
      | None -> []
    in
    match
      List.find_map path ~f:(fun dir ->
        let candidate = Filename.concat dir prog in
        if Sys.file_exists candidate then Some candidate else None)
    with
    | Some resolved -> resolved
    | None -> prog)
  else prog
;;

let ensure_clean_working_tree ~vcs ~repo_root =
  let status =
    Vcs.git vcs ~repo_root ~args:[ "status"; "--porcelain" ] ~f:Vcs.Git.exit0_and_stdout
    |> String.strip
  in
  if not (String.equal status "")
  then
    Err.raise
      Pp.O.
        [ Pp.hbox
            (Pp.text "Repo "
             ++ Pp_tty.path (module String) (Vcs.Repo_root.to_string repo_root)
             ++ Pp.text " has uncommitted changes.")
        ; Pp.verbatim status
        ]
      ~hints:[ Pp.text "Commit or stash them first." ]
;;
