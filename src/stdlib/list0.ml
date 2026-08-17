(*********************************************************************************)
(*  central - Manage history between sub-repos and their monorepo                *)
(*  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*  SPDX-License-Identifier: MIT                                                 *)
(*********************************************************************************)

include Stdlib.ListLabels

let min_elt t ~compare =
  match t with
  | [] -> None
  | hd :: tl ->
    Some (Stdlib.List.fold_left (fun a b -> if compare a b <= 0 then a else b) hd tl)
;;
