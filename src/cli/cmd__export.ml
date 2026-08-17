(*********************************************************************************)
(*  central - Manage history between sub-repos and their monorepo                *)
(*  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*  SPDX-License-Identifier: MIT                                                 *)
(*********************************************************************************)

(* This command computes the diff of everything that changed under the
   subrepo's directory in the monorepo since the last sync recorded in its
   [.gitrepo] file, strips the directory path prefix, and applies the result
   as a single new commit onto the subrepo's [subrepo] branch, in the
   subrepo repository itself.

   This deliberately squashes the whole range into a single commit rather
   than replaying central's commits one by one - the caller supplies the
   commit message to use with [-m]. *)

(* [is_applicable] ties this guard to the same [Next_step.Export] predicate
   that drives [next_step] - the two failure cases below are just its two
   ways of being [false], spelled out with a specific, actionable message
   instead of a generic "not applicable". [--force] lets the caller push
   through the "branch moved" case at their own risk; there is no forcing an
   empty export, so that case stays a hard error below regardless (see the
   diff-emptiness check in [export]). *)
let verify_applicable ~subrepo ~subrepo_dir ~force facts =
  let next_step_facts = Subrepo_facts.next_step_facts facts in
  let is_applicable = Central.Next_step.is_applicable Export ~facts:next_step_facts in
  if is_applicable || force
  then ()
  else (
    match next_step_facts.subrepo_head_status with
    | Central_gitrepo_rev_compared_to_subrepo_head { descendance = Same_node } ->
      Err.raise
        Pp.O.
          [ Pp.text "Nothing to export: no changes under "
            ++ Pp_tty.path (module String) subrepo_dir
            ++ Pp.text " since the last sync."
          ]
    | Central_gitrepo_rev_compared_to_subrepo_head
        { descendance = Strict_ancestor | Strict_descendant | Other }
    | Unknown_central_gitrepo_rev ->
      Err.raise
        Pp.O.
          [ Pp.text "The "
            ++ Pp_tty.kwd (module String) "subrepo"
            ++ Pp.text " branch of "
            ++ Pp_tty.id (module Central.Subrepo) subrepo
            ++ Pp.text " has moved since the last sync recorded in "
            ++ Pp_tty.kwd (module String) ".gitrepo"
            ++ Pp.text "."
          ]
        ~hints:
          Pp.O.
            [ Pp.text "Bring those changes into central first with "
              ++ Pp_tty.kwd (module String) "central import"
              ++ Pp.text " before exporting, or pass "
              ++ Pp_tty.kwd (module String) "--force"
              ++ Pp.text " to export anyway."
            ])
;;

let compute_diff ~vcs ~central_root ~subrepo_dir ~gitrepo_path ~base_rev ~head_rev =
  Vcs.git
    vcs
    ~repo_root:central_root
    ~args:
      [ "diff"
      ; "--relative=" ^ subrepo_dir
      ; Vcs.Rev.to_string base_rev
      ; Vcs.Rev.to_string head_rev
      ; "--"
      ; subrepo_dir
      ; ":(exclude)" ^ gitrepo_path
      ]
    ~f:Vcs.Git.exit0_and_stdout
;;

let apply_patch_and_commit
      ~vcs
      ~subrepo_repo_root
      ~subrepo_branch
      ~commit_message
      ~patch_file
  =
  Vcs.git
    vcs
    ~repo_root:subrepo_repo_root
    ~args:[ "checkout"; Vcs.Branch_name.to_string subrepo_branch ]
    ~f:Vcs.Git.exit0;
  Vcs.git
    vcs
    ~repo_root:subrepo_repo_root
    ~args:[ "apply"; "--3way"; "--index"; patch_file ]
    ~f:Vcs.Git.exit0;
  App_log.success (Pp.text "Applied patch in the subrepo.");
  Vcs.commit vcs ~repo_root:subrepo_repo_root ~commit_message
;;

