(*********************************************************************************)
(*  central - Manage history between sub-repos and their monorepo                *)
(*  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*  SPDX-License-Identifier: MIT                                                 *)
(*********************************************************************************)

open! Central

(* @mdexp

# Config

`central` reads two small, optional JSON config files, each with a
`$schema` under `schema/` for editor support:

- `Repo_config` - read from `.central/repo-config.json`, at the root of the
  monorepo itself. Currently just `name`, the string that identifies "the
  central repo" among the positional arguments to commands like `push` and
  `todo` (as opposed to a subrepo) - defaults to `"central"`.
- `User_config` - read from the XDG config directory,
  `~/.config/central/user-config.json`. Empty for now; a placeholder for
  per-user settings to come.

Both are entirely optional: a missing file just means the default. *)

let%expect_test "Repo_config.default" =
  print_string (Json.to_string (Repo_config.to_json Repo_config.default));
  [%expect {| { "rootRepoName": "central" } |}]
;;

let%expect_test "Repo_config round trip" =
  let t = Repo_config.create ~root_repo_name:"my-monorepo" () in
  print_endline (Repo_config.root_repo_name t);
  [%expect {| my-monorepo |}];
  print_string (Json.to_string (Repo_config.to_json t));
  [%expect {| { "rootRepoName": "my-monorepo" } |}]
;;

(* @mdexp

`Repo_config.find_and_load` is what commands actually call: it looks for
`.central/repo-config.json` in the repo and falls back to the default if
it isn't there. *)

let%expect_test "Repo_config.find_and_load" =
  let vcs = Volgo_git_unix.create () in
  let fake_central = Central_test_helpers.create ~vcs ~subrepos:[] in
  let { Central_test_helpers.Fake_central.central_root; _ } = fake_central in
  (* No [.central/repo-config.json] yet - falls back to the default. *)
  let t = Central.Repo_config.find_and_load ~repo_root:central_root in
  print_endline (Repo_config.root_repo_name t);
  [%expect {| central |}];
  Central_test_helpers.write_file
    ~repo_root:central_root
    ~path_in_repo:Repo_config.path_in_repo
    ~contents:{|{ "rootRepoName": "my-monorepo" }|};
  let t = Central.Repo_config.find_and_load ~repo_root:central_root in
  print_endline (Repo_config.root_repo_name t);
  [%expect {| my-monorepo |}]
;;

(* @mdexp

Unknown fields are rejected rather than silently ignored - a typo in the
config file is a loud error, not a silently-dropped setting: *)

let%expect_test "Repo_config.of_json rejects unknown fields" =
  (match Repo_config.of_json (`Assoc [ "unknown_field", `String "x" ]) ~loc:Loc.none with
   | (_ : Repo_config.t) -> assert false
   | exception Err.E err -> print_endline (Err.to_string_hum err));
  [%expect {| "Unknown config field \"unknown_field\"." |}]
;;

(* @mdexp `User_config` follows the same shape, currently an empty record: *)

let%expect_test "User_config" =
  print_string (Json.to_string (User_config.to_json (User_config.create ())));
  [%expect {| {} |}]
;;
