(*********************************************************************************)
(*  central - Manage history between sub-repos and their monorepo                *)
(*  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*  SPDX-License-Identifier: MIT                                                 *)
(*********************************************************************************)

let update ~repo_root ~gitrepo_file_path ~new_commit ~new_parent =
  let path = Vcs.Repo_root.append repo_root gitrepo_file_path in
  let original_contents =
    In_channel.with_open_bin (Absolute_path.to_string path) In_channel.input_all
  in
  let gitrepo_file =
    Parsing_utils.parse_lexbuf_exn
      (module Gitrepo_file_parser)
      ~path:(path :> Fpath.t)
      ~lexbuf:(Lexing.from_string original_contents)
  in
  let file_rewriter = File_rewriter.create ~path:(path :> Fpath.t) ~original_contents in
  File_rewriter.replace
    file_rewriter
    ~range:(Loc.range gitrepo_file.commit.loc)
    ~text:(Vcs.Rev.to_string new_commit);
  File_rewriter.replace
    file_rewriter
    ~range:(Loc.range gitrepo_file.parent.loc)
    ~text:(Vcs.Rev.to_string new_parent);
  let updated_contents = File_rewriter.contents file_rewriter in
  Out_channel.with_open_bin (Absolute_path.to_string path) (fun oc ->
    Out_channel.output_string oc updated_contents);
  Log.debug (fun () ->
    [ Pp.verbatim
        (Myers.diff
           ~color:true
           ~expected_label:".gitrepo (before)"
           ~actual_label:".gitrepo (after)"
           original_contents
           updated_contents)
    ])
;;
