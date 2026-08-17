(*********************************************************************************)
(*  central - Manage history between sub-repos and their monorepo                *)
(*  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*  SPDX-License-Identifier: MIT                                                 *)
(*********************************************************************************)

let%expect_test "write" =
  let t =
    Gitrepo_file.create
      ~remote:(`Repo_root (Vcs.Repo_root.v "/tmp/repo"))
      ~branch:Vcs.Branch_name.main
      ~commit:(Vcs.Rev.v "94b6be7e2baf34c57aac3de0bab8448289de8391")
      ~parent:(Vcs.Rev.v "f9ade60d84dd80a5a0eddf63e67111d257b53dca")
      ()
  in
  print_string (Gitrepo_file.write t);
  [%expect
    {|
    ; DO NOT EDIT (unless you know what you are doing)
    ;
    ; This subdirectory is a git "subrepo", and this file is maintained by the
    ; git-subrepo command. See https://github.com/ingydotnet/git-subrepo#readme
    ;
    [subrepo]
    	remote = /tmp/repo
    	branch = main
    	commit = 94b6be7e2baf34c57aac3de0bab8448289de8391
    	parent = f9ade60d84dd80a5a0eddf63e67111d257b53dca
    	method = rebase
    	cmdver = 0.4.6
    |}];
  ()
;;
