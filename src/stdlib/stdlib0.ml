(*********************************************************************************)
(*  central - Manage history between sub-repos and their monorepo                *)
(*  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*  SPDX-License-Identifier: MIT                                                 *)
(*********************************************************************************)

module Absolute_path = Absolute_path0
module Dyn = Dyn0
module Json = Json0
module List = List0
module Loc = Loc0
module Myers = Myers0
module Ref = Ref0
module String = String0
module String_id = String_id0

let ( let@ ) f k = f k
let print pp = Format.printf "%a@." Pp.to_fmt pp
let print_dyn dyn = print (Dyn.pp dyn)
