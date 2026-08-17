(*********************************************************************************)
(*  central - Manage history between sub-repos and their monorepo                *)
(*  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*  SPDX-License-Identifier: MIT                                                 *)
(*********************************************************************************)

(* This is used after a subrepo push whose history was rewritten afterwards
   without changing the resulting tree - typically: [export], then rework
   the just-exported commit into a nicer sequence of commits, arriving at
   the exact same state. Since the tree hasn't actually changed, there is
   nothing to bring in via [import] (its diff would be empty, and it would
   refuse to run) - the only thing left stale is the commit central's
   [.gitrepo] file points at, which still names the pre-rewrite commit. That
   is all [stitch] fixes: it points [.gitrepo] at the subrepo's new tip
   instead. *)

(* The required pre-conditions, each checked below with its own actionable
   message:

   1. The subrepo branch has actually moved since the last sync - otherwise
   there is nothing to stitch.

   2. The subrepo has no real content changes between the commit recorded in
   [.gitrepo] and its current tip - i.e. this really is a pure history
   rewrite, "merely changing the commit" rather than its content. If it
   isn't, [stitch] would silently point [.gitrepo] at a tip whose tree
   doesn't match what central has under the subrepo's directory - [import]
   is what's needed instead.

   3. Central has no local changes of its own under the subrepo's directory
   since the last sync - otherwise there would be a real diff between
   central's checkout and the subrepo's new tip that a plain re-pointing of
   [.gitrepo] can't account for. *)
let verify_applicable
      ~subrepo
      ~subrepo_dir
      ~(gitrepo_abs_path : Absolute_path.t)
      ~gitrepo_rev
      ~subrepo_head_rev
      ~name_status
      ~central_has_changes_in_subrepo
  =
  let loc = Loc.of_file ~path:(gitrepo_abs_path :> Fpath.t) in
  if Vcs.Rev.equal gitrepo_rev subrepo_head_rev
  then
    Err.raise
      ~loc
      Pp.O.
        [ Pp.text "Nothing to stitch: the "
          ++ Pp_tty.kwd (module String) "subrepo"
          ++ Pp.text " branch of "
          ++ Pp_tty.id (module Central.Subrepo) subrepo
          ++ Pp.text " is already the commit recorded in "
          ++ Pp_tty.kwd (module String) ".gitrepo"
          ++ Pp.text "."
        ];
  if not (List.is_empty name_status)
  then
    Err.raise
      ~loc
      Pp.O.
        [ Pp.text "Cannot stitch: "
          ++ Pp_tty.path (module String) subrepo_dir
          ++ Pp.text " has content changes between the commit recorded in "
          ++ Pp_tty.kwd (module String) ".gitrepo"
          ++ Pp.text " and its current tip - this isn't a pure history rewrite."
        ]
      ~hints:
        Pp.O.
          [ Pp.text "Use "
            ++ Pp_tty.kwd (module String) "central import"
            ++ Pp.text " instead to bring those changes in."
          ];
  if central_has_changes_in_subrepo
  then
    Err.raise
      ~loc
      Pp.O.
        [ Pp.text "Cannot stitch: central has local changes of its own under "
          ++ Pp_tty.path (module String) subrepo_dir
          ++ Pp.text " since the last sync."
        ]
      ~hints:[ Pp.text "Export or import those changes first, then stitch." ]
;;

let stitch ~vcs ~central_root ~subrepo facts =
  let subrepo_dir = Central.Subrepo.root subrepo |> Vcs.Path_in_repo.to_string in
  let gitrepo_file_path = Subrepo_facts.gitrepo_file_path facts in
  let gitrepo_rev = (Subrepo_facts.gitrepo_file facts).commit.txt in
  let subrepo_head_rev =
    Vcs.Graph.rev
      (Subrepo_facts.subrepo_graph facts)
      ~node:(Subrepo_facts.subrepo_head facts)
  in
  let name_status =
    Vcs.name_status
      vcs
      ~repo_root:(Subrepo_facts.subrepo_repo_root facts)
      ~changed:(Between { src = gitrepo_rev; dst = subrepo_head_rev })
  in
  verify_applicable
    ~subrepo
    ~subrepo_dir
    ~gitrepo_abs_path:(Vcs.Repo_root.append central_root gitrepo_file_path)
    ~gitrepo_rev
    ~subrepo_head_rev
    ~name_status
    ~central_has_changes_in_subrepo:
      (Subrepo_facts.next_step_facts facts).central_has_changes_in_subrepo;
  let central_head_rev = Vcs.current_revision vcs ~repo_root:central_root in
  Gitrepo_update.update
    ~repo_root:central_root
    ~gitrepo_file_path
    ~new_commit:subrepo_head_rev
    ~new_parent:central_head_rev;
  Vcs.add vcs ~repo_root:central_root ~path:gitrepo_file_path;
  let commit_message =
    Vcs.Commit_message.v
      (Printf.sprintf "Stitch repo %s" (Central.Subrepo.to_string subrepo))
  in
  let (_ : Vcs.Rev.t) = Vcs.commit vcs ~repo_root:central_root ~commit_message in
  App_log.success
    Pp.O.(
      Pp.text "Stitched " ++ Pp_tty.id (module Central.Subrepo) subrepo ++ Pp.text ".")
;;

let main =
  Command.make
    ~summary:"Stitch a subrepo's tip to the monorepo."
    ~readme:(fun () ->
      "After a push to a subrepo, if the subrepo history is rewritten, its tip will \
       change while the $(b,.gitrepo) file will still contain the tip of the subrepo as \
       of prior to the history edit.\n\n\
       When the history edit is only about reordering commits, there is no need for a \
       complex merge, nor to run $(b,import) - its diff would be empty. Instead we can \
       simply set the new tip of the subrepo in the $(b,.gitrepo) file.\n\n\
       This is what we call a $(b,stitch). The required pre-conditions are:\n\n\
       1. The subrepo branch has actually moved since the last sync.\n\n\
       2. The subrepo has no changes between the $(b,.gitrepo) file and the actual tip \
       of the subrepo.\n\n\
       3. The monorepo has no changes in the subrepo between the revision when the \
       subrepo push was done and the current tip.\n\n\
       Unlike $(b,export), there is nothing worth writing by hand here: the commit that \
       updates the $(b,.gitrepo) file is created automatically, with the message \
       $(b,\"Stitch repo REPO\").")
    (let open Command.Std in
     let+ () = Log_cli.set_config ()
     and+ which_subrepos = Which_repos.Subrepos.arg in
     let vcs = Volgo_git_unix.create () in
     let cwd = Unix.getcwd () |> Absolute_path.v in
     let central_root = Common_helpers.find_enclosing_repo_root vcs ~from:cwd in
     Common_helpers.ensure_clean_working_tree ~vcs ~repo_root:central_root;
     let central_graph = Vcs.graph vcs ~repo_root:central_root in
     let subrepos = Which_repos.Subrepos.resolve which_subrepos ~repo_root:central_root in
     Which_repos.Subrepos.iter subrepos ~f:(fun subrepo ->
       let facts = Subrepo_facts.compute ~vcs ~central_root ~central_graph ~subrepo in
       stitch ~vcs ~central_root ~subrepo facts))
;;
