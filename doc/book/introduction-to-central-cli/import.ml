(*********************************************************************************)
(*  central - Manage history between sub-repos and their monorepo                *)
(*  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*  SPDX-License-Identifier: MIT                                                 *)
(*********************************************************************************)

(* Like [export.ml], this page runs the real [central] executable (see
   [Central_test_harness]), against a throwaway fake repo (see
   [Central_test_helpers]). Fake repos here are built with a few subrepos,
   not just [widget] - [central todo] covers every subrepo present under
   [repo/], and this shows it correctly narrows down to only what needs
   attention among several. *)

(* @mdexp.config { snapshot: { lang: "ansi" } } *)

(* @mdexp

# Importing a change

The other direction: commits made directly in a subrepo's own history -
typically because someone fetched from its real, public remote - don't show
up under `repo/<name>/` in central on their own. Bringing them in is:

```
central import <name>
```

`-m "<message>"` is optional here - it defaults to `"Import changes from
<name>"`. Unlike `export`, `repo/<name>/` in central isn't public history, so
there's rarely anything worth saying beyond that.

Unlike `export`, central may itself have moved on with changes of its own in
the meantime, so `import` has to pick between two ways of bringing the
subrepo's commits in:

- If central hasn't touched `repo/<name>/` at all since the last sync, the
  subrepo's changes are applied straight onto the current commit, as a
  single new commit - no merge, because there is nothing under
  `repo/<name>/` for it to possibly conflict with. This is the default, and
  keeps history linear in the common case.
- Otherwise - central *does* have changes of its own under `repo/<name>/` -
  `import` falls back to an ordinary two-parent `git merge`: it builds a new
  commit carrying the subrepo's changes, then merges it into whatever branch
  you have checked out (normally `main`).

## The default: applying directly

Say new commits landed on `widget`'s own `subrepo` branch (from fetching its
real remote), while central moved on with an unrelated change of its own -
elsewhere, outside `repo/widget/`. `central todo` already knows there's
something to bring in: *)

let widget = Central.Subrepo.v "widget"
let gadget = Central.Subrepo.v "gadget"
let sprocket = Central.Subrepo.v "sprocket"

let central_path subrepo ~subrepo_path =
  Vcs.Path_in_repo.v
    (Filename.concat
       (Vcs.Path_in_repo.to_string (Central.Subrepo.root subrepo))
       (Vcs.Path_in_repo.to_string subrepo_path))
;;

let%expect_test "import" =
  let vcs = Volgo_git_unix.create () in
  let fake_central =
    Central_test_helpers.create ~vcs ~subrepos:[ widget; gadget; sprocket ]
  in
  let { Central_test_helpers.Fake_central.central_root; _ } = fake_central in
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
    ~text:"\nUpstream added a usage example.\n";
  Vcs.add vcs ~repo_root:fake_widget.repo_root ~path:readme;
  let (_ : Vcs.Rev.t) =
    Central_test_helpers.commit
      ~vcs
      ~repo_root:fake_widget.repo_root
      ~commit_message:"Upstream: add usage example"
  in
  (* In real usage, fetching from the real remote and catching [main] up
     with [advance-subrepo] tend to happen close together - keeping [main]
     caught up here too, so the dashboard below is about importing, not
     about a second, unrelated [main] lagging behind. *)
  Vcs.git
    vcs
    ~repo_root:fake_widget.repo_root
    ~args:[ "branch"; "-f"; "main"; "subrepo" ]
    ~f:Vcs.Git.exit0;
  (* Central's own top-level [README.md] - outside [repo/widget/] entirely,
     so it has no bearing on whether [repo/widget/] itself has moved. *)
  Central_test_helpers.append_file
    ~repo_root:central_root
    ~path_in_repo:readme
    ~text:"\nUnrelated central change.\n";
  Vcs.add vcs ~repo_root:central_root ~path:readme;
  let (_ : Vcs.Rev.t) =
    Central_test_helpers.commit
      ~vcs
      ~repo_root:central_root
      ~commit_message:"Unrelated central change"
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
    │   widget │ import    │      │
    └──────────┴───────────┴──────┘
    |}];
  (* @mdexp

     Following it here means importing. Since central never touched
     `repo/widget/`, the change lands directly, with no merge commit: *)
  central [ [ "import"; "widget" ]; [ "-m"; "Bring in upstream usage example" ] ];
  (* @mdexp.snapshot *)
  [%expect
    {|
    $ central import widget -m "Bring in upstream usage example"
    [ OK ] Imported into [main] directly (no merge needed).
    |}];
  (* @mdexp A single, linear commit - no second parent to merge: *)
  Central_test_helpers.print_graph ~vcs ~repo_root:central_root ~refs:[ "main" ];
  (* @mdexp.snapshot *)
  [%expect
    {|
    * Bring in upstream usage example
    * Unrelated central change
    * Add fake subrepo sprocket
    * Add fake subrepo gadget
    * Add fake subrepo widget
    * Initial commit
    |}];
  (* @mdexp `repo/widget/README.md` now carries the upstream change: *)
  Central_test_helpers.print_file
    ~repo_root:central_root
    ~path_in_repo:(central_path widget ~subrepo_path:readme);
  (* @mdexp.snapshot { lang: "markdown" } *)
  [%expect
    {|
    # widget

    This is a fake [widget] repo, generated by [Central_test_helpers] for tests.

    Upstream added a usage example.
    |}];
  (* @mdexp

     And `central todo` shows both central and `widget` with the same,
     ordinary next step - `push`, covered next: *)
  central [ [ "todo" ] ];
  (* @mdexp.snapshot *)
  [%expect
    {|
    $ central todo
    ┌──────────┬───────────┬──────┐
    │ Repo     │ Next step │ Diff │
    ├──────────┼───────────┼──────┤
    │ central  │ push      │    8 │
    │   widget │ push      │      │
    └──────────┴───────────┴──────┘
    |}]
