(*********************************************************************************)
(*  central - Manage history between sub-repos and their monorepo                *)
(*  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*  SPDX-License-Identifier: MIT                                                 *)
(*********************************************************************************)

(* Like [export.ml] and [import.ml], this page runs the real [central]
   executable (see [Central_test_harness]) rather than calling into the
   CLI's OCaml implementation directly. *)

(* @mdexp.config { snapshot: { lang: "ansi" } } *)

(* @mdexp

# Stitch

`central stitch <repo>` is for a narrower situation than `import`:
someone `export`ed a change, then reworked the commit(s) that just landed in
the subrepo's own history - splitting one commit into a nicer sequence,
squashing, reordering, rewording - without changing the tree they arrive at.
`repo/<repo>/.gitrepo` in central still names the pre-rewrite commit, which
no longer exists on the subrepo's `subrepo` branch.

Running `import` at this point would either fail outright (the old commit
isn't an ancestor of the new tip any more) or, if it somehow went through,
apply an empty patch for no reason - there is nothing to actually bring in,
since the tree hasn't changed. `stitch` is the narrow fix: it just repoints
`.gitrepo` at the subrepo's new tip, and commits that update with an
auto-generated message - central's copy of a subrepo isn't public history,
so unlike `export` there's nothing worth writing by hand here.

The required pre-conditions:

1. The `subrepo` branch has actually moved since the last sync.
2. There is no real content diff between the commit recorded in `.gitrepo`
   and the subrepo's current tip - i.e. this really is a pure history
   rewrite.
3. Central has no local changes of its own under `repo/<repo>/` since the
   last sync.

## Rewriting history after an export

Suppose a change lands in central and gets exported as usual, as one
squashed commit: *)

let%expect_test "stitch after a pure history rewrite" =
  let vcs = Volgo_git_unix.create () in
  let widget = Central.Subrepo.v "widget" in
  let fake_central = Central_test_helpers.create ~vcs ~subrepos:[ widget ] in
  let { Central_test_helpers.Fake_central.central_root; _ } = fake_central in
  let fake_widget =
    Central_test_helpers.Fake_central.find_exn fake_central ~subrepo:widget
  in
  let harness = Central_test_harness.create ~repo_root:central_root in
  let@ central = Central_test_harness.with_cli harness ~cwd:central_root in
  (* Export a change, then rewrite the subrepo's history into two commits
     that arrive at the exact same tree - a pure history rewrite. *)
  let readme_path = Vcs.Path_in_repo.v "repo/widget/README.md" in
  Central_test_helpers.append_file
    ~repo_root:central_root
    ~path_in_repo:readme_path
    ~text:"\nDescribe feature A.\n\nDescribe feature B.\n";
  Vcs.add vcs ~repo_root:central_root ~path:readme_path;
  let (_ : Vcs.Rev.t) =
    Central_test_helpers.commit
      ~vcs
      ~repo_root:central_root
      ~commit_message:"Document feature A and B"
  in
  central [ [ "export"; "widget" ]; [ "-m"; "Document feature A and B" ] ];
  (* @mdexp.snapshot *)
  [%expect
    {|
    $ central export widget -m "Document feature A and B"
    ==================== widget ====================
    [ OK ] Applied patch in the subrepo.
    [ OK ] Exported to [widget].
    |}];
  (* @mdexp

     Now, imagine that squashed commit gets reworked directly in `widget`'s
     own history into two smaller, better organized commits - reaching the
     exact same final `README.md` either way. `.gitrepo` still names the
     abandoned squash commit, which no longer exists on `subrepo`: *)
  let readme = Vcs.Path_in_repo.v "README.md" in
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
  Central_test_helpers.append_file
    ~repo_root:fake_widget.repo_root
    ~path_in_repo:readme
    ~text:"\nDescribe feature A.\n";
  Vcs.add vcs ~repo_root:fake_widget.repo_root ~path:readme;
  let (_ : Vcs.Rev.t) =
    Central_test_helpers.commit
      ~vcs
      ~repo_root:fake_widget.repo_root
      ~commit_message:"Document feature A"
  in
  Central_test_helpers.append_file
    ~repo_root:fake_widget.repo_root
    ~path_in_repo:readme
    ~text:"\nDescribe feature B.\n";
  Vcs.add vcs ~repo_root:fake_widget.repo_root ~path:readme;
  let (_ : Vcs.Rev.t) =
    Central_test_helpers.commit
      ~vcs
      ~repo_root:fake_widget.repo_root
      ~commit_message:"Document feature B"
  in
  (* @mdexp

     `import` would refuse here - the commit `.gitrepo` names is gone, so it
     can't tell this apart from a more troubling rewrite. `stitch` recognizes
     it for what it is and just catches `.gitrepo` up, committing the update
     itself with an auto-generated message: *)
  central [ [ "stitch"; "widget" ] ];
  (* @mdexp.snapshot *)
  [%expect
    {|
    $ central stitch widget
    ==================== widget ====================
    [ OK ] Stitched [widget].
    |}];
  Central_test_helpers.print_log_subjects ~vcs ~repo_root:central_root ~ref_:"main" ();
  (* @mdexp.snapshot *)
  [%expect
    {|
    Stitch repo widget
    export widget
    Document feature A and B
    Add fake subrepo widget
    Initial commit
    |}];
  (* @mdexp

     Running `stitch` again right away is a clean error - `.gitrepo` is
     already caught up, so there is nothing left to stitch: *)
  central [ [ "stitch"; "widget" ] ];
  (* @mdexp.snapshot *)
  [%expect
    {|
    $ central stitch widget
    ==================== widget ====================
    File "$CENTRAL_ROOT/repo/widget/.gitrepo", line 1, characters 0-0:
    Error: Nothing to stitch: the [subrepo] branch of [widget] is already the
    commit recorded in [.gitrepo].
    [123]
    |}];
  (* @mdexp

     And `central todo` confirms both sides agree - `widget`'s own `main`
     just needs to catch up, same as after any ordinary `export`: *)
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

## Guardrails

`stitch` only repoints `.gitrepo` - it never brings in real content changes.
If the subrepo's tip actually differs in substance from what `.gitrepo`
records, this isn't a pure history rewrite any more, and `stitch` refuses
rather than silently pretending the trees still match: *)

let%expect_test "nothing to stitch" =
  let vcs = Volgo_git_unix.create () in
  let widget = Central.Subrepo.v "widget" in
  let fake_central = Central_test_helpers.create ~vcs ~subrepos:[ widget ] in
  let { Central_test_helpers.Fake_central.central_root; _ } = fake_central in
  let harness = Central_test_harness.create ~repo_root:central_root in
  let@ central = Central_test_harness.with_cli harness ~cwd:central_root in
  central [ [ "stitch"; "widget" ] ];
  (* @mdexp.snapshot *)
  [%expect
    {|
    $ central stitch widget
    ==================== widget ====================
    File "$CENTRAL_ROOT/repo/widget/.gitrepo", line 1, characters 0-0:
    Error: Nothing to stitch: the [subrepo] branch of [widget] is already the
    commit recorded in [.gitrepo].
    [123]
    |}]
;;

let%expect_test "cannot stitch: real content changes" =
  let vcs = Volgo_git_unix.create () in
  let widget = Central.Subrepo.v "widget" in
  let fake_central = Central_test_helpers.create ~vcs ~subrepos:[ widget ] in
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
    ~text:"\nGenuinely new content.\n";
  Vcs.add vcs ~repo_root:fake_widget.repo_root ~path:readme;
  let (_ : Vcs.Rev.t) =
    Central_test_helpers.commit
      ~vcs
      ~repo_root:fake_widget.repo_root
      ~commit_message:"Genuinely new content"
  in
  let harness = Central_test_harness.create ~repo_root:central_root in
  let@ central = Central_test_harness.with_cli harness ~cwd:central_root in
  central [ [ "stitch"; "widget" ] ];
  (* @mdexp.snapshot *)
  [%expect
    {|
    $ central stitch widget
    ==================== widget ====================
    File "$CENTRAL_ROOT/repo/widget/.gitrepo", line 1, characters 0-0:
    Error: Cannot stitch: "repo/widget" has content changes between the commit
    recorded in [.gitrepo] and its current tip - this isn't a pure history
    rewrite.
    Hint: Use [central import] instead to bring those changes in.
    [123]
    |}]
;;

(* @mdexp

And if central itself has moved on with local changes of its own under
`repo/<repo>/` since the last sync - even alongside an otherwise legitimate
history rewrite upstream - `stitch` refuses too, since a plain re-pointing
of `.gitrepo` can no longer account for the full picture: *)

let%expect_test "central has changes of its own" =
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
    ~text:"\nDescribe feature A.\n";
  Vcs.add vcs ~repo_root:central_root ~path:readme_path;
  let (_ : Vcs.Rev.t) =
    Central_test_helpers.commit
      ~vcs
      ~repo_root:central_root
      ~commit_message:"Document feature A"
  in
  let harness = Central_test_harness.create ~repo_root:central_root in
  let@ central = Central_test_harness.with_cli harness ~cwd:central_root in
  central [ [ "export"; "widget" ]; [ "-m"; "Document feature A" ] ];
  (* @mdexp.snapshot *)
  [%expect
    {|
    $ central export widget -m "Document feature A"
    ==================== widget ====================
    [ OK ] Applied patch in the subrepo.
    [ OK ] Exported to [widget].
    |}];
  (* A pure reword upstream - same tree, different message, so it would
     otherwise be a perfectly legitimate stitch. *)
  Vcs.git
    vcs
    ~repo_root:fake_widget.repo_root
    ~args:[ "checkout"; "subrepo" ]
    ~f:Vcs.Git.exit0;
  Vcs.git
    vcs
    ~repo_root:fake_widget.repo_root
    ~args:[ "commit"; "--amend"; "-m"; "Document feature A (reworded)" ]
    ~f:Vcs.Git.exit0;
  (* Central, meanwhile, made its own unrelated edit under [repo/widget/]
     after the export. *)
  let notes_path = Vcs.Path_in_repo.v "repo/widget/NOTES.md" in
  Central_test_helpers.write_file
    ~repo_root:central_root
    ~path_in_repo:notes_path
    ~contents:"Internal note, never meant for upstream.\n";
  Vcs.add vcs ~repo_root:central_root ~path:notes_path;
  let (_ : Vcs.Rev.t) =
    Central_test_helpers.commit
      ~vcs
      ~repo_root:central_root
      ~commit_message:"Add internal note"
  in
  central [ [ "stitch"; "widget" ] ];
  (* @mdexp.snapshot *)
  [%expect
    {|
    $ central stitch widget
    ==================== widget ====================
    File "$CENTRAL_ROOT/repo/widget/.gitrepo", line 1, characters 0-0:
    Error: Cannot stitch: central has local changes of its own under
    "repo/widget" since the last sync.
    Hint: Export or import those changes first, then stitch.
    [123]
    |}]
;;

(* @mdexp

And as a precondition, `stitch` first checks that `central`'s own working
tree is clean - an unstaged edit is rejected outright, before anything else
is even looked at: *)

let%expect_test "dirty working tree" =
  let vcs = Volgo_git_unix.create () in
  let widget = Central.Subrepo.v "widget" in
  let fake_central = Central_test_helpers.create ~vcs ~subrepos:[ widget ] in
  let { Central_test_helpers.Fake_central.central_root; _ } = fake_central in
  (* Edited, but never [Vcs.add]ed - left unstaged. *)
  Central_test_helpers.append_file
    ~repo_root:central_root
    ~path_in_repo:(Vcs.Path_in_repo.v "README.md")
    ~text:"\nStray, unstaged edit.\n";
  let harness = Central_test_harness.create ~repo_root:central_root in
  let@ central = Central_test_harness.with_cli harness ~cwd:central_root in
  central [ [ "stitch"; "widget" ] ];
  (* @mdexp.snapshot *)
  [%expect
    {|
    $ central stitch widget
    Error: Repo "$CENTRAL_ROOT" has uncommitted changes -
    commit or stash them first.
    Hint: M README.md
    [123]
    |}]
;;
