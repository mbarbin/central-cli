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

(* [Central_test_harness] sets this env var, around the [central] subprocess
   it spawns for expect tests, to the same placeholder it otherwise
   substitutes into raw output after the fact (e.g. ["$CENTRAL_ROOT"]).
   Substituting it here, before formatting, rather than relying solely on
   that post-hoc raw-text substitution, keeps messages built from
   [repo_root] from word-wrapping differently depending on the real (and
   platform-dependent - e.g. macOS's much longer [$TMPDIR]) length of the
   path: the placeholder is always short, so the surrounding sentence always
   fits on one line regardless of where the test happens to run. *)
let repo_root_env_var_for_test = "CENTRAL_TEST_REPO_ROOT"

let repo_root_for_display repo_root =
  match Sys.getenv_opt repo_root_env_var_for_test with
  | Some placeholder -> placeholder
  | None -> Vcs.Repo_root.to_string repo_root
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
        [ Pp.text "Repo "
          ++ Pp_tty.path (module String) (repo_root_for_display repo_root)
          ++ Pp.text " has uncommitted changes."
        ; Pp.verbatim status
        ]
      ~hints:[ Pp.text "Commit or stash them first." ]
;;
