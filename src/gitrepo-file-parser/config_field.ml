(*********************************************************************************)
(*  central - Manage history between sub-repos and their monorepo                *)
(*  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*  SPDX-License-Identifier: MIT                                                 *)
(*********************************************************************************)

type t =
  | Remote of [ `Repo_root of Vcs.Repo_root.t ] Loc.Txt.t
  | Branch of Vcs.Branch_name.t Loc.Txt.t
  | Commit of Vcs.Rev.t Loc.Txt.t
  | Parent of Vcs.Rev.t Loc.Txt.t
  | Method of [ `Merge | `Rebase ] Loc.Txt.t
  | Cmdver of string Loc.Txt.t

let remote ts =
  List.find_map ts ~f:(function
    | Remote r -> Some r
    | _ -> None)
  |> Option.get
;;

let branch ts =
  List.find_map ts ~f:(function
    | Branch b -> Some b
    | _ -> None)
  |> Option.get
;;

let commit ts =
  List.find_map ts ~f:(function
    | Commit c -> Some c
    | _ -> None)
  |> Option.get
;;

let parent ts =
  List.find_map ts ~f:(function
    | Parent p -> Some p
    | _ -> None)
  |> Option.get
;;

let method_ ts =
  List.find_map ts ~f:(function
    | Method m -> Some m
    | _ -> None)
  |> Option.get
;;

let cmdver ts =
  List.find_map ts ~f:(function
    | Cmdver c -> Some c
    | _ -> None)
  |> Option.get
;;
