(*********************************************************************************)
(*  central - Manage history between sub-repos and their monorepo                *)
(*  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*  SPDX-License-Identifier: MIT                                                 *)
(*********************************************************************************)

type t =
  { header : string list
  ; remote : [ `Repo_root of Vcs.Repo_root.t ] Loc.Txt.t
  ; branch : Vcs.Branch_name.t Loc.Txt.t
  ; commit : Vcs.Rev.t Loc.Txt.t
  ; parent : Vcs.Rev.t Loc.Txt.t
  ; method_ : [ `Merge | `Rebase ] Loc.Txt.t
  ; cmdver : string Loc.Txt.t
  }

let to_dyn { header; remote; branch; commit; parent; method_; cmdver } =
  Dyn.Record
    [ "header", Dyn.list Dyn.string header
    ; ( "remote"
      , Loc.Txt.to_dyn
          (function
            | `Repo_root repo_root ->
              Dyn.Variant ("Repo_root", [ Dyn.string (Vcs.Repo_root.to_string repo_root) ]))
          remote )
    ; "branch", Loc.Txt.to_dyn (fun b -> Dyn.string (Vcs.Branch_name.to_string b)) branch
    ; "commit", Loc.Txt.to_dyn (fun c -> Dyn.string (Vcs.Rev.to_string c)) commit
    ; "parent", Loc.Txt.to_dyn (fun p -> Dyn.string (Vcs.Rev.to_string p)) parent
    ; ( "method_"
      , Loc.Txt.to_dyn
          (function
            | `Merge -> Dyn.Variant ("Merge", [])
            | `Rebase -> Dyn.Variant ("Rebase", []))
          method_ )
    ; "cmdver", Loc.Txt.to_dyn Dyn.string cmdver
    ]
;;

let default_header =
  {|
; DO NOT EDIT (unless you know what you are doing)
;
; This subdirectory is a git "subrepo", and this file is maintained by the
; git-subrepo command. See https://github.com/ingydotnet/git-subrepo#readme
;
|}
  |> String.trim
  |> String.split_on_char ~sep:'\n'
;;

let create
      ?(header = default_header)
      ~remote
      ~branch
      ~commit
      ~parent
      ?(method_ = `Rebase)
      ?(cmdver = "0.4.6")
      ()
  =
  let f = Loc.Txt.no_loc in
  { header
  ; remote = f remote
  ; branch = f branch
  ; commit = f commit
  ; parent = f parent
  ; method_ = f method_
  ; cmdver = f cmdver
  }
;;

let write { header; remote; branch; commit; parent; method_; cmdver } =
  let fields =
    List.map
      [ ( "remote"
        , match remote.txt with
          | `Repo_root repo_root -> Vcs.Repo_root.to_string repo_root )
      ; "branch", Vcs.Branch_name.to_string branch.txt
      ; "commit", Vcs.Rev.to_string commit.txt
      ; "parent", Vcs.Rev.to_string parent.txt
      ; ( "method"
        , match method_.txt with
          | `Merge -> "merge"
          | `Rebase -> "rebase" )
      ; "cmdver", cmdver.txt
      ]
      ~f:(fun (field, value) -> Printf.sprintf "\t%s = %s" field value)
  in
  String.concat ~sep:"\n" (List.concat [ header; [ "[subrepo]" ]; fields ]) ^ "\n"
;;
