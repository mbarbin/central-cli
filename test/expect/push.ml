(*********************************************************************************)
(*  central - Manage history between sub-repos and their monorepo                *)
(*  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*  SPDX-License-Identifier: MIT                                                 *)
(*********************************************************************************)

(* Like [export.ml], this runs the real [central] executable (see
   [Central_test_harness]) rather than calling into the CLI's OCaml
   implementation directly. Each fake repo built by [Central_test_helpers]
   has its own real, separate bare remote (never a real, production one), so
   the pushes below are genuine - their effect is verified by reading
   straight from that remote afterwards. *)

(* @mdexp.config { snapshot: { lang: "ansi" } } *)

(* @mdexp

# Push

`central push <repo>...` pushes the given repo's (or repos') `main` branch
to its real remote - the final step once a change has made its way all the
way to a subrepo's own `main` (via `export`, then `advance-main` if needed),
or simply for central's own local commits.

By default, before pushing, it opens `gitk --all` to visualize the history
and asks for confirmation; every example below passes `--yes` to skip both,
the way this would run non-interactively (e.g. from a script or CI).

## Nothing to push

Right after `Central_test_helpers.create`, every repo's `main` is already
up to date with its own remote - pushing is a clean no-op: *)

let%expect_test "nothing to push" =
  let vcs = Volgo_git_unix.create () in
  let fake_central = Central_test_helpers.create ~vcs ~subrepos:[] in
  let { Central_test_helpers.Fake_central.central_root; _ } = fake_central in
  let harness = Central_test_harness.create ~repo_root:central_root in
  let@ central = Central_test_harness.with_cli harness ~cwd:central_root in
  central [ [ "push"; "central"; "--yes" ] ];
  (* @mdexp.snapshot *)
  [%expect
    {|
    $ central push central --yes
    ==================== central ====================
    [SKIP] Skipping [push] (not applicable).
    |}]
;;

(* @mdexp

## Pushing central's own commits

Once central has a local commit its remote doesn't have yet, `push` is
applicable, and sends it there. Here, that commit comes from `import`ing an
upstream change from `widget` - the everyday way central ends up with
something to push: *)

(* Creates a fresh fake central repo with one commit not yet pushed to its
   remote - by importing an upstream change from the [widget] subrepo. *)
let create_central_with_unpushed_commit vcs =
  let widget = Central.Subrepo.v "widget" in
  let fake_central = Central_test_helpers.create ~vcs ~subrepos:[ widget ] in
  let { Central_test_helpers.Fake_central.central_root; central_remote_root; subrepos } =
    fake_central
  in
  let fake_widget =
    Central_test_helpers.Fake_central.find_exn fake_central ~subrepo:widget
  in
  let readme = Vcs.Path_in_repo.v "README.md" in
  Vcs.git
    vcs
    ~repo_root:fake_widget.repo_root
    ~args:[ "checkout"; "subrepo" ]
    ~f:Vcs.Git.exit0;
  Central_test_helpers.append_file
    ~repo_root:fake_widget.repo_root
    ~path_in_repo:readme
    ~text:"\nEdited directly upstream.\n";
  Vcs.add vcs ~repo_root:fake_widget.repo_root ~path:readme;
  let (_ : Vcs.Rev.t) =
    Central_test_helpers.commit
      ~vcs
      ~repo_root:fake_widget.repo_root
      ~commit_message:"Edited directly upstream"
  in
  let harness = Central_test_harness.create ~repo_root:central_root in
  Central_test_harness.run harness ~cwd:central_root [ [ "import"; "widget" ] ];
  ignore (subrepos : Central_test_helpers.Fake_subrepo.t list);
  harness, central_root, central_remote_root
;;

