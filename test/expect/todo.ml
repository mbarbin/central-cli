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

# Todo

`central todo` is the dashboard: one row for central itself, plus one row
per subrepo that has something outstanding - each with its `Next step`
(what `central` command to run next) and, for subrepos, `Diff` (how many
lines under `repo/<name>/` differ from what's already been dealt with).
Subrepos with nothing outstanding simply don't appear, so the table only
ever shows what actually needs attention - see [the day-to-day
workflow](workflow.md) for it used end to end.

`central`'s own row uses `Repo_config.root_repo_name` as its label - `"central"` by
default, but configurable per-repo (see [config.md](config.md)). *)

let%expect_test "empty todo, right after create" =
  let vcs = Volgo_git_unix.create () in
  let widget = Central.Subrepo.v "widget" in
  let fake_central = Central_test_helpers.create ~vcs ~subrepos:[ widget ] in
  let { Central_test_helpers.Fake_central.central_root; _ } = fake_central in
  let harness = Central_test_harness.create ~repo_root:central_root in
  let@ central = Central_test_harness.with_cli harness ~cwd:central_root in
  central [ [ "todo" ] ];
  [%expect {| $ central todo |}]
;;

(* @mdexp

Once `repo/widget/` has an uncommitted-to-upstream change, `widget` shows
up with `export` as its next step, and `central` itself already needs a
`push` for the commit that introduced it: *)

let%expect_test "export shows up as a next step for the subrepo" =
  let vcs = Volgo_git_unix.create () in
  let widget = Central.Subrepo.v "widget" in
  let fake_central = Central_test_helpers.create ~vcs ~subrepos:[ widget ] in
  let { Central_test_helpers.Fake_central.central_root; _ } = fake_central in
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
  central [ [ "todo" ] ];
  [%expect
    {|
    $ central todo
    ┌──────────┬───────────┬──────┐
    │ Repo     │ Next step │ Diff │
    ├──────────┼───────────┼──────┤
    │ central  │ push      │    2 │
    │   widget │ export    │    2 │
    └──────────┴───────────┴──────┘
    |}]
;;

(* @mdexp

After `export`, `widget`'s next step becomes `advance-main` - the `Diff`
column goes blank, since there's no longer a content diff to size, only a
branch to fast-forward: *)

let%expect_test "after export, central itself needs a push" =
  let vcs = Volgo_git_unix.create () in
  let widget = Central.Subrepo.v "widget" in
  let fake_central = Central_test_helpers.create ~vcs ~subrepos:[ widget ] in
  let { Central_test_helpers.Fake_central.central_root; _ } = fake_central in
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
  central [ [ "todo" ] ];
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

And with a `.central/repo-config.json` setting a custom `name`, that name -
not `"central"` - is what labels the top row: *)

let%expect_test "a custom repo_config name is used for central's own row" =
  let vcs = Volgo_git_unix.create () in
  let widget = Central.Subrepo.v "widget" in
  let fake_central = Central_test_helpers.create ~vcs ~subrepos:[ widget ] in
  let { Central_test_helpers.Fake_central.central_root; _ } = fake_central in
  Central_test_helpers.write_file
    ~repo_root:central_root
    ~path_in_repo:Central.Repo_config.path_in_repo
    ~contents:{|{ "rootRepoName": "my-monorepo" }|};
  Vcs.add vcs ~repo_root:central_root ~path:Central.Repo_config.path_in_repo;
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
      ~commit_message:"Add repo config and document installation"
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
  central [ [ "todo" ] ];
  [%expect
    {|
    $ central todo
    ┌─────────────┬──────────────┬──────┐
    │ Repo        │ Next step    │ Diff │
    ├─────────────┼──────────────┼──────┤
    │ my-monorepo │ push         │    7 │
    │   widget    │ advance-main │      │
    └─────────────┴──────────────┴──────┘
    |}]
;;
