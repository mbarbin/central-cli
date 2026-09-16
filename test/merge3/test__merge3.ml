(*********************************************************************************)
(*  central - Manage history between sub-repos and their monorepo                *)
(*  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*  SPDX-License-Identifier: MIT                                                 *)
(*********************************************************************************)

(* Smoke tests for the vendored {!Merge3}. The algorithm is upstream's and
   tested there; what is pinned down here is the shape of the edit script
   central depends on, and the degenerate inputs [Myers] never hands it --
   splitting a string on '\n' always yields at least one element, so an empty
   array only ever arrives from a direct caller. *)

let show_edits edits =
  List.iter edits ~f:(fun edit ->
    print_endline
      (match (edit : string Merge3.edit) with
       | Keep l -> Printf.sprintf "  %s" l
       | Delete l -> Printf.sprintf "- %s" l
       | Insert l -> Printf.sprintf "+ %s" l))
;;

let diff a b = Merge3.diff ~eq:String.equal a b

let%expect_test "diff: both sides empty" =
  show_edits (diff [||] [||]);
  [%expect {| |}];
  ()
;;

let%expect_test "diff: from empty" =
  show_edits (diff [||] [| "a"; "b" |]);
  [%expect
    {|
    + a
    + b
    |}];
  ()
;;

let%expect_test "diff: to empty" =
  show_edits (diff [| "a"; "b" |] [||]);
  [%expect
    {|
    - a
    - b
    |}];
  ()
;;

let%expect_test "diff: unchanged" =
  show_edits (diff [| "a"; "b" |] [| "a"; "b" |]);
  [%expect
    {|
      a
      b
    |}];
  ()
;;

let%expect_test "diff: a substitution" =
  show_edits (diff [| "a"; "b"; "c" |] [| "a"; "B"; "c" |]);
  [%expect
    {|
      a
    - b
    + B
      c
    |}];
  ()
;;

let%expect_test "diff: an insertion into the middle" =
  show_edits (diff [| "a"; "c" |] [| "a"; "b"; "c" |]);
  [%expect
    {|
      a
    + b
      c
    |}];
  ()
;;

let%expect_test "diff: a deletion from the middle" =
  show_edits (diff [| "a"; "b"; "c" |] [| "a"; "c" |]);
  [%expect
    {|
      a
    - b
      c
    |}];
  ()
;;

let%expect_test "diff: nothing in common" =
  show_edits (diff [| "a"; "b" |] [| "x"; "y" |]);
  [%expect
    {|
    - a
    - b
    + x
    + y
    |}];
  ()
;;