let%expect_test "push central" =
  let vcs = Volgo_git_unix.create () in
  let harness, central_root, central_remote_root =
    create_central_with_unpushed_commit vcs
  in
  (* Before pushing, the remote hasn't seen the import commit yet. *)
  Central_test_helpers.print_log_subjects
    ~vcs
    ~repo_root:central_remote_root
    ~ref_:"main"
    ();
  (* @mdexp.snapshot *)
  [%expect
    {|
    $ central import widget
    [ OK ] Imported into [main] directly (no merge needed).
    Add fake subrepo widget
    Initial commit
    |}];
  let@ central = Central_test_harness.with_cli harness ~cwd:central_root in
  central [ [ "push"; "central"; "--yes" ] ];
  (* @mdexp.snapshot *)
  [%expect
    {|
    $ central push central --yes
    ==================== central ====================
    [ OK ] Pushed.
    |}];
  (* @mdexp

     The commit really is on the remote now - reading its log directly
     (rather than trusting `central`'s own say-so) confirms it: *)
  Central_test_helpers.print_log_subjects
    ~vcs
    ~repo_root:central_remote_root
    ~ref_:"main"
    ();
  (* @mdexp.snapshot *)
  [%expect
    {|
    Import changes from widget
    Add fake subrepo widget
    Initial commit
    |}]
;;

(* @mdexp

## Pushing a subrepo

The same, for a subrepo's own `main` - as it would be after a change went
through `export` (and `advance-main`, catching `main` up to the `subrepo`
branch export landed on). Here, to isolate what `push` itself does, `main`
gets a commit directly: *)

let%expect_test "push subrepo" =
  let vcs = Volgo_git_unix.create () in
  let widget = Central.Subrepo.v "widget" in
  let fake_central = Central_test_helpers.create ~vcs ~subrepos:[ widget ] in
  let { Central_test_helpers.Fake_central.central_root; _ } = fake_central in
  let fake_widget =
    Central_test_helpers.Fake_central.find_exn fake_central ~subrepo:widget
  in
  let readme = Vcs.Path_in_repo.v "README.md" in
  Central_test_helpers.append_file
    ~repo_root:fake_widget.repo_root
    ~path_in_repo:readme
    ~text:"\nDirect edit in widget.\n";
  Vcs.add vcs ~repo_root:fake_widget.repo_root ~path:readme;
  let (_ : Vcs.Rev.t) =
    Central_test_helpers.commit
      ~vcs
      ~repo_root:fake_widget.repo_root
      ~commit_message:"Direct edit in widget"
  in
  let harness = Central_test_harness.create ~repo_root:central_root in
  let@ central = Central_test_harness.with_cli harness ~cwd:central_root in
  central [ [ "push"; "widget" ]; [ "--yes" ] ];
  (* @mdexp.snapshot *)
  [%expect
    {|
    $ central push widget --yes
    ==================== widget ====================
    [ OK ] Pushed.
    |}];
  Central_test_helpers.print_log_subjects
    ~vcs
    ~repo_root:fake_widget.remote_root
    ~ref_:"main"
    ();
  (* @mdexp.snapshot *)
  [%expect
    {|
    Direct edit in widget
    Initial commit
    |}]
;;

(* @mdexp

`--dry-run`/interactive mode (the default) opens `gitk --all` to preview the
history before confirming - which needs a real display and isn't something
this book can exercise deterministically. The "not applicable" guard is
checked before the preview, though, so that much is safe to demonstrate
regardless of confirm mode: *)

let%expect_test "push with --dry-run, nothing to push" =
  let vcs = Volgo_git_unix.create () in
  let fake_central = Central_test_helpers.create ~vcs ~subrepos:[] in
  let { Central_test_helpers.Fake_central.central_root; _ } = fake_central in
  let harness = Central_test_harness.create ~repo_root:central_root in
  let@ central = Central_test_harness.with_cli harness ~cwd:central_root in
  central [ [ "push"; "central"; "--dry-run" ] ];
  (* @mdexp.snapshot *)
  [%expect
    {|
    $ central push central --dry-run
    ==================== central ====================
    [SKIP] Skipping [push] (not applicable).
    |}]
;;
