(*********************************************************************************)
(*  central - Manage history between sub-repos and their monorepo                *)
(*  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*  SPDX-License-Identifier: MIT                                                 *)
(*********************************************************************************)

(* Like [export.ml] and [import.ml], this page runs the real [central]
   executable (see [Central_test_harness]), against a throwaway fake repo
   (see [Central_test_helpers]). *)

(* @mdexp.config { snapshot: { lang: "ansi" } } *)

(* @mdexp

# Stitching a rewritten history

A narrower situation than [importing a change](import.md): you `export`ed a
change, then reworked the commit(s) that just landed in the subrepo's own
history - splitting it into a nicer sequence, rewording, reordering -
without changing the content it arrives at. `repo/<name>/.gitrepo` in
central still names the pre-rewrite commit, which doesn't exist on the
subrepo's `subrepo` branch any more.

`import` isn't the right tool here: there is nothing to actually bring in,
since the content hasn't changed - only the commit(s) carrying it have. The
fix is:

```
central stitch <name>
```

which simply repoints `.gitrepo` at the subrepo's new tip and commits that
update itself, with an auto-generated message - central's copy of a subrepo
isn't public history, so unlike `export` there's nothing worth writing by
hand here.

Say `widget`'s README got a couple of new paragraphs, exported as usual: *)

let widget = Central.Subrepo.v "widget"

let central_path subrepo ~subrepo_path =
  Vcs.Path_in_repo.v
    (Filename.concat
       (Vcs.Path_in_repo.to_string (Central.Subrepo.root subrepo))
       (Vcs.Path_in_repo.to_string subrepo_path))
;;

let%expect_test "stitch" =
  let vcs = Volgo_git_unix.create () in
  let fake_central = Central_test_helpers.create ~vcs ~subrepos:[ widget ] in
  let { Central_test_helpers.Fake_central.central_root; _ } = fake_central in
  let fake_widget =
    Central_test_helpers.Fake_central.find_exn fake_central ~subrepo:widget
  in
  let readme_path = central_path widget ~subrepo_path:(Vcs.Path_in_repo.v "README.md") in
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
  let harness = Central_test_harness.create ~repo_root:central_root in
  let@ central = Central_test_harness.with_cli harness ~cwd:central_root in
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

     Now imagine that squashed commit gets reworked directly in `widget`'s
     own history into two smaller commits instead - reaching the exact same
     final `README.md` either way: *)
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
  Central_test_helpers.print_log_subjects
    ~vcs
    ~repo_root:fake_widget.repo_root
    ~ref_:"subrepo"
    ();
  (* @mdexp.snapshot *)
  [%expect
    {|
    Document feature B
    Document feature A
    Initial commit
    |}];
  (* @mdexp

     `import` would refuse at this point - the commit `.gitrepo` names is
     gone, so it can't tell this apart from history that was reset or
     rewritten in some more troubling way. `stitch` recognizes it for what
     it is and just catches `.gitrepo` up: *)
  central [ [ "stitch"; "widget" ] ];
  (* @mdexp.snapshot *)
  [%expect
    {|
    $ central stitch widget
    ==================== widget ====================
    [ OK ] Stitched [widget].
    |}];
  (* @mdexp

     `central todo` shows the same pattern as after any `export` - `widget`'s
     own `main` is one `advance-main` behind, nothing to do with the rewrite
     just stitched over: *)
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

`stitch` refuses if the subrepo's tip has any real content diff against what
`.gitrepo` records - that would mean actual changes, not just a rewrite, and
those need `import` instead - or if central has moved on with local changes
of its own under `repo/<name>/` in the meantime.

That covers the two directions changes travel between central and a
subrepo. Either way, once a change has landed in a subrepo's own history,
the last step is [pushing it out for real](push.md). *)