;;

(* @mdexp

## Falling back to a merge

If central *has* touched `repo/widget/` since the last sync - even in a file
the upstream change never went near - `import` can no longer assume
`repo/widget/` is untouched, so it falls back to building a separate import
commit and merging it in, an ordinary two-parent `git merge`: *)

let%expect_test "merge" =
  let vcs = Volgo_git_unix.create () in
  let fake_central =
    Central_test_helpers.create ~vcs ~subrepos:[ widget; gadget; sprocket ]
  in
  let { Central_test_helpers.Fake_central.central_root; _ } = fake_central in
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
    ~text:"\nUpstream added a usage example.\n";
  Vcs.add vcs ~repo_root:fake_widget.repo_root ~path:readme;
  let (_ : Vcs.Rev.t) =
    Central_test_helpers.commit
      ~vcs
      ~repo_root:fake_widget.repo_root
      ~commit_message:"Upstream: add usage example"
  in
  (* Central adds a file of its own directly under [repo/widget/] - a
     different file from the one upstream just touched, so the two are free
     to land side by side without conflicting, but this is enough for
     `repo/widget/` to no longer be untouched. *)
  let notes = central_path widget ~subrepo_path:(Vcs.Path_in_repo.v "NOTES.md") in
  Central_test_helpers.write_file
    ~repo_root:central_root
    ~path_in_repo:notes
    ~contents:"Internal note, never meant for upstream.\n";
  Vcs.add vcs ~repo_root:central_root ~path:notes;
  let (_ : Vcs.Rev.t) =
    Central_test_helpers.commit
      ~vcs
      ~repo_root:central_root
      ~commit_message:"Add internal note"
  in
  let harness = Central_test_harness.create ~repo_root:central_root in
  let@ central = Central_test_harness.with_cli harness ~cwd:central_root in
  central [ [ "import"; "widget" ]; [ "-m"; "Bring in upstream usage example" ] ];
  (* @mdexp.snapshot *)
  [%expect
    {|
    $ central import widget -m "Bring in upstream usage example"
    [ OK ] Built the import commit.
    Merge made by the 'ort' strategy.
     repo/widget/.gitrepo  | 4 ++--
     repo/widget/README.md | 2 ++
     2 files changed, 4 insertions(+), 2 deletions(-)
    [ OK ] Imported into [main].
    |}];
  (* @mdexp

     Unlike the direct case above, the import commit sits as a child of the
     *old* sync point, not of central's HEAD at the time - a separate line
     of history, joined by the merge: *)
  Central_test_helpers.print_graph ~vcs ~repo_root:central_root ~refs:[ "main" ];
  (* @mdexp.snapshot *)
  [%expect
    {|
    *   Merge widget import
    |\
    | * Bring in upstream usage example
    * | Add internal note
    * | Add fake subrepo sprocket
    * | Add fake subrepo gadget
    |/
    * Add fake subrepo widget
    * Initial commit
    |}]
;;

(* @mdexp

## When it doesn't merge cleanly

Falling back to a merge means it can behave like an ordinary `git merge` in
every other way too: if your own central changes happen to touch the exact
same lines the upstream commits did, `import` leaves you in the middle of a
real conflict, markers included: *)