let export ~vcs ~central_root ~subrepo ~message ?(force = false) () =
  Common_helpers.ensure_clean_working_tree ~vcs ~repo_root:central_root;
  let central_graph = Vcs.graph vcs ~repo_root:central_root in
  let facts = Subrepo_facts.compute ~vcs ~central_root ~central_graph ~subrepo in
  let subrepo_dir = Central.Subrepo.root subrepo |> Vcs.Path_in_repo.to_string in
  verify_applicable ~subrepo ~subrepo_dir ~force facts;
  Common_helpers.ensure_clean_working_tree
    ~vcs
    ~repo_root:(Subrepo_facts.subrepo_repo_root facts);
  let gitrepo_file_path = Subrepo_facts.gitrepo_file_path facts in
  let base_rev = Subrepo_facts.base facts in
  let head_rev = Vcs.current_revision vcs ~repo_root:central_root in
  let diff =
    compute_diff
      ~vcs
      ~central_root
      ~subrepo_dir
      ~gitrepo_path:(Vcs.Path_in_repo.to_string gitrepo_file_path)
      ~base_rev
      ~head_rev
  in
  if String.equal (String.strip diff) ""
  then
    Err.raise
      Pp.O.
        [ Pp.text "Nothing to export: no changes under "
          ++ Pp_tty.path (module String) subrepo_dir
          ++ Pp.text " since the last sync."
        ];
  let patch_file = Filename.temp_file "central-export" ".patch" in
  Fun.protect
    ~finally:(fun () ->
      try Sys.remove patch_file with
      | Sys_error _ -> ())
    (fun () ->
       Out_channel.with_open_bin patch_file (fun oc -> Out_channel.output_string oc diff);
       let subrepo_repo_root = Subrepo_facts.subrepo_repo_root facts in
       let subrepo_branch = (Subrepo_facts.gitrepo_file facts).branch.txt in
       let new_subrepo_rev =
         apply_patch_and_commit
           ~vcs
           ~subrepo_repo_root
           ~subrepo_branch
           ~commit_message:(Vcs.Commit_message.v message)
           ~patch_file
       in
       Gitrepo_update.update
         ~repo_root:central_root
         ~gitrepo_file_path
         ~new_commit:new_subrepo_rev
         ~new_parent:head_rev;
       Vcs.add vcs ~repo_root:central_root ~path:gitrepo_file_path;
       let (_ : Vcs.Rev.t) =
         Vcs.commit
           vcs
           ~repo_root:central_root
           ~commit_message:
             (Vcs.Commit_message.v
                (Printf.sprintf "export %s" (Central.Subrepo.to_string subrepo)))
       in
       App_log.success
         Pp.O.(
           Pp.text "Exported to "
           ++ Pp_tty.id (module Central.Subrepo) subrepo
           ++ Pp.text "."))
;;

let main =
  Command.make
    ~summary:"Export monorepo changes into a subrepo, as a single commit."
    ~readme:(fun () ->
      "This computes the diff of everything that changed under a subrepo's directory in \
       the monorepo since the last sync recorded in its $(b,.gitrepo) file, strips the \
       directory path prefix, and applies the result as a single new commit onto the tip \
       of the subrepo's $(b,subrepo) branch, directly in the subrepo repository.\n\n\
       This requires the $(b,subrepo) branch to not have moved since the last sync: if \
       new commits landed there in the meantime, bring them into central first, or pass \
       $(b,--force) to export anyway.\n\n\
       Several $(b,REPO)s may be given at once (or $(b,--all) for every subrepo), for \
       chores that make the same systematic change across many of them: each is exported \
       in turn, in the order given, printing a separator between repos; $(b,-m) is \
       reused as-is for every commit. Export stops at the first repo that fails, leaving \
       the ones after it untouched.")
    (let open Command.Std in
     let+ () = Log_cli.set_config ()
     and+ which_subrepos = Which_repos.Subrepos.arg
     and+ message =
       Arg.named
         [ "m" ]
         Param.string
         ~docv:"MSG"
         ~doc:
           "Commit message to use for the commit created in the subrepo - reused as-is \
            for every subrepo when several are given."
     and+ force = Arg.flag [ "force" ] ~doc:"Force export even if not applicable." in
     let vcs = Volgo_git_unix.create () in
     let cwd = Unix.getcwd () |> Absolute_path.v in
     let central_root = Common_helpers.find_enclosing_repo_root vcs ~from:cwd in
     let subrepos = Which_repos.Subrepos.resolve which_subrepos ~repo_root:central_root in
     let do_export (subrepo : Central.Subrepo.t) : unit =
       export ~vcs ~central_root ~subrepo ~message ~force ()
     in
     Which_repos.Subrepos.iter subrepos ~f:do_export)
;;
