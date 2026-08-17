(*_********************************************************************************)
(*_  central - Manage history between sub-repos and their monorepo                *)
(*_  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*_  SPDX-License-Identifier: MIT                                                 *)
(*_********************************************************************************)

(** Manipulating the files [.gitrepo] created by [git subrepo]. *)

type t =
  { header : string list
  ; remote : [ `Repo_root of Vcs.Repo_root.t ] Loc.Txt.t
  ; branch : Vcs.Branch_name.t Loc.Txt.t
  ; commit : Vcs.Rev.t Loc.Txt.t
  ; parent : Vcs.Rev.t Loc.Txt.t
  ; method_ : [ `Merge | `Rebase ] Loc.Txt.t
  ; cmdver : string Loc.Txt.t
  }

val to_dyn : t -> Dyn.t

val create
  :  ?header:string list
  -> remote:[ `Repo_root of Vcs.Repo_root.t ]
  -> branch:Vcs.Branch_name.t
  -> commit:Vcs.Rev.t
  -> parent:Vcs.Rev.t
  -> ?method_:[ `Merge | `Rebase ]
  -> ?cmdver:string
  -> unit
  -> t

val write : t -> string
