(*********************************************************************************)
(*  central - Manage history between sub-repos and their monorepo                *)
(*  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*  SPDX-License-Identifier: MIT                                                 *)
(*********************************************************************************)

(* Like [export.ml], this runs the real [central] executable (see
   [Central_test_harness]) rather than calling into the CLI's OCaml
   implementation directly. *)

(* @mdexp.config { snapshot: { lang: "ansi" } } *)

(* @mdexp

# Advance Main, Advance Subrepo

`export` only ever moves a subrepo's `subrepo` branch - it never touches
`main`, so `main` falls one commit behind after every export. Two commands
catch it back up, at different scopes:

- `central advance-main <repo>` fast-forwards that subrepo's local `main`
  branch to match `subrepo`, from the same machine an `export` (or `import`)
  just ran on - the everyday, single-machine case.
- `central advance-subrepo <repo>` is the more thorough version, aimed at a
  *second* machine: after pulling central's own `main` (which brings in
  whatever `.gitrepo` now says), it fast-forwards that subrepo's local
  `subrepo` *and* `main` branches to match - both in one go, provided the
  commit `.gitrepo` points to is already present locally (e.g. already
  fetched from the subrepo's real remote - `advance-subrepo` itself never
  fetches anything).

## Advance-main, right after an export

`export` lands a commit on `widget`'s `subrepo` branch - `main` hasn't
moved: *)

let%expect_test "advance-main after export" =
  let vcs = Volgo_git_unix.create () in
  let widget = Central.Subrepo.v "widget" in
  let fake_central = Central_test_helpers.create ~vcs ~subrepos:[ widget ] in
  let { Central_test_helpers.Fake_central.central_root; _ } = fake_central in
  let fake_widget =
    Central_test_helpers.Fake_central.find_exn fake_central ~subrepo:widget
  in
  let readme_path = Vcs.Path_in_repo.v "repo/widget/README.md" in
  Central_test_helpers.append_file
    ~repo_root:central_root
    ~path_in_repo:readme_path
    ~text:"\nAdded a line about installation.\n";
  Vcs.add vcs ~repo_root:central_root ~path:readme_path;
  let (_ : Vcs.Rev.t) =
    Central_test_helpers.commit
      ~vcs
      ~repo_root:central_root
      ~commit_message:"Document installation"
  in
  let harness = Central_test_harness.create ~repo_root:central_root in
  let@ central = Central_test_harness.with_cli harness ~cwd:central_root in
  central [ [ "export"; "widget" ]; [ "-m"; "Document installation" ] ];
  [%expect
    {|
    $ central export widget -m "Document installation"
    ==================== widget ====================
    [ OK ] Applied patch in the subrepo.
    [ OK ] Exported to [widget].
    |}];
  (* [export] only moved [subrepo] - [main] is now a strict ancestor of it.
     The "Updating X..Y" summary line below prints abbreviated shas that
     [Central_test_harness] can only redact if the full sha was registered
     first - it isn't printed in full anywhere in this transcript otherwise. *)
  let rev_of ~ref_ =
    Vcs.git
      vcs
      ~repo_root:fake_widget.repo_root
      ~args:[ "rev-parse"; ref_ ]
      ~f:(fun output -> Vcs.Git.exit0_and_stdout output |> String.strip |> Vcs.Rev.v)
  in
  Central_test_harness.register_rev harness ~rev:(rev_of ~ref_:"main");
  Central_test_harness.register_rev harness ~rev:(rev_of ~ref_:"subrepo");
  central [ [ "advance-main"; "widget" ] ];
  (* @mdexp.snapshot *)
  [%expect
    {|
    $ central advance-main widget
    ==================== widget ====================
    Updating 1185512..f452a6f
    Fast-forward
     README.md | 2 ++
     1 file changed, 2 insertions(+)
    |}];
  (* @mdexp `main` is fast-forwarded to the same commit `subrepo` already carried: *)
  Central_test_helpers.print_log_subjects
    ~vcs
    ~repo_root:fake_widget.repo_root
    ~ref_:"main"
    ();
  (* @mdexp.snapshot *)
  [%expect
    {|
    Document installation
    Initial commit
    |}]
;;

(* @mdexp

Right after `Central_test_helpers.create`, there's nothing for `main` to
catch up to: *)

let%expect_test "advance-main not applicable" =
  let vcs = Volgo_git_unix.create () in
  let widget = Central.Subrepo.v "widget" in
  let fake_central = Central_test_helpers.create ~vcs ~subrepos:[ widget ] in
  let { Central_test_helpers.Fake_central.central_root; _ } = fake_central in
  let harness = Central_test_harness.create ~repo_root:central_root in
  let@ central = Central_test_harness.with_cli harness ~cwd:central_root in
  central [ [ "advance-main"; "widget" ] ];
  (* @mdexp.snapshot *)
  [%expect
    {|
    $ central advance-main widget
    ==================== widget ====================
    [SKIP] Skipping [advance-main] (not applicable).
    |}]
;;

(* @mdexp

## Advance-subrepo, catching up a fresh checkout on another machine

Say a change was already exported and pushed from elsewhere: central's own
`.gitrepo` (as pulled from its real remote) now points at a newer `widget`
commit, already fetched into this machine's own checkout of `widget` (e.g.
by a plain `git fetch`, run once ahead of time), but not yet merged into
either its `subrepo` or `main` branch. `advance-subrepo` brings both up to
date in one command: *)