let%expect_test "conflict" =
  let vcs = Volgo_git_unix.create () in
  let fake_central =
    Central_test_helpers.create ~vcs ~subrepos:[ widget; gadget; sprocket ]
  in
  let { Central_test_helpers.Fake_central.central_root; _ } = fake_central in
  let fake_widget =
    Central_test_helpers.Fake_central.find_exn fake_central ~subrepo:widget
  in
  let readme = Vcs.Path_in_repo.v "README.md" in
  let central_readme = central_path widget ~subrepo_path:readme in
  Central_test_helpers.write_file
    ~repo_root:central_root
    ~path_in_repo:central_readme
    ~contents:"# widget, edited by central\n";
  Vcs.add vcs ~repo_root:central_root ~path:central_readme;
  let (_ : Vcs.Rev.t) =
    Central_test_helpers.commit
      ~vcs
      ~repo_root:central_root
      ~commit_message:"Central retitles the README"
  in
  Vcs.git
    vcs
    ~repo_root:fake_widget.repo_root
    ~args:[ "checkout"; "subrepo" ]
    ~f:Vcs.Git.exit0;
  Central_test_helpers.write_file
    ~repo_root:fake_widget.repo_root
    ~path_in_repo:readme
    ~contents:"# widget, retitled upstream\n";
  Vcs.add vcs ~repo_root:fake_widget.repo_root ~path:readme;
  let (_ : Vcs.Rev.t) =
    Central_test_helpers.commit
      ~vcs
      ~repo_root:fake_widget.repo_root
      ~commit_message:"Upstream retitles the README"
  in
  let harness = Central_test_harness.create ~repo_root:central_root in
  let@ central = Central_test_harness.with_cli harness ~cwd:central_root in
  central [ [ "import"; "widget" ]; [ "-m"; "Bring in upstream retitle" ] ];
  (* @mdexp.snapshot *)
  [%expect
    {|
    $ central import widget -m "Bring in upstream retitle"
    [ OK ] Built the import commit.
    Auto-merging repo/widget/README.md
    CONFLICT (content): Merge conflict in repo/widget/README.md
    Automatic merge failed; fix conflicts and then commit the result.
    Error: Merge conflict while importing - resolve the conflicts above in
    [main], then [git add] the resolved files and [git commit] to finish the
    merge.
    Hint: .gitrepo has already been updated as part of the import commit being
    merged - no further action needed there once the merge is complete.
    [123]
    |}];
  (* @mdexp

     Resolve it exactly like you would any git merge conflict - edit the
     file, then `git add` and `git commit`. `.gitrepo` is already updated at
     this point, so there's nothing else to do for the subrepo side of it: *)
  let merge_head =
    Vcs.git
      vcs
      ~repo_root:central_root
      ~args:[ "rev-parse"; "MERGE_HEAD" ]
      ~f:(fun output -> Vcs.Git.exit0_and_stdout output |> String.strip |> Vcs.Rev.v)
  in
  Central_test_harness.register_rev harness ~rev:merge_head;
  print_string
    (Central_test_harness.redact
       harness
       (String.trim
          (Central_test_helpers.read_file
             ~repo_root:central_root
             ~path_in_repo:central_readme)));
  (* @mdexp.snapshot { lang: "text" } *)
  [%expect
    {|
    <<<<<<< HEAD
    # widget, edited by central
    =======
    # widget, retitled upstream
    >>>>>>> 1185512b92d612b25613f2e5b473e5231185512b
    |}];
  Central_test_helpers.write_file
    ~repo_root:central_root
    ~path_in_repo:central_readme
    ~contents:"# widget, retitled (resolved)\n";
  Vcs.add vcs ~repo_root:central_root ~path:central_readme;
  let (_ : Vcs.Rev.t) =
    Central_test_helpers.commit
      ~vcs
      ~repo_root:central_root
      ~commit_message:"Resolve README retitle conflict"
  in
  (* @mdexp

     With the merge committed, `export` is available again right away - it
     carries your resolution out to `widget`, since that's what its own
     history now disagrees with: *)
  central [ [ "export"; "widget" ]; [ "-m"; "Resolve conflicting retitle" ] ];
  (* @mdexp.snapshot *)
  [%expect
    {|
    $ central export widget -m "Resolve conflicting retitle"
    ==================== widget ====================
    [ OK ] Applied patch in the subrepo.
    [ OK ] Exported to [widget].
    |}];
  Central_test_helpers.print_log_subjects
    ~vcs
    ~repo_root:fake_widget.repo_root
    ~ref_:"subrepo"
    ();
  (* @mdexp.snapshot *)
  [%expect
    {|
    Resolve conflicting retitle
    Upstream retitles the README
    Initial commit
    |}];
  (* @mdexp

     `central todo` shows the same pattern as after any `export`: `widget`'s
     own `main` is left one `advance-main` behind its `subrepo` branch -
     nothing to do with the conflict just resolved: *)
  central [ [ "todo" ] ];
  (* @mdexp.snapshot *)
  [%expect
    {|
    $ central todo
    ┌──────────┬──────────────┬──────┐
    │ Repo     │ Next step    │ Diff │
    ├──────────┼──────────────┼──────┤
    │ central  │ push         │    8 │
    │   widget │ advance-main │      │
    └──────────┴──────────────┴──────┘
    |}]
;;

(* @mdexp

Either way, once a change has landed in a subrepo's own history, the last
step is [pushing it out for real](push.md). *)
