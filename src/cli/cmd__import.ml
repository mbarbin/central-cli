(*********************************************************************************)
(*  central - Manage history between sub-repos and their monorepo                *)
(*  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*  SPDX-License-Identifier: MIT                                                 *)
(*********************************************************************************)

(* This command brings new commits from the subrepo's [subrepo] branch into
   central. It picks between two ways of doing that, depending on whether
   central has local changes of its own under the subrepo's directory since
   the last sync recorded in [.gitrepo] - see
   [Central.Next_step.Facts.central_has_changes_in_subrepo], computed once
   by [Subrepo_facts] and reused here.

   The common case - central has no changes under the subrepo's directory
   since the last sync: then that directory at central's current HEAD is,
   by construction, byte-for-byte the same as it was at the last sync
   point (nothing has touched it since), so the subrepo's own diff since
   then is guaranteed to apply there too, exactly as well as it would at
   the last sync point itself. There is nothing to merge, so we don't
   build one: the subrepo's diff is applied straight onto central's
   current checkout, as a single new commit that is a direct child of
   HEAD - a plain, linear commit, same as any other. This is the default,
   and it's what keeps history simple in the overwhelmingly common case
   where nothing central did could possibly conflict with what the
   subrepo brings in. See [apply_directly].

   The fallback - central *does* have local changes of its own under the
   subrepo's directory, which may or may not conflict with the incoming
   ones: rather than applying the subrepo's diff directly onto central's
   current HEAD (where it might collide with those local changes), we
   build a new commit as a direct child of [Subrepo_facts.base] - the
   central commit that last recorded a sync point in [.gitrepo]. At that
   revision, the subrepo's directory is - by construction - in exactly the
   state the subrepo was in as of the last sync, so the subrepo's own diff
   since then is guaranteed to apply there cleanly, no matter what else
   has happened on central's actual HEAD since. We call this the "import
   commit". We then [git merge --no-ff] it into whatever branch was
   checked out in central (normally [main]): an ordinary two-parent merge
   between "HEAD, plus whatever central did since the base" and "the
   base, plus the subrepo's new content" - so any real conflict between
   the two is surfaced by git itself, the usual way, left for the caller
   to resolve and commit. See [build_import_commit] and
   [merge_import_commit].

   Either way, the commit that carries the subrepo's new content also
   updates [.gitrepo] to record the new sync point - it's the only commit
   that touches [.gitrepo], so a later [export] finds it exactly like it
   would after its own commit. *)

(* [is_applicable] ties this guard to the same [Next_step.Import] predicate
   that drives [next_step] - see there for why it doesn't care whether
   central also has local changes of its own: [import] picks between
   applying directly and merging precisely to handle that case either way.
   The two cases below are its remaining ways of being [false], each
   spelled out with a specific, actionable message instead of a generic
   "not applicable". [--force] lets the caller push through either of them
   at their own risk. *)
let verify_applicable ~subrepo ~force facts =
  let next_step_facts = Subrepo_facts.next_step_facts facts in
  let is_applicable = Central.Next_step.is_applicable Import ~facts:next_step_facts in
  if is_applicable || force
  then ()
  else (
    match next_step_facts.subrepo_head_status with
    | Central_gitrepo_rev_compared_to_subrepo_head { descendance = Same_node } ->
      Err.raise
        Pp.O.
          [ Pp.text "Nothing to import: the "
            ++ Pp_tty.kwd (module String) "subrepo"
            ++ Pp.text " branch of "
            ++ Pp_tty.id (module Central.Subrepo) subrepo
            ++ Pp.text " has not moved since the last sync."
          ]
    | Central_gitrepo_rev_compared_to_subrepo_head { descendance = Strict_ancestor } ->
      (* Unreachable: this is exactly the case [is_applicable] requires. *)
      assert false
    | Central_gitrepo_rev_compared_to_subrepo_head
        { descendance = Strict_descendant | Other }
    | Unknown_central_gitrepo_rev ->
      Err.raise
        Pp.O.
          [ Pp.text "Cannot import: the "
            ++ Pp_tty.kwd (module String) "subrepo"
            ++ Pp.text " branch of "
            ++ Pp_tty.id (module Central.Subrepo) subrepo
            ++ Pp.text " is not a descendant of the commit recorded in "
            ++ Pp_tty.kwd (module String) ".gitrepo"
            ++ Pp.text "."
          ]
        ~hints:
          [ Pp.text
              "This can happen if the subrepo branch was reset or rewritten \
               independently of central - this needs to be sorted out manually."
          ])
;;

let compute_diff ~vcs ~subrepo_repo_root ~old_rev ~new_rev =
  Vcs.git
    vcs
    ~repo_root:subrepo_repo_root
    ~args:[ "diff"; Vcs.Rev.to_string old_rev; Vcs.Rev.to_string new_rev ]
    ~f:Vcs.Git.exit0_and_stdout
;;

