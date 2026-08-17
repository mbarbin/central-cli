(*_********************************************************************************)
(*_  central - Manage history between sub-repos and their monorepo                *)
(*_  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*_  SPDX-License-Identifier: MIT                                                 *)
(*_********************************************************************************)

(** The next most logical step to make progress on a sub-repo.

    Only the cases covered so far ([advance-main], [advance-subrepo],
    [export], [import], [push]) are represented here; more will be added as
    the CLI grows. *)

type t =
  | Advance_main
  | Advance_subrepo
  | Export
  | Import
  | Push

val all : t list
val equal : t -> t -> bool
val compare : t -> t -> int
val hash : t -> int
val to_dyn : t -> Dyn.t
val to_string_hum : t -> string

(** An alias for {!to_string_hum}. *)
val to_string : t -> string

module Facts : sig
  (** The input type regroups all the facts that the computation of next step
      depends on, from the perspective of a particular sub-repo. *)

  module Subrepo_head_status : sig
    (** This type captures the relationship between the [commit] revision that
        is indicated in the [.gitrepo] file against the location of the
        [subrepo] branch in the subrepo. *)
    type t =
      | Unknown_central_gitrepo_rev
      | Central_gitrepo_rev_compared_to_subrepo_head of
          { descendance : Vcs.Graph.Descendance.t }

    val to_dyn : t -> Dyn.t
  end

  type t =
    { central_has_changes_in_subrepo : bool
      (** Since the last [export], there are some changes in the monorepo in
          the subrepo directory. *)
    ; subrepo_head_status : Subrepo_head_status.t
    ; main_is_strict_ancestor_of_subrepo : bool
      (** As long as we rely on a [subrepo] branch, sometimes this branch
          advances more than [main]. *)
    ; remote_main_is_strict_ancestor_of_local_main : bool
    }

  val all : t list
  val to_dyn : t -> Dyn.t
end

(** [compute input] computes the next step to make progress. *)
val compute : Facts.t -> t option

(** Given the facts, tell whether a particular next-step is currently
    applicable. Note that the todo may favor a different next-step as the
    suggested way to make immediate progress in the case where several next-steps
    are applicable. *)
val is_applicable : t -> facts:Facts.t -> bool
