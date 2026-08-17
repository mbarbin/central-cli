(*_********************************************************************************)
(*_  central - Manage history between sub-repos and their monorepo                *)
(*_  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*_  SPDX-License-Identifier: MIT                                                 *)
(*_********************************************************************************)

(** Intermediary type to allow parsing the config fields out of order. *)

type t =
  | Remote of [ `Repo_root of Vcs.Repo_root.t ] Loc.Txt.t
  | Branch of Vcs.Branch_name.t Loc.Txt.t
  | Commit of Vcs.Rev.t Loc.Txt.t
  | Parent of Vcs.Rev.t Loc.Txt.t
  | Method of [ `Merge | `Rebase ] Loc.Txt.t
  | Cmdver of string Loc.Txt.t

val remote : t list -> [ `Repo_root of Vcs.Repo_root.t ] Loc.Txt.t
val branch : t list -> Vcs.Branch_name.t Loc.Txt.t
val commit : t list -> Vcs.Rev.t Loc.Txt.t
val parent : t list -> Vcs.Rev.t Loc.Txt.t
val method_ : t list -> [ `Merge | `Rebase ] Loc.Txt.t
val cmdver : t list -> string Loc.Txt.t
