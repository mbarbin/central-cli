(*_********************************************************************************)
(*_  central - Manage history between sub-repos and their monorepo                *)
(*_  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*_  SPDX-License-Identifier: MIT                                                 *)
(*_********************************************************************************)

(** A thin wrapper around JSON handling, abstracting over the underlying
    library (currently Yojson). *)

type t = Yojson.Basic.t

(** Raised when JSON parsing or validation fails. *)
exception Error of t * string

(** Pretty-print a JSON value to a string. *)
val to_string : t -> string
