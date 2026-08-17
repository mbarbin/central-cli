(*********************************************************************************)
(*  central - Manage history between sub-repos and their monorepo                *)
(*  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*  SPDX-License-Identifier: MIT                                                 *)
(*********************************************************************************)

let parse_string_exn ~path str =
  Parsing_utils.parse_lexbuf_exn
    (module Gitrepo_file_parser)
    ~path
    ~lexbuf:(Lexing.from_string str)
;;

let test ?(strip = true) ?(show_positions = false) str =
  let@ () = fun f -> Err.For_test.protect f in
  let c =
    parse_string_exn
      ~path:("test" |> Fpath.v)
      (if strip then String.trim str ^ "\n" else str)
  in
  Ref.set_temporarily Loc.include_sexp_of_locs show_positions ~f:(fun () ->
    print_dyn (Gitrepo_file.to_dyn c))
;;

let%expect_test "parsing" =
  test ~strip:false ~show_positions:true "";
  [%expect
    {|
    File "test", line 1, characters 0-0:
    Error: Syntax error.
    [123] |}];
  test ~show_positions:true "";
  [%expect
    {|
    File "test", line 2, characters 0-0:
    Error: Syntax error.
    [123] |}];
  test ~strip:false ~show_positions:true "\n";
  [%expect
    {|
    File "test", line 2, characters 0-0:
    Error: Syntax error.
    [123] |}];
  test
    ~show_positions:true
    {|
; DO NOT EDIT (unless you know what you are doing)
;
; This subdirectory is a git "subrepo", and this file is maintained by the
; git-subrepo command. See https://github.com/ingydotnet/git-subrepo#readme
;
[subrepo]
	remote = /home/mathieu/dev/micrograd
	branch = subrepo
	commit = 94b6be7e2baf34c57aac3de0bab8448289de8391
	parent = f9ade60d84dd80a5a0eddf63e67111d257b53dca
	method = rebase
	cmdver = 0.4.6
|};
  [%expect
    {|
    { header =
        [ "; DO NOT EDIT (unless you know what you are doing)"
        ; ";"
        ; "; This subdirectory is a git \"subrepo\", and this file is maintained by the"
        ; "; git-subrepo command. See https://github.com/ingydotnet/git-subrepo#readme"
        ; ";"
        ]
    ; remote =
        { txt = Repo_root "/home/mathieu/dev/micrograd"
        ; loc = { start = "test:7:10"; stop = "test:7:37" }
        }
    ; branch =
        { txt = "subrepo"; loc = { start = "test:8:10"; stop = "test:8:17" } }
    ; commit =
        { txt = "94b6be7e2baf34c57aac3de0bab8448289de8391"
        ; loc = { start = "test:9:10"; stop = "test:9:50" }
        }
    ; parent =
        { txt = "f9ade60d84dd80a5a0eddf63e67111d257b53dca"
        ; loc = { start = "test:10:10"; stop = "test:10:50" }
        }
    ; method_ =
        { txt = Rebase; loc = { start = "test:11:10"; stop = "test:11:16" } }
    ; cmdver =
        { txt = "0.4.6"; loc = { start = "test:12:10"; stop = "test:12:15" } }
    }
    |}];
  ()
;;

let%expect_test "rewriter" =
  let@ () = fun f -> Err.For_test.protect f in
  let original_contents =
    Gitrepo_file.create
      ~remote:(`Repo_root (Vcs.Repo_root.v "/tmp/repo"))
      ~branch:Vcs.Branch_name.main
      ~commit:(Vcs.Rev.v "94b6be7e2baf34c57aac3de0bab8448289de8391")
      ~parent:(Vcs.Rev.v "f9ade60d84dd80a5a0eddf63e67111d257b53dca")
      ()
    |> Gitrepo_file.write
  in
  test original_contents;
  [%expect
    {|
    { header =
        [ "; DO NOT EDIT (unless you know what you are doing)"
        ; ";"
        ; "; This subdirectory is a git \"subrepo\", and this file is maintained by the"
        ; "; git-subrepo command. See https://github.com/ingydotnet/git-subrepo#readme"
        ; ";"
        ]
    ; remote = Repo_root "/tmp/repo"
    ; branch = "main"
    ; commit = "94b6be7e2baf34c57aac3de0bab8448289de8391"
    ; parent = "f9ade60d84dd80a5a0eddf63e67111d257b53dca"
    ; method_ = Rebase
    ; cmdver = "0.4.6"
    }
    |}];
  let path = Fpath.v "test" in
  let gitrepo_file =
    Parsing_utils.parse_lexbuf_exn
      (module Gitrepo_file_parser)
      ~path
      ~lexbuf:(Lexing.from_string original_contents)
  in
  let file_rewriter = File_rewriter.create ~path ~original_contents in
  let () =
    File_rewriter.replace
      file_rewriter
      ~range:(Loc.range gitrepo_file.commit.loc)
      ~text:"b258b0cde128083c4f05bcf276bcc1322f1d36a2";
    File_rewriter.replace
      file_rewriter
      ~range:(Loc.range gitrepo_file.method_.loc)
      ~text:"merge"
  in
  let modified_contents = File_rewriter.contents file_rewriter in
  print_string (Myers.diff original_contents modified_contents ~context:3);
  [%expect
    {|
    @@ -6,7 +6,7 @@
      [subrepo]
      remote = /tmp/repo
      branch = main
    -|	commit = 94b6be7e2baf34c57aac3de0bab8448289de8391
    +|	commit = b258b0cde128083c4f05bcf276bcc1322f1d36a2
      parent = f9ade60d84dd80a5a0eddf63e67111d257b53dca
    -|	method = rebase
    +|	method = merge
      cmdver = 0.4.6
    |}];
  ()
;;
