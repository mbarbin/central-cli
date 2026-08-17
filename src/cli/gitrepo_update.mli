(*_********************************************************************************)
(*_  central - Manage history between sub-repos and their monorepo                *)
(*_  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*_  SPDX-License-Identifier: MIT                                                 *)
(*_********************************************************************************)

(** Shared by [export] and [import]: both record a new sync point by
    rewriting [.gitrepo]'s [commit] and [parent] fields in place, in
    whichever repo checkout [repo_root] points at (the caller's own working
    copy for [export], a temporary worktree for [import]).

    [new_commit] is the subrepo revision the new sync point corresponds to;
    [new_parent] is the central revision it corresponds to - normally the
    git-parent of the commit doing the rewriting, so that
    [Subrepo_facts.compute]'s search for the sync-point commit finds it
    again later.

    The unified diff of the file before/after is logged at [Debug] level -
    invisible by default, shown when the command is run with e.g.
    [--verbosity=debug]. *)
val update
  :  repo_root:Vcs.Repo_root.t
  -> gitrepo_file_path:Vcs.Path_in_repo.t
  -> new_commit:Vcs.Rev.t
  -> new_parent:Vcs.Rev.t
  -> unit
