(*********************************************************************************)
(*  central - Manage history between sub-repos and their monorepo                *)
(*  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*  SPDX-License-Identifier: MIT                                                 *)
(*********************************************************************************)

type t =
  | Advance_main
  | Advance_subrepo
  | Export
  | Import
  | Push

let all = [ Advance_main; Advance_subrepo; Export; Import; Push ]
let equal : t -> t -> bool = Stdlib.( = )
let compare : t -> t -> int = Stdlib.compare
let hash : t -> int = Stdlib.Hashtbl.hash

let to_dyn = function
  | Advance_main -> Dyn.Variant ("Advance_main", [])
  | Advance_subrepo -> Dyn.Variant ("Advance_subrepo", [])
  | Export -> Dyn.Variant ("Export", [])
  | Import -> Dyn.Variant ("Import", [])
  | Push -> Dyn.Variant ("Push", [])
;;

let to_string_hum = function
  | Advance_main -> "advance-main"
  | Advance_subrepo -> "advance-subrepo"
  | Export -> "export"
  | Import -> "import"
  | Push -> "push"
;;

let to_string = to_string_hum

module Facts = struct
  module Subrepo_head_status = struct
    type t =
      | Unknown_central_gitrepo_rev
      | Central_gitrepo_rev_compared_to_subrepo_head of
          { descendance : Vcs.Graph.Descendance.t }

    let all =
      Unknown_central_gitrepo_rev
      :: List.map Vcs.Graph.Descendance.all ~f:(fun descendance ->
        Central_gitrepo_rev_compared_to_subrepo_head { descendance })
    ;;

    let to_dyn = function
      | Unknown_central_gitrepo_rev -> Dyn.Variant ("Unknown_central_gitrepo_rev", [])
      | Central_gitrepo_rev_compared_to_subrepo_head { descendance } ->
        Dyn.inline_record
          "Central_gitrepo_rev_compared_to_subrepo_head"
          [ "descendance", Vcs.Graph.Descendance.to_dyn descendance ]
    ;;
  end

  type t =
    { central_has_changes_in_subrepo : bool
    ; subrepo_head_status : Subrepo_head_status.t
    ; main_is_strict_ancestor_of_subrepo : bool
    ; remote_main_is_strict_ancestor_of_local_main : bool
    }

  let all : t list =
    let ( let* ) x f = List.concat_map x ~f in
    let bool = [ false; true ] in
    let* central_has_changes_in_subrepo = bool in
    let* subrepo_head_status = Subrepo_head_status.all in
    let* main_is_strict_ancestor_of_subrepo = bool in
    let* remote_main_is_strict_ancestor_of_local_main = bool in
    [ { central_has_changes_in_subrepo
      ; subrepo_head_status
      ; main_is_strict_ancestor_of_subrepo
      ; remote_main_is_strict_ancestor_of_local_main
      }
    ]
  ;;

  let to_dyn t =
    Dyn.Record
      [ "central_has_changes_in_subrepo", Dyn.bool t.central_has_changes_in_subrepo
      ; "subrepo_head_status", Subrepo_head_status.to_dyn t.subrepo_head_status
      ; ( "main_is_strict_ancestor_of_subrepo"
        , Dyn.bool t.main_is_strict_ancestor_of_subrepo )
      ; ( "remote_main_is_strict_ancestor_of_local_main"
        , Dyn.bool t.remote_main_is_strict_ancestor_of_local_main )
      ]
  ;;
end

let next_step_priority = function
  | Advance_main -> 0
  | Advance_subrepo -> 1
  | Import -> 2
  | Export -> 3
  | Push -> 4
;;

let is_applicable
      (t : t)
      ~facts:
        { Facts.central_has_changes_in_subrepo
        ; subrepo_head_status
        ; main_is_strict_ancestor_of_subrepo
        ; remote_main_is_strict_ancestor_of_local_main
        }
  =
  match t with
  | Advance_main -> main_is_strict_ancestor_of_subrepo
  | Advance_subrepo ->
    (match subrepo_head_status with
     | Central_gitrepo_rev_compared_to_subrepo_head { descendance = Strict_descendant } ->
       true
     | Central_gitrepo_rev_compared_to_subrepo_head
         { descendance = Same_node | Strict_ancestor | Other }
     | Unknown_central_gitrepo_rev -> false)
  | Export ->
    central_has_changes_in_subrepo
    &&
      (match subrepo_head_status with
      | Central_gitrepo_rev_compared_to_subrepo_head { descendance = Same_node } -> true
      | Central_gitrepo_rev_compared_to_subrepo_head
          { descendance = Other | Strict_ancestor | Strict_descendant }
      | Unknown_central_gitrepo_rev -> false)
  | Import ->
    (* Unlike [Export], this doesn't also require
       [not central_has_changes_in_subrepo]: when central has no changes of
       its own under the subrepo path, [import] applies the subrepo's diff
       directly onto HEAD; otherwise it builds its commit as a child of the
       last sync point and merges it in, so either way it's just as capable
       of bringing the subrepo's new commits in when central *also* has
       local changes of its own under the subrepo path - any conflict
       between the two surfaces as an ordinary merge conflict, the same way
       it would if central's local changes had landed after the import
       instead of before it. *)
    (match subrepo_head_status with
     | Central_gitrepo_rev_compared_to_subrepo_head { descendance = Strict_ancestor } ->
       true
     | Central_gitrepo_rev_compared_to_subrepo_head
         { descendance = Same_node | Other | Strict_descendant }
     | Unknown_central_gitrepo_rev -> false)
  | Push -> remote_main_is_strict_ancestor_of_local_main
;;

let compute facts =
  let applicable_next_steps = List.filter all ~f:(fun t -> is_applicable t ~facts) in
  List.min_elt applicable_next_steps ~compare:(fun t1 t2 ->
    Int.compare (next_step_priority t1) (next_step_priority t2))
;;
