(*_********************************************************************************)
(*_  central - Manage history between sub-repos and their monorepo                *)
(*_  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*_  SPDX-License-Identifier: MIT                                                 *)
(*_********************************************************************************)

(** [import ~vcs ~central_root ~subrepo ~message] is the implementation
    behind [central import]. Exposed separately from {!val:main} so that
    tests can drive it directly against a fake central repo, without going
    through command-line parsing. See {!val:main} for the full behavior.

    Like {!val:Cmd__export.export}: progress messages go through the normal
    [App_log]/[Logs] machinery (silent without a reporter); a merge
    conflict is always reported regardless, since it is the primary
    actionable outcome of this command when a merge is needed at all. When
    central has no local changes of its own under the subrepo's directory
    since the last sync, the subrepo's changes are instead applied directly
    as a single new commit on top of HEAD - no merge, so nothing can
    conflict. The unified diff of the [.gitrepo] file update is logged at
    [Debug] level (see [Gitrepo_update.update]).

    [force] (default [false]) bypasses the guard that otherwise requires the
    subrepo's [subrepo] branch to actually be ahead of the last recorded
    sync point - see {!val:main}'s [--force]. *)
val import
  :  vcs:
       < Vcs.Trait.add
       ; Vcs.Trait.commit
       ; Vcs.Trait.current_branch
       ; Vcs.Trait.current_revision
       ; Vcs.Trait.git
       ; Vcs.Trait.log
       ; Vcs.Trait.name_status
       ; Vcs.Trait.num_status
       ; Vcs.Trait.refs
       ; Vcs.Trait.show
       ; .. >
         Vcs.t
  -> central_root:Vcs.Repo_root.t
  -> subrepo:Central.Subrepo.t
  -> message:string
  -> ?force:bool
  -> unit
  -> unit

val main : unit Command.t
