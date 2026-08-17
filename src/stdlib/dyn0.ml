(*********************************************************************************)
(*  central - Manage history between sub-repos and their monorepo                *)
(*  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*  SPDX-License-Identifier: MIT                                                 *)
(*********************************************************************************)

module List = List0
module Sexp = Sexplib0.Sexp
include Dyn

let inline_record cons fields = Dyn.variant cons [ Dyn.record fields ]

let to_sexp =
  let rec aux (dyn : Dyn.t) : Sexp.t =
    match[@coverage off] dyn with
    | Opaque -> Atom "<opaque>"
    | Unit -> List []
    | Int i -> Sexplib0.Sexp_conv.sexp_of_int i
    | Int32 i -> Sexplib0.Sexp_conv.sexp_of_int32 i
    | Record fields ->
      List (List.map fields ~f:(fun (field, t) -> Sexp.List [ Atom field; aux t ]))
    | Variant (v, args) ->
      (* Special pretty print of variants holding records. *)
      (match args with
       | [] -> Atom v
       | [ Record fields ] ->
         List
           (Atom v
            :: List.map fields ~f:(fun (field, t) -> Sexp.List [ Atom field; aux t ]))
       | _ -> List (Atom v :: List.map args ~f:aux))
    | Bool b -> Sexplib0.Sexp_conv.sexp_of_bool b
    | String a -> Sexplib0.Sexp_conv.sexp_of_string a
    | Bytes a -> Sexplib0.Sexp_conv.sexp_of_bytes a
    | Int64 i -> Sexplib0.Sexp_conv.sexp_of_int64 i
    | Nativeint i -> Sexplib0.Sexp_conv.sexp_of_nativeint i
    | Char c -> Sexplib0.Sexp_conv.sexp_of_char c
    | Float f -> Sexplib0.Sexp_conv.sexp_of_float f
    | Option o -> Sexplib0.Sexp_conv.sexp_of_option aux o
    | List l -> Sexplib0.Sexp_conv.sexp_of_list aux l
    | Array a -> Sexplib0.Sexp_conv.sexp_of_array aux a
    | Tuple t -> List (List.map t ~f:aux)
    | Map m -> List (List.map m ~f:(fun (k, v) -> Sexp.List [ aux k; aux v ]))
    | Set s -> List (List.map s ~f:aux)
  in
  aux
;;