let%expect_test "advance-subrepo catches up a stale local checkout" =
  let vcs = Volgo_git_unix.create () in
  let widget = Central.Subrepo.v "widget" in
  let fake_central = Central_test_helpers.create ~vcs ~subrepos:[ widget ] in
  let { Central_test_helpers.Fake_central.central_root; _ } = fake_central in
  let fake_widget =
    Central_test_helpers.Fake_central.find_exn fake_central ~subrepo:widget
  in
  let readme_path = Vcs.Path_in_repo.v "repo/widget/README.md" in
  Central_test_helpers.append_file
    ~repo_root:central_root
    ~path_in_repo:readme_path
    ~text:"\nAdded a line about installation.\n";
  Vcs.add vcs ~repo_root:central_root ~path:readme_path;
  let (_ : Vcs.Rev.t) =
    Central_test_helpers.commit
      ~vcs
      ~repo_root:central_root
      ~commit_message:"Document installation"
  in
  let harness = Central_test_harness.create ~repo_root:central_root in
  Central_test_harness.run
    harness
    ~cwd:central_root
    [ [ "export"; "widget" ]; [ "-m"; "Document installation" ] ];
  [%expect
    {|
    $ central export widget -m "Document installation"
    ==================== widget ====================
    [ OK ] Applied patch in the subrepo.
    [ OK ] Exported to [widget].
    |}];
  (* Simulate this machine's local checkout of [widget] not having its
     [subrepo]/[main] branches advanced to the latest commit yet, even
     though central's [.gitrepo] (as synced from another machine) already
     points at it. The commit itself must stay reachable from some local
     ref for [advance-subrepo] to find it at all - as it would be in
     practice via a remote-tracking ref, once fetched - so tag it before
     winding [subrepo] back, rather than orphaning it outright. *)
  let rev_of ~ref_ =
    Vcs.git
      vcs
      ~repo_root:fake_widget.repo_root
      ~args:[ "rev-parse"; ref_ ]
      ~f:(fun output -> Vcs.Git.exit0_and_stdout output |> String.strip)
  in
  let new_rev = rev_of ~ref_:"subrepo" in
  Vcs.git
    vcs
    ~repo_root:fake_widget.repo_root
    ~args:[ "tag"; "keep-reachable"; new_rev ]
    ~f:Vcs.Git.exit0;
  Central_test_harness.register_rev harness ~rev:(Vcs.Rev.v new_rev);
  Central_test_harness.register_rev harness ~rev:(Vcs.Rev.v (rev_of ~ref_:"main"));
  Vcs.git
    vcs
    ~repo_root:fake_widget.repo_root
    ~args:[ "checkout"; "subrepo" ]
    ~f:Vcs.Git.exit0;
  Vcs.git
    vcs
    ~repo_root:fake_widget.repo_root
    ~args:[ "reset"; "--hard"; "HEAD~1" ]
    ~f:Vcs.Git.exit0;
  let@ central = Central_test_harness.with_cli harness ~cwd:central_root in
  central [ [ "advance-subrepo"; "widget" ] ];
  (* @mdexp.snapshot *)
  [%expect
    {|
    $ central advance-subrepo widget
    ==================== widget ====================
    Updating f452a6f..1185512
    Fast-forward
     README.md | 2 ++
     1 file changed, 2 insertions(+)
    Updating f452a6f..1185512
    Fast-forward
     README.md | 2 ++
     1 file changed, 2 insertions(+)
    |}];
  (* @mdexp `subrepo` is on the new commit now: *)
  Central_test_helpers.print_log_subjects
    ~vcs
    ~repo_root:fake_widget.repo_root
    ~ref_:"subrepo"
    ();
  (* @mdexp.snapshot *)
  [%expect
    {|
    Document installation
    Initial commit
    |}];
  (* @mdexp And so is `main` - both branches now point at the very same commit: *)
  Central_test_helpers.print_log_subjects
    ~vcs
    ~repo_root:fake_widget.repo_root
    ~ref_:"main"
    ();
  (* @mdexp.snapshot *)
  [%expect
    {|
    Document installation
    Initial commit
    |}]
;;
