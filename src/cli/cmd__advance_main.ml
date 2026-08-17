(*********************************************************************************)
(*  central - Manage history between sub-repos and their monorepo                *)
(*  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*  SPDX-License-Identifier: MIT                                                 *)
(*********************************************************************************)

let main =
  Command.make
    ~summary:"Advance a subrepo's main branch to its subrepo branch."
    ~readme:(fun () ->
      "After having exported to the $(b,subrepo) branch, the $(b,main) branch is \
       typically behind, as a strict ancestor. This command checks out $(b,main), then \
       fast-forwards it to the revision the $(b,subrepo) branch is at.\n\n\
       This fails if $(b,main) is not an ancestor of $(b,subrepo).")
    (let open Command.Std in
     let+ () = Log_cli.set_config ()
     and+ force =
       Arg.flag
         [ "force" ]
         ~doc:
           "By default, this command only proceeds if the next step for the given \
            subrepo is advance-main (and does nothing otherwise). Pass this flag to \
            force advancing main even when this isn't the immediate next step."
     and+ which_subrepos = Which_repos.Subrepos.arg in
     let vcs = Volgo_git_unix.create () in
     let cwd = Unix.getcwd () |> Absolute_path.v in
     let central_root = Common_helpers.find_enclosing_repo_root vcs ~from:cwd in
     let central_graph = Vcs.graph vcs ~repo_root:central_root in
     let subrepos = Which_repos.Subrepos.resolve which_subrepos ~repo_root:central_root in
     Which_repos.Subrepos.iter subrepos ~f:(fun subrepo ->
       let facts = Subrepo_facts.compute ~vcs ~central_root ~central_graph ~subrepo in
       let is_applicable =
         Central.Next_step.is_applicable
           Advance_main
           ~facts:(Subrepo_facts.next_step_facts facts)
       in
       if is_applicable || force
       then (
         let () =
           Vcs.git
             vcs
             ~repo_root:(Subrepo_facts.subrepo_repo_root facts)
             ~args:[ "checkout"; "main" ]
             ~f:Vcs.Git.exit0
         in
         let output =
           Vcs.git
             vcs
             ~repo_root:(Subrepo_facts.subrepo_repo_root facts)
             ~args:[ "merge"; "--ff-only"; "subrepo" ]
             ~f:Vcs.Git.exit0_and_stdout
         in
         print_string output)
       else Central_log.skip_step Advance_main))
;;
