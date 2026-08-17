(*_********************************************************************************)
(*_  central - Manage history between sub-repos and their monorepo                *)
(*_  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*_  SPDX-License-Identifier: MIT                                                 *)
(*_********************************************************************************)

(** Gathering facts about a subrepo.

    This is used by [export], [import], [push], [stitch], [advance-main],
    [advance-subrepo] and [todo] to verify some invariants, compute the next
    step, and size the outstanding diff. Only what those commands need is
    included for now (no changelog / release facts yet). *)

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
  -> central_graph:Vcs.Graph.t
  -> subrepo:Central.Subrepo.t
  -> t

(** {1 Next steps} *)

val next_step_facts : t -> Central.Next_step.Facts.t
val next_step : t -> Central.Next_step.t option

(** {1 Subrepo graph} *)

val subrepo_repo_root : t -> Vcs.Repo_root.t
val subrepo_graph : t -> Vcs.Graph.t
val subrepo_head : t -> Vcs.Graph.Node.t

(** {1 Gitrepo file (git subrepo)} *)

val gitrepo_file : t -> Gitrepo_file.t
val gitrepo_file_path : t -> Vcs.Path_in_repo.t

(** {1 Diffs}

    Computing the diffs of all that has changed between the last time we
    synced with the subrepo and the current head of the subrepo. *)

(** The revision used as the base of diffs. This is the last revision known
    by central when it last synced with the subrepo. *)
val base : t -> Vcs.Rev.t

(** The total number of changed lines (added + removed, and 1 per binary
    file) under the subrepo's directory in the monorepo, since {!base}. Used
    to populate the "Diff" column in [todo]'s table. *)
val num_lines_to_review : t -> int
