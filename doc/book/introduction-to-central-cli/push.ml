(*********************************************************************************)
(*  central - Manage history between sub-repos and their monorepo                *)
(*  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*  SPDX-License-Identifier: MIT                                                 *)
(*********************************************************************************)

(* Like [export.ml] and [import.ml], this page runs the real [central]
   executable against a throwaway fake repo - including a real, separate
   bare remote (never a real, production one) for central and for `widget`,
   so the pushes below are genuine. Built with a few subrepos, not just
   `widget`, so [central todo]'s dashboard has more than one row to narrow
   down. *)

(* @mdexp.config { snapshot: { lang: "ansi" } } *)

(* @mdexp

# Pushing your changes

`export` (and `advance-main`, when needed) bring a change all the way to a
subrepo's own `main` branch - but only in your local checkout. The last
step is getting it out to the subrepo's real remote:

```
central push <name>
```

`central` itself needs the same treatment: any local commit not yet on its
own remote (including, as you're about to see, the one `export` itself just
made to update `.gitrepo`). By default `push` opens `gitk` to show you what
you're about to push and asks for confirmation; pass `--yes` to skip both
and push right away.

## Finishing the loop

Picking up where [Exporting a change](export.md) left off: `widget`'s
README was edited in central and committed there. `central todo` is the
constant thread through all of this - it's what tells you export is next: *)

let widget = Central.Subrepo.v "widget"
let gadget = Central.Subrepo.v "gadget"
let sprocket = Central.Subrepo.v "sprocket"

let central_path subrepo ~subrepo_path =
  Vcs.Path_in_repo.v
    (Filename.concat
       (Vcs.Path_in_repo.to_string (Central.Subrepo.root subrepo))
       (Vcs.Path_in_repo.to_string subrepo_path))
;;

let%expect_test "push" =
  let vcs = Volgo_git_unix.create () in
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

     Checking back in, `widget`'s next step changed - `export` only moved
     its `subrepo` branch, so `main` is now behind it: *)
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
  (* @mdexp `advance-main` catches it up: *)
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
  (* @mdexp

     Now both central and `widget` have local commits their remotes don't
     have yet - the dashboard agrees, with the same next step for both: *)
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
  (* @mdexp `push` sends them all in one go: *)
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

     And the dashboard is clear - back where it started, the change now
     genuinely out, all the way to both real remotes: *)
  central [ [ "todo" ] ];
  (* @mdexp.snapshot *)
  [%expect {| $ central todo |}]
;;

(* @mdexp

That's the full loop, start to finish: edit under `repo/<name>/`, `export`
it, `advance-main` if `main` is left behind, `push` - and `central todo`
tells you what's next at every step along the way. *)
