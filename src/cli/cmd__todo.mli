(*_********************************************************************************)
(*_  central - Manage history between sub-repos and their monorepo                *)
(*_  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*_  SPDX-License-Identifier: MIT                                                 *)
(*_********************************************************************************)

(** Not shared with the internal tool's own [Cmd__todo]: that one also
    scans for CRs and factors in release/changelog state, neither of which
    is in scope here yet. This is a standalone, trimmed-down version:
    central plus each subrepo, with their next step and outstanding diff
    size. *)

module Todo_table : sig
  type t

  val compute
    :  vcs:
         < Vcs.Trait.current_revision
         ; Vcs.Trait.git
         ; Vcs.Trait.log
         ; Vcs.Trait.name_status
         ; Vcs.Trait.num_status
         ; Vcs.Trait.refs
         ; Vcs.Trait.show
         ; .. >
           Vcs.t
    -> central_root:Vcs.Repo_root.t
    -> t

  val to_string : t -> repo_config:Central.Repo_config.t -> string
end

val main : unit Command.t
