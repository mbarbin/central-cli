(*********************************************************************************)
(*  central - Manage history between sub-repos and their monorepo                *)
(*  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*  SPDX-License-Identifier: MIT                                                 *)
(*********************************************************************************)

(* This page runs the real [central] executable (see [Central_test_harness]),
   against a throwaway fake repo (see [Central_test_helpers]) - so what you
   read below is, command for command, exactly what you'd type and see
   yourself, just against a fake `widget` instead of a real subrepo. *)

(* @mdexp.config { snapshot: { lang: "ansi" } } *)

(* @mdexp

# Exporting a change

Most day-to-day edits to a subrepo happen the easy way: you just edit files
under `repo/<name>/` directly in central, like you would any other file, and
commit as usual. The one extra step is telling central to carry that change
out into the subrepo's own history:

```
central export <name> -m "<message>"
```

Say you've just edited `widget`'s README and committed that in central. Not
sure what to do next? `central todo` always knows: *)

let widget = Central.Subrepo.v "widget"
let gadget = Central.Subrepo.v "gadget"
let sprocket = Central.Subrepo.v "sprocket"

let central_path subrepo ~subrepo_path =
  Vcs.Path_in_repo.v
    (Filename.concat
       (Vcs.Path_in_repo.to_string (Central.Subrepo.root subrepo))
       (Vcs.Path_in_repo.to_string subrepo_path))
;;

let%expect_test "export" =
  let vcs = Volgo_git_unix.create () in
  (* [central todo] covers every subrepo present under [repo/], so this fake
     repo is built with a few of them (unlike the other scenarios on this
     page, which only need [widget]) - enough to show the dashboard
     correctly narrows down to only what needs attention - see
     [Central_test_helpers.create]. *)
  let fake_central =
    Central_test_helpers.create ~vcs ~subrepos:[ widget; gadget; sprocket ]
  in
  let { Central_test_helpers.Fake_central.central_root; _ } = fake_central in
  let fake_widget =
    Central_test_helpers.Fake_central.find_exn fake_central ~subrepo:widget
  in
  let readme_path = central_path widget ~subrepo_path:(Vcs.Path_in_repo.v "README.md") in
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
  let harness = Central_test_harness.create ~repo_root:central_root in
  let@ central = Central_test_harness.with_cli harness ~cwd:central_root in
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

     `widget` now has a real new commit, with your message, on top of its
     `subrepo` branch: *)
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
  (* @mdexp

     Checking back in with `central todo` shows `widget`'s row is still
     there, but the next step changed: `export` only advances the
     `subrepo` branch, so `widget`'s own `main` is now behind it - a
     genuine second step, covered in
     [Pushing your changes](push.md), not a leftover of the first: *)
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
    |}]
;;

(* @mdexp

`export` always squashes everything you changed under `repo/<name>/` since
the last export into that one new commit - it doesn't try to replay your
central commits one by one. If you made several commits in central along
the way, only the final state matters; `-m` is the message the subrepo
commit gets.

## If there's nothing to export

Running `export` again right away, with nothing new under `repo/<name>/`,
is a clean error rather than an empty commit - a useful sanity check if
you're not sure whether your change already went out: *)

let%expect_test "nothing to export" =
  let vcs = Volgo_git_unix.create () in
  let fake_central = Central_test_helpers.create ~vcs ~subrepos:[ widget ] in
  let { Central_test_helpers.Fake_central.central_root; _ } = fake_central in
  let harness = Central_test_harness.create ~repo_root:central_root in
  let@ central = Central_test_harness.with_cli harness ~cwd:central_root in
  central [ [ "export"; "widget" ]; [ "-m"; "Nothing changed" ] ];
  (* @mdexp.snapshot *)
  [%expect
    {|
    $ central export widget -m "Nothing changed"
    ==================== widget ====================
    Error: Nothing to export: no changes under "repo/widget" since the last sync.
    [123]
    |}]
;;

(* @mdexp

## Exporting several subrepos at once

Some changes are chores that touch many subrepos the same way - bumping a
shared convention, applying the same fix everywhere. `export` accepts more
than one `REPO` on the command line (or `--all` for every subrepo), and
exports them one after another, in the order given, reusing the same `-m`
message for each: *)

let%expect_test "export several at once" =
  let vcs = Volgo_git_unix.create () in
  let fake_central =
    Central_test_helpers.create ~vcs ~subrepos:[ widget; gadget; sprocket ]
  in
  let { Central_test_helpers.Fake_central.central_root; _ } = fake_central in
  List.iter [ widget; gadget; sprocket ] ~f:(fun subrepo ->
    let readme_path =
      central_path subrepo ~subrepo_path:(Vcs.Path_in_repo.v "README.md")
    in
    Central_test_helpers.append_file
      ~repo_root:central_root
      ~path_in_repo:readme_path
      ~text:"\nSee LICENSE for details.\n";
    Vcs.add vcs ~repo_root:central_root ~path:readme_path);
  let (_ : Vcs.Rev.t) =
    Central_test_helpers.commit
      ~vcs
      ~repo_root:central_root
      ~commit_message:"Add license footer to every subrepo"
  in
  let harness = Central_test_harness.create ~repo_root:central_root in
  let@ central = Central_test_harness.with_cli harness ~cwd:central_root in
  central [ [ "export"; "widget"; "gadget"; "sprocket" ]; [ "-m"; "Add license footer" ] ];
  (* @mdexp.snapshot *)
  [%expect
    {|
    $ central export widget gadget sprocket -m "Add license footer"
    ==================== widget ====================
    [ OK ] Applied patch in the subrepo.
    [ OK ] Exported to [widget].
    ==================== gadget ====================
    [ OK ] Applied patch in the subrepo.
    [ OK ] Exported to [gadget].
    ==================== sprocket ====================
    [ OK ] Applied patch in the subrepo.
    [ OK ] Exported to [sprocket].
    |}];
  central [ [ "todo" ] ];
  (* @mdexp.snapshot *)
  [%expect
    {|
    $ central todo
    ┌────────────┬──────────────┬──────┐
    │ Repo       │ Next step    │ Diff │
    ├────────────┼──────────────┼──────┤
    │ central    │ push         │   18 │
    │   gadget   │ advance-main │      │
    │   sprocket │ advance-main │      │
    │   widget   │ advance-main │      │
    └────────────┴──────────────┴──────┘
    |}]
;;

(* @mdexp

If one of them fails partway through - say a subrepo's `subrepo` branch
moved on its own since the last sync - `export` stops right there: the
repos before it keep whatever they already got exported, and the ones after
it are never even attempted. See `test/expect/export.ml` for that scenario
in detail, along with every other guardrail covered above.

That's the everyday case covered. The next chapter,
[Importing a change](import.md), covers the other direction - bringing
commits made directly in a subrepo's own history back into central. *)
