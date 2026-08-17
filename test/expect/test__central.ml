(*********************************************************************************)
(*  central - Manage history between sub-repos and their monorepo                *)
(*  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*  SPDX-License-Identifier: MIT                                                 *)
(*********************************************************************************)

(* At the moment this test is empty, however this library needs to exist so
   that expect tests have somewhere to live as [central] grows. *)

open! Central

let%expect_test "empty" =
  ();
  [%expect {||}];
  ()
;;
