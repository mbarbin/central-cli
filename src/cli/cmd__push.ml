(*********************************************************************************)
(*  central - Manage history between sub-repos and their monorepo                *)
(*  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*  SPDX-License-Identifier: MIT                                                 *)
(*********************************************************************************)

(* Opens [gitk --all] in [repo_root] so the person confirming the push can
   see what's actually about to go out before answering the prompt (or, in
   [Dry_run] mode, before the run is skipped anyway) - skipped entirely in
   [Yes] mode, where nobody is watching. *)
let visualize_with_gitk ~repo_root =
  App_log.status
    Pp.O.(
      Pp.text "Visualizing the history of the repository with "
      ++ Pp_tty.kwd (module String) "gitk"
      ++ Pp.text ".");
  let prog = "gitk" in
  let argv = [ "gitk"; "--all" ] in
  let cwd = Spawn.Working_dir.Path (Vcs.Repo_root.to_string repo_root) in
  try
    let prog = Common_helpers.resolve_in_path ~prog in
    let pid = Spawn.spawn ~prog ~argv ~cwd () in
    match Unix.waitpid [] pid with
    | _, WEXITED 0 -> ()
    | _ ->
      Err.raise
        Pp.O.
          [ Pp.text "Running process "
            ++ Pp_tty.kwd (module String) "gitk"
            ++ Pp.text " failed."
          ]
  with
  | exn ->
    Err.raise
      Pp.O.
        [ Pp.text "Running process "
          ++ Pp_tty.kwd (module String) "gitk"
          ++ Pp.text " failed."
        ; Err.exn exn
        ]
;;

let push ~vcs ~repo_root ~is_applicable ~force ~confirm_mode =
  if not (is_applicable || force)
  then Central_log.skip_step Push
  else (
    (match (confirm_mode : Prompt.Confirm_mode.t) with
     | Yes -> ()
     | Interactive | Dry_run -> visualize_with_gitk ~repo_root);
    let remote =
      Vcs_extra.branch_tracking_exn vcs ~repo_root ~branch_name:Vcs.Branch_name.main
    in
    let confirmed =
      match (confirm_mode : Prompt.Confirm_mode.t) with
      | Yes -> true
      | Dry_run ->
        App_log.skip (Pp.text "Push skipped (dry-run).");
        false
      | Interactive ->
        Prompt.ask_yn
          ~prompt:
            (Printf.sprintf
               "Confirming push to %s/main in %s?"
               (Prompt.styled Loc (Vcs.Remote_name.to_string remote.remote_name))
               (Prompt.styled Loc (Vcs.Repo_root.to_string repo_root)))
          ~default:(Some false)
    in
    if not confirmed
    then (
      match confirm_mode with
      | Dry_run -> ()
      | Interactive -> App_log.skip (Pp.text "Push not confirmed.")
      | Yes -> assert false (* unreachable *))
    else (
      let output =
        Vcs.git
          vcs
          ~repo_root
          ~args:[ "push"; Vcs.Remote_name.to_string remote.remote_name; "main" ]
          ~f:Vcs.Git.exit0_and_stdout
      in
      print_string output;
      App_log.success (Pp.text "Pushed.")))
;;

let main =
  Command.make
    ~summary:"Push repo(s) to remote."
    (let open Command.Std in
     let+ () = Log_cli.set_config ()
     and+ force = Arg.flag [ "force" ] ~doc:"Force the push."
     and+ which_repos = Which_repos.arg ~default_to_central:false
     and+ confirm_mode = Prompt.Confirm_mode.arg in
     let vcs = Volgo_git_unix.create () in
     let cwd = Unix.getcwd () |> Absolute_path.v in
     let central_root = Common_helpers.find_enclosing_repo_root vcs ~from:cwd in
     let repo_config = Central.Repo_config.find_and_load ~repo_root:central_root in
     let central_graph = Vcs.graph vcs ~repo_root:central_root in
     let central_main_head =
       Vcs_extra.find_local_branch_exn
         ~repo_root:central_root
         ~graph:central_graph
         ~branch_name:Vcs.Branch_name.main
     in
     let central_remote_main_head =
       Vcs_extra.find_remote_tracking_node_exn
         vcs
         ~repo_root:central_root
         ~graph:central_graph
         ~branch_name:Vcs.Branch_name.main
     in
     let repos = Which_repos.resolve which_repos ~repo_config ~repo_root:central_root in
     Which_repos.iter repos ~repo_config ~f:(fun repo ->
       match (repo : Which_repos.repo) with
       | Central ->
         let is_applicable =
           Vcs.Graph.is_strict_ancestor
             central_graph
             ~ancestor:central_remote_main_head
             ~descendant:central_main_head
         in
         push ~vcs ~repo_root:central_root ~is_applicable ~force ~confirm_mode
       | Subrepo subrepo ->
         let facts = Subrepo_facts.compute ~vcs ~central_root ~central_graph ~subrepo in
         let is_applicable =
           Central.Next_step.is_applicable
             Push
             ~facts:(Subrepo_facts.next_step_facts facts)
         in
         push
           ~vcs
           ~repo_root:(Subrepo_facts.subrepo_repo_root facts)
           ~is_applicable
           ~force
           ~confirm_mode))
;;
