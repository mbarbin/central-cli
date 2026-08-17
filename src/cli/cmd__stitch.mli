(*_********************************************************************************)
(*_  central - Manage history between sub-repos and their monorepo                *)
(*_  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*_  SPDX-License-Identifier: MIT                                                 *)
(*_********************************************************************************)

(** [stitch ~vcs ~central_root ~subrepo facts] is the implementation behind
    [central stitch] for a single [subrepo], given its {!Subrepo_facts.t}.
    Exposed separately from {!val:main} so that tests can drive it directly
    against a fake central repo, without going through command-line
    parsing.

    This requires the subrepo's [subrepo] branch to have moved since the
    last sync recorded in [.gitrepo], with no actual content changes between
    the two - i.e. a pure history rewrite - and no local changes of
    central's own under the subrepo's directory since the last sync; see
    {!val:main} for the full behavior. Unlike {!Cmd__export.export}, there
    is no message to supply: the commit that updates [.gitrepo] is created
    automatically, with the message ["Stitch repo REPO"] - the subrepo's
    copy in the monorepo isn't public history, so there's nothing worth
    writing by hand here. *)
val stitch
  :  vcs:
       < Vcs.Trait.add
       ; Vcs.Trait.commit
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
  -> Subrepo_facts.t
  -> unit

val main : unit Command.t
