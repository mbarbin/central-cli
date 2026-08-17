(*_********************************************************************************)
(*_  central - Manage history between sub-repos and their monorepo                *)
(*_  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*_  SPDX-License-Identifier: MIT                                                 *)
(*_********************************************************************************)

(** [export ~vcs ~central_root ~subrepo ~message] is the implementation behind
    [central export]. Exposed separately from {!val:main} so that tests can
    drive it directly against a fake central repo, without going through
    command-line parsing. See {!val:main} for the full behavior.

    Progress messages ("Applied patch...", "Exported to...") always go
    through the normal [App_log]/[Logs] machinery - they only show up once a
    reporter has been installed (e.g. via [Log_cli.set_config], as
    {!val:main} does), so callers driving this programmatically (tests, other
    commands) see nothing by default without any extra effort.

    The unified diff of the [.gitrepo] file before/after is logged at
    [Debug] level - it only shows up when the caller has configured [Logs]
    for debug output (e.g. the CLI's own [--verbosity=debug], via
    {!val:main}'s [Log_cli.set_config]).

    [force] (default [false]) bypasses the guard that requires the subrepo's
    [subrepo] branch to not have moved since the last sync - see
    {!val:main}'s [--force]. It cannot make an empty export succeed: that
    check stays unconditional. *)
val export
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
  -> message:string
  -> ?force:bool
  -> unit
  -> unit

val main : unit Command.t
