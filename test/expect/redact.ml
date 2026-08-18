(*********************************************************************************)
(*  central - Manage history between sub-repos and their monorepo                *)
(*  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*  SPDX-License-Identifier: MIT                                                 *)
(*********************************************************************************)

(* @mdexp

# Deterministic Revisions

Every command that touches git prints real revisions - commit hashes,
`MERGE_HEAD`, the trailing `>>>>>>> <sha>` on a conflict marker - and a real
revision is different every time a test runs, since it's derived from tree
content, parents, and commit timestamps, none of which stay fixed between
runs. Left alone, that would make every snapshot in this book flaky.

`Central_test_harness` fixes this by redacting: every real revision it sees
is auto-detected and rewritten to a deterministic mock counterpart (see the
conflict example in [Import](import.md) for one in the wild), so the same
command run today or a year from now prints the exact same snapshot.
`to_mock_rev`/`register_rev` map a real revision to its mock; `redact`
applies that mapping - and every abbreviated prefix git might plausibly
print for it - to a piece of text.

A mock revision is itself just a 40-character hex string, indistinguishable
from a real one. That has one sharp edge worth pinning down directly: a
mock revision can coincidentally *contain* a run of characters equal to
some other, unrelated revision's abbreviated prefix. `redact` has to
substitute every registered revision starting from the *original* text in a
single pass, so that a mock revision it has already written out is never
handed back for re-examination - otherwise a later, shorter pattern could
match inside it and corrupt it: *)

let%expect_test
    "redact doesn't let one rev's abbreviated prefix corrupt another rev's \
     already-substituted mock"
  =
  let t = Central_test_harness.create ~repo_root:(Vcs.Repo_root.v "/tmp/repo") in
  (* Registered first, so it lands on mock rev counter 0 - deterministically
     ["1185512b92d612b25613f2e5b473e5231185512b"], regardless of
     [first_rev]'s own (arbitrary) value. *)
  let first_rev = Vcs.Rev.v (String.make 40 'a') in
  Central_test_harness.register_rev t ~rev:first_rev;
  (* Crafted so its abbreviated prefix, ["b92d"], is exactly the substring
     sitting at offset 7 of [first_rev]'s mock counterpart above. *)
  let second_rev = Vcs.Rev.v ("b92d" ^ String.make 36 '0') in
  Central_test_harness.register_rev t ~rev:second_rev;
  print_string (Central_test_harness.redact t (Vcs.Rev.to_string first_rev));
  (* @mdexp.snapshot { lang: "text" } *)
  [%expect {| 1185512b92d612b25613f2e5b473e5231185512b |}]
;;
