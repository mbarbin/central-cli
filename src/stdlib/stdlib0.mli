(*_********************************************************************************)
(*_  central - Manage history between sub-repos and their monorepo                *)
(*_  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*_  SPDX-License-Identifier: MIT                                                 *)
(*_********************************************************************************)

(** Extending [Stdlib] for use in this project. Populated on demand: modules
    here re-export the plain stdlib (or a vendored / public library) as-is,
    growing extra helpers only once something actually needs them. *)

module Absolute_path = Absolute_path0
module Dyn = Dyn0
module Json = Json0
module List = List0
module Loc = Loc0
module Myers = Myers0
module Ref = Ref0
module String = String0
module String_id = String_id0

(** Binding operator for pass-through / resource-style callbacks.

    [let@ x = with_resource in body] is equivalent to
    [with_resource @@ fun x -> body]. *)
val ( let@ ) : (('a -> 'b) -> 'c) -> ('a -> 'b) -> 'c

val print_dyn : Dyn.t -> unit
