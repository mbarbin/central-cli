(*********************************************************************************)
(*  central - Manage history between sub-repos and their monorepo                *)
(*  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*  SPDX-License-Identifier: MIT                                                 *)
(*********************************************************************************)

(* Like [export.ml], this page runs the real [central] executable (see
   [Central_test_harness]) rather than calling into the CLI's OCaml
   implementation directly - so what you read below is, command for command,
   what a [central] user would type and see in their own terminal. *)

(* @mdexp.config { snapshot: { lang: "ansi" } } *)

(* @mdexp

# A day-to-day workflow

This walks through the everyday loop of working in `central`: edit
something, check `central todo` for what needs attention, act on it, and
confirm the dashboard is clear again.

`central todo`'s dashboard covers every subrepo `central` knows about, so
this fake repo (unlike the one on the [Export](export.md) page) is built
with a few of them, not just `widget` - enough to show the dashboard
correctly narrows down to only what needs attention. *)

let%expect_test "empty dashboard" =
  let vcs = Volgo_git_unix.create () in
  let widget = Central.Subrepo.v "widget" in
  let gadget = Central.Subrepo.v "gadget" in
  let sprocket = Central.Subrepo.v "sprocket" in
  let fake_central =
    Central_test_helpers.create ~vcs ~subrepos:[ widget; gadget; sprocket ]
  in
  let { Central_test_helpers.Fake_central.central_root; _ } = fake_central in
  let harness = Central_test_harness.create ~repo_root:central_root in
  let@ central = Central_test_harness.with_cli harness ~cwd:central_root in
  (* @mdexp With nothing out of the ordinary going on, the dashboard is empty: *)
  central [ [ "todo" ] ];
  (* @mdexp.snapshot *)
  [%expect {| $ central todo |}]
;;

(* @mdexp

## Editing directly in central

Suppose someone edits `repo/widget/README.md` directly from within `central`
and commits it there - the way most day-to-day changes happen. *)

let%expect_test "edit, todo, export, todo again" =
  let vcs = Volgo_git_unix.create () in
  let widget = Central.Subrepo.v "widget" in
  let gadget = Central.Subrepo.v "gadget" in
  let sprocket = Central.Subrepo.v "sprocket" in
  let fake_central =
    Central_test_helpers.create ~vcs ~subrepos:[ widget; gadget; sprocket ]
  in
  let { Central_test_helpers.Fake_central.central_root; _ } = fake_central in
  let fake_widget =
    Central_test_helpers.Fake_central.find_exn fake_central ~subrepo:widget
  in
  let harness = Central_test_harness.create ~repo_root:central_root in
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
      ~commit_message:"Document installation in widget's README"
  in
  let@ central = Central_test_harness.with_cli harness ~cwd:central_root in
  (* @mdexp `central todo` now shows `widget` needs attention: *)
  central [ [ "todo" ] ];
  (* @mdexp.snapshot *)
  [%expect
    {|
    $ central todo
    ┌──────────┬───────────┬──────┐
    │ Repo     │ Next step │ Diff │
    ├──────────┼───────────┼──────┤
    │ central  │ push      │    2 │
    │   widget │ export    │    2 │
    └──────────┴───────────┴──────┘
    |}];
  (* @mdexp Following it means exporting: *)
  central [ [ "export"; "widget" ]; [ "-m"; "Document installation" ] ];
  (* @mdexp.snapshot *)
  [%expect
    {|
    $ central export widget -m "Document installation"
    ==================== widget ====================
    [ OK ] Applied patch in the subrepo.
    [ OK ] Exported to [widget].
    |}];
  (* @mdexp

     `widget`'s row is still there, but the next step changed: `export` only
     advances the subrepo's `subrepo` branch, so `widget`'s own `main` branch
     is now behind it. This is a genuine second step, not a leftover of the
     first: *)
  central [ [ "todo" ] ];
  (* @mdexp.snapshot *)
  [%expect
    {|
    $ central todo
    ┌──────────┬──────────────┬──────┐
    │ Repo     │ Next step    │ Diff │
    ├──────────┼──────────────┼──────┤
    │ central  │ push         │    6 │
    │   widget │ advance-main │      │
    └──────────┴──────────────┴──────┘
    |}];
  (* [git merge --ff-only]'s own "Updating <old>..<new>" summary below prints
     abbreviated revisions, which the harness can only rewrite if it already
     knows the full ones - register widget's [main] (the "old" side) and
     [subrepo] (the "new" side, [export]'s new commit) ahead of time. *)
  let rev_of ~ref_ =
    Vcs.git
      vcs
      ~repo_root:fake_widget.repo_root
      ~args:[ "rev-parse"; ref_ ]
      ~f:(fun output -> Vcs.Git.exit0_and_stdout output |> String.strip |> Vcs.Rev.v)
  in
  Central_test_harness.register_rev harness ~rev:(rev_of ~ref_:"main");
  Central_test_harness.register_rev harness ~rev:(rev_of ~ref_:"subrepo");
  (* @mdexp `advance-main` is exactly that: catch `widget`'s `main` branch up: *)
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
  (* @mdexp

     `widget` is left with a `push` next step, same as `central` itself: both
     now have local commits their own remote doesn't have yet - central's
     edit and the `.gitrepo` update `export` made, and the commit
     `advance-main` just fast-forwarded `widget`'s own `main` to: *)
  central [ [ "todo" ] ];
  (* @mdexp.snapshot *)
  [%expect
    {|
    $ central todo
    ┌──────────┬───────────┬──────┐
    │ Repo     │ Next step │ Diff │
    ├──────────┼───────────┼──────┤
    │ central  │ push      │    6 │
    │   widget │ push      │      │
    └──────────┴───────────┴──────┘
    |}];
  (* @mdexp

     `push` closes the loop for both at once - a real `git push` to each
     one's own remote: *)
  central [ [ "push"; "central"; "widget" ]; [ "--yes" ] ];
  (* @mdexp.snapshot *)
  [%expect
    {|
    $ central push central widget --yes
    ==================== central ====================
    [ OK ] Pushed.
    ==================== widget ====================
    [ OK ] Pushed.
    |}];
  (* @mdexp

     And the dashboard is clear again - back where we started, the change
     now genuinely out, all the way to both real remotes: *)
  central [ [ "todo" ] ];
  (* @mdexp.snapshot *)
  [%expect {| $ central todo |}]
;;
