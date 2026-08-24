(*********************************************************************************)
(*  central - Manage history between sub-repos and their monorepo                *)
(*  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*  SPDX-License-Identifier: MIT                                                 *)
(*********************************************************************************)

open! Central

(* @mdexp

# Subrepo

`Central.Subrepo.t` identifies one of the sub-repos vendored under `repo/`
in the enclosing monorepo. It isn't a fixed, hand-maintained enum: it's just
a validated string (the directory name under `repo/`), and the set of known
sub-repos is discovered dynamically by walking the filesystem.

## Discovery

`all` walks `repo/`'s direct children and keeps the ones that contain a
`.gitrepo` file, sorted by name: *)

let%expect_test "Subrepo.all" =
  let vcs = Volgo_git_unix.create () in
  let widget = Subrepo.v "widget" in
  let gadget = Subrepo.v "gadget" in
  let fake_central = Central_test_helpers.create ~vcs ~subrepos:[ widget; gadget ] in
  let { Central_test_helpers.Fake_central.central_root; _ } = fake_central in
  List.iter (Subrepo.all ~repo_root:central_root) ~f:(fun t ->
    print_endline (Subrepo.to_string t));
  [%expect
    {|
    gadget
    widget
    |}]
;;

(* @mdexp

`find_on_disk` looks a sub-repo name up against `all` - unlike `of_string`,
it validates that the name actually names a vendored sub-repo, not merely
that it has the right shape: *)

let%expect_test "Subrepo.find_on_disk" =
  let vcs = Volgo_git_unix.create () in
  let widget = Subrepo.v "widget" in
  let fake_central = Central_test_helpers.create ~vcs ~subrepos:[ widget ] in
  let { Central_test_helpers.Fake_central.central_root; _ } = fake_central in
  let print_find name =
    print_dyn
      (Subrepo.find_on_disk ~repo_root:central_root ~name |> Dyn.option Subrepo.to_dyn)
  in
  print_find "widget";
  [%expect {| Some "widget" |}];
  print_find "does-not-exist";
  [%expect {| None |}]
;;

(* @mdexp

## Manipulating paths

Unlike `all` and `find_on_disk` above, everything in this section is pure
path manipulation: none of it reads the filesystem, or confirms that
anything it is given actually exists on disk.

`root` and `gitrepo_file_path` locate a sub-repo's own directory, and its
`.gitrepo` file, as paths in the enclosing monorepo: *)

let%expect_test "Subrepo.root, Subrepo.gitrepo_file_path" =
  let widget = Subrepo.v "widget" in
  print_endline (Vcs.Path_in_repo.to_string (Subrepo.root widget));
  [%expect {| repo/widget |}];
  print_endline (Vcs.Path_in_repo.to_string (Subrepo.gitrepo_file_path widget));
  [%expect {| repo/widget/.gitrepo |}]
;;

(* @mdexp

`central_path` and `subrepo_path` convert a path back and forth between the
two frames of reference a path can be expressed in: relative to the
sub-repo's own root (what the sub-repo's standalone checkout sees), or
relative to the enclosing monorepo (prefixed with `root`, what the monorepo
checkout sees): *)

let print_subrepo_path t ~central_path =
  print_dyn (Subrepo.subrepo_path t ~central_path |> Dyn.option Vcs.Path_in_repo.to_dyn)
;;

let%expect_test "Subrepo.central_path, Subrepo.subrepo_path" =
  let widget = Subrepo.v "widget" in
  let subrepo_path = Vcs.Path_in_repo.v "src/dune" in
  let central_path = Subrepo.central_path widget ~subrepo_path in
  print_endline (Vcs.Path_in_repo.to_string central_path);
  (* @mdexp.snapshot { lang: "text" } *)
  [%expect {| repo/widget/src/dune |}];
  print_subrepo_path widget ~central_path;
  [%expect {| Some "src/dune" |}]
;;

(* @mdexp

`subrepo_path` returns `None` for a path that doesn't belong to the
sub-repo at all - and, since a path in the sub-repo's own repo is never
empty, for the sub-repo's root itself: *)

let%expect_test "Subrepo.subrepo_path, not under root" =
  let widget = Subrepo.v "widget" in
  print_subrepo_path widget ~central_path:(Vcs.Path_in_repo.v "README.md");
  [%expect {| None |}];
  print_subrepo_path widget ~central_path:(Vcs.Path_in_repo.v "repo/widget");
  [%expect {| None |}]
;;
