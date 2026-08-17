(*********************************************************************************)
(*  central - Manage history between sub-repos and their monorepo                *)
(*  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*  SPDX-License-Identifier: MIT                                                 *)
(*********************************************************************************)

let main =
  Command.make
    ~summary:"Advance a subrepo's subrepo & main branches to the monorepo's commit."
    ~readme:(fun () ->
      "This command may occasionally be useful when moving from one computer to another. \
       By pulling the $(b,main) branch of the monorepo, you'll effectively access the \
       knowledge of where the $(b,subrepo) branches must point to in each subrepo. This \
       information is read from the $(b,.gitrepo) files.\n\n\
       This command advances both the $(b,main) and $(b,subrepo) branches in the \
       subrepos to these revisions (assuming such an update hasn't been done in a while \
       on that particular computer).")
    (let open Command.Std in
     let+ () = Log_cli.set_config ()
     and+ force = Arg.flag [ "force" ] ~doc:"Force advance even if not applicable."
     and+ which_subrepos = Which_repos.Subrepos.arg in
     let vcs = Volgo_git_unix.create () in
     let cwd = Unix.getcwd () |> Absolute_path.v in
     let central_root = Common_helpers.find_enclosing_repo_root vcs ~from:cwd in
     let central_graph = Vcs.graph vcs ~repo_root:central_root in
     let compute_facts ~subrepo =
       Subrepo_facts.compute ~vcs ~central_root ~central_graph ~subrepo
     in
     let subrepos = Which_repos.Subrepos.resolve which_subrepos ~repo_root:central_root in
     Which_repos.Subrepos.iter subrepos ~f:(fun subrepo ->
       let facts = compute_facts ~subrepo in
       let is_applicable =
         Central.Next_step.is_applicable
           Advance_subrepo
           ~facts:(Subrepo_facts.next_step_facts facts)
       in
       if not (is_applicable || force)
       then Central_log.skip_step Advance_subrepo
       else (
         let gitrepo_rev = (Subrepo_facts.gitrepo_file facts).commit.txt in
         let () =
           Vcs.git
             vcs
             ~repo_root:(Subrepo_facts.subrepo_repo_root facts)
             ~args:[ "checkout"; "subrepo" ]
             ~f:Vcs.Git.exit0
         in
         let output =
           Vcs.git
             vcs
             ~repo_root:(Subrepo_facts.subrepo_repo_root facts)
             ~args:[ "merge"; "--ff-only"; Vcs.Rev.to_string gitrepo_rev ]
             ~f:Vcs.Git.exit0_and_stdout
         in
         print_string output;
         let () =
           Vcs.git
             vcs
             ~repo_root:(Subrepo_facts.subrepo_repo_root facts)
             ~args:[ "checkout"; "main" ]
             ~f:Vcs.Git.exit0
         in
         (* And we advance main as well if applicable. *)
         let facts = compute_facts ~subrepo in
         let is_applicable =
           Central.Next_step.is_applicable
             Advance_main
             ~facts:(Subrepo_facts.next_step_facts facts)
         in
         if not is_applicable
         then Central_log.skip_step Advance_main
         else (
           let output =
             Vcs.git
               vcs
               ~repo_root:(Subrepo_facts.subrepo_repo_root facts)
               ~args:[ "merge"; "--ff-only"; "subrepo" ]
               ~f:Vcs.Git.exit0_and_stdout
           in
           print_string output))))
;;