(* A temporary, detached worktree at [base_rev] - so we can build the import
   commit without disturbing whatever [central_root]'s own checkout
   currently has checked out or in progress. *)
let with_temp_worktree vcs ~central_root ~base_rev f =
  let tmp_dir = Filename.temp_dir "central-import" "" in
  Vcs.git
    vcs
    ~repo_root:central_root
    ~args:[ "worktree"; "add"; "--detach"; tmp_dir; Vcs.Rev.to_string base_rev ]
    ~f:Vcs.Git.exit0;
  Fun.protect
    ~finally:(fun () ->
      try
        Vcs.git
          vcs
          ~repo_root:central_root
          ~args:[ "worktree"; "remove"; "--force"; tmp_dir ]
          ~f:Vcs.Git.exit0
      with
      | _ -> ())
    (fun () -> f (Vcs.Repo_root.of_absolute_path (Absolute_path.v tmp_dir)))
;;

let current_branch_name_or_head ~vcs ~central_root =
  match Vcs.current_branch_opt vcs ~repo_root:central_root with
  | Some branch_name -> Vcs.Branch_name.to_string branch_name
  | None -> "HEAD"
;;

(* The fast path: central has no changes of its own under the subrepo's
   directory since the last sync, so the subrepo's diff applies just as
   well onto the current checkout as it would at the last sync point - no
   separate worktree, no merge, just a single new commit as a direct child
   of HEAD. [new_parent] is that same HEAD, since it is now, genuinely,
   the new commit's git-parent. *)
let apply_directly
      ~vcs
      ~central_root
      ~subrepo_dir
      ~gitrepo_file_path
      ~patch_file
      ~new_subrepo_rev
      ~commit_message
  =
  let head_rev = Vcs.current_revision vcs ~repo_root:central_root in
  Vcs.git
    vcs
    ~repo_root:central_root
    ~args:[ "apply"; "--3way"; "--index"; "--directory=" ^ subrepo_dir; patch_file ]
    ~f:Vcs.Git.exit0;
  Gitrepo_update.update
    ~repo_root:central_root
    ~gitrepo_file_path
    ~new_commit:new_subrepo_rev
    ~new_parent:head_rev;
  Vcs.add vcs ~repo_root:central_root ~path:gitrepo_file_path;
  let (_ : Vcs.Rev.t) = Vcs.commit vcs ~repo_root:central_root ~commit_message in
  let branch_name = current_branch_name_or_head ~vcs ~central_root in
  App_log.success
    Pp.O.(
      Pp.text "Imported into "
      ++ Pp_tty.id (module String) branch_name
      ++ Pp.text " directly (no merge needed).")
;;

let build_import_commit
      ~vcs
      ~worktree_root
      ~subrepo_dir
      ~gitrepo_file_path
      ~patch_file
      ~new_subrepo_rev
      ~base_rev
      ~commit_message
  =
  Vcs.git
    vcs
    ~repo_root:worktree_root
    ~args:[ "apply"; "--3way"; "--index"; "--directory=" ^ subrepo_dir; patch_file ]
    ~f:Vcs.Git.exit0;
  Gitrepo_update.update
    ~repo_root:worktree_root
    ~gitrepo_file_path
    ~new_commit:new_subrepo_rev
    ~new_parent:base_rev;
  Vcs.add vcs ~repo_root:worktree_root ~path:gitrepo_file_path;
  App_log.success (Pp.text "Built the import commit.");
  Vcs.commit vcs ~repo_root:worktree_root ~commit_message
;;

let merge_import_commit ~vcs ~central_root ~import_rev ~merge_message =
  let branch_name = current_branch_name_or_head ~vcs ~central_root in
  let output =
    Vcs.git
      vcs
      ~repo_root:central_root
      ~args:[ "merge"; "--no-ff"; "-m"; merge_message; Vcs.Rev.to_string import_rev ]
      ~f:(fun output -> output)
  in
  print_string output.stdout;
  print_string output.stderr;
  match output.exit_code with
  | 0 ->
    App_log.success
      Pp.O.(
        Pp.text "Imported into " ++ Pp_tty.id (module String) branch_name ++ Pp.text ".")
  | 1 ->
    Err.raise
      Pp.O.
        [ Pp.text "Merge conflict while importing - resolve the conflicts above in "
          ++ Pp_tty.id (module String) branch_name
          ++ Pp.text ", then "
          ++ Pp_tty.kwd (module String) "git add"
          ++ Pp.text " the resolved files and "
          ++ Pp_tty.kwd (module String) "git commit"
          ++ Pp.text " to finish the merge."
        ]
      ~hints:
        [ Pp.text
            ".gitrepo has already been updated as part of the import commit being merged \
             - no further action needed there once the merge is complete."
        ]
  | exit_code ->
    Err.raise [ Pp.textf "git merge exited with unexpected code %d." exit_code ]
;;

let import ~vcs ~central_root ~subrepo ~message ?(force = false) () =
  Common_helpers.ensure_clean_working_tree ~vcs ~repo_root:central_root;
  let central_graph = Vcs.graph vcs ~repo_root:central_root in
  let facts = Subrepo_facts.compute ~vcs ~central_root ~central_graph ~subrepo in
  verify_applicable ~subrepo ~force facts;
  let subrepo_dir = Central.Subrepo.root subrepo |> Vcs.Path_in_repo.to_string in
  let gitrepo_file_path = Subrepo_facts.gitrepo_file_path facts in
  let base_rev = Subrepo_facts.base facts in
  let gitrepo_rev = (Subrepo_facts.gitrepo_file facts).commit.txt in
  let subrepo_repo_root = Subrepo_facts.subrepo_repo_root facts in
  let subrepo_graph = Subrepo_facts.subrepo_graph facts in
  let new_subrepo_rev =
    Vcs.Graph.rev subrepo_graph ~node:(Subrepo_facts.subrepo_head facts)
  in
  let diff =
    compute_diff ~vcs ~subrepo_repo_root ~old_rev:gitrepo_rev ~new_rev:new_subrepo_rev
  in
  if String.equal (String.strip diff) ""
  then
    Err.raise
      [ Pp.text "Nothing to import: no changes in the subrepo since the last sync." ];
  let patch_file = Filename.temp_file "central-import" ".patch" in
  Fun.protect
    ~finally:(fun () ->
      try Sys.remove patch_file with
      | Sys_error _ -> ())
    (fun () ->
       Out_channel.with_open_bin patch_file (fun oc -> Out_channel.output_string oc diff);
       let central_has_changes_in_subrepo =
         (Subrepo_facts.next_step_facts facts).central_has_changes_in_subrepo
       in
       if central_has_changes_in_subrepo
       then (
         let import_rev =
           with_temp_worktree vcs ~central_root ~base_rev (fun worktree_root ->
             build_import_commit
               ~vcs
               ~worktree_root
               ~subrepo_dir
               ~gitrepo_file_path
               ~patch_file
               ~new_subrepo_rev
               ~base_rev
               ~commit_message:(Vcs.Commit_message.v message))
         in
         let merge_message =
           Printf.sprintf "Merge %s import" (Central.Subrepo.to_string subrepo)
         in
         merge_import_commit ~vcs ~central_root ~import_rev ~merge_message)
       else
         apply_directly
           ~vcs
           ~central_root
           ~subrepo_dir
           ~gitrepo_file_path
           ~patch_file
           ~new_subrepo_rev
           ~commit_message:(Vcs.Commit_message.v message))
;;

let main =
  Command.make
    ~summary:"Import new subrepo commits into central."
    ~readme:(fun () ->
      "This brings commits from the tip of a subrepo's $(b,subrepo) branch that are not \
       yet reflected in central into its directory.\n\n\
       If central has no local changes of its own under that directory since the last \
       sync recorded in $(b,.gitrepo), the subrepo's changes are applied directly as a \
       single new commit on top of the current HEAD - no merge, since the directory is \
       byte-for-byte what it was at the last sync point, so there is nothing for the \
       incoming changes to conflict with. This is the common case.\n\n\
       Otherwise, this falls back to an ordinary two-parent $(b,git merge): a new commit \
       is first built as a direct child of the central revision recorded in \
       $(b,.gitrepo) - not of the current HEAD - so applying the subrepo's own diff \
       there is guaranteed to succeed regardless of what else changed in central since. \
       It is then merged into the active branch (normally $(b,main)): if central has no \
       conflicting local changes this completes on its own, otherwise git leaves the \
       usual conflict markers for you to resolve, then $(b,git add) and $(b,git commit) \
       to finish.\n\n\
       Either way, the commit that brings the subrepo's changes in also updates \
       $(b,.gitrepo) to record the new sync point, so $(b,export) can be used again \
       right after.\n\n\
       This requires the $(b,subrepo) branch to actually be ahead of the last recorded \
       sync point; pass $(b,--force) to import anyway.")
    (let open Command.Std in
     let+ () = Log_cli.set_config ()
     and+ subrepo =
       Arg.pos
         ~pos:0
         (Param.validated_string (module Central.Subrepo))
         ~docv:"REPO"
         ~doc:"The subrepo to import changes from."
     and+ message =
       Arg.named_opt
         [ "m" ]
         Param.string
         ~docv:"MSG"
         ~doc:
           "Commit message for the commit that brings the subrepo's changes in. Defaults \
            to \"Import changes from REPO\"."
     and+ force = Arg.flag [ "force" ] ~doc:"Force import even if not applicable." in
     let vcs = Volgo_git_unix.create () in
     let cwd = Unix.getcwd () |> Absolute_path.v in
     let central_root = Common_helpers.find_enclosing_repo_root vcs ~from:cwd in
     let message =
       match message with
       | Some message -> message
       | None ->
         Printf.sprintf "Import changes from %s" (Central.Subrepo.to_string subrepo)
     in
     import ~vcs ~central_root ~subrepo ~message ~force ())
;;
