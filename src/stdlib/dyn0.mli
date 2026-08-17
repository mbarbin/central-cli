(*_********************************************************************************)
(*_  central - Manage history between sub-repos and their monorepo                *)
(*_  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*_  SPDX-License-Identifier: MIT                                                 *)
(*_********************************************************************************)

include module type of struct
  include Dyn
end

(** {1 Builder}

    This extends the existing interface to build dyn values with a helper
    that we've found convenient while working with this abstraction. *)

val inline_record : string -> (string * Dyn.t) list -> Dyn.t

(** {1 Alternate syntax}

    Produces a sexp representation of a dyn value, focused on readability
    for debugging, error messages and expect tests - not a round-trip
    serialization framework. *)
val to_sexp : Dyn.t -> Sexplib0.Sexp.t
