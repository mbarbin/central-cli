(*********************************************************************************)
(*  central - Manage history between sub-repos and their monorepo                *)
(*  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*  SPDX-License-Identifier: MIT                                                 *)
(*********************************************************************************)

module Id = String_id.Make (struct
    let module_name = "Subrepo"

    (* A subrepo name is a directory name under [repo/]: non-empty, and not
       itself a path (no "/"). *)
    let invariant s = String.length s > 0 && not (String.contains s '/')
  end)

type t = Id.t

let to_string = Id.to_string
let of_string = Id.of_string
let v = Id.v
let equal = Id.equal
let compare = Id.compare
let hash = Id.hash
let to_dyn = Id.to_dyn
let root t = Vcs.Path_in_repo.v (Printf.sprintf "repo/%s" (to_string t))

let gitrepo_file_path t =
  Vcs.Path_in_repo.v (Printf.sprintf "repo/%s/.gitrepo" (to_string t))
;;

let all ~repo_root =
  let subrepos_dir = Filename.concat (Vcs.Repo_root.to_string repo_root) "repo" in
  match Sys.readdir subrepos_dir with
  | exception Sys_error _ -> []
  | entries ->
    Array.to_list entries
    |> List.filter ~f:(fun name ->
      let dir = Filename.concat subrepos_dir name in
      Sys.is_directory dir && Sys.file_exists (Filename.concat dir ".gitrepo"))
    |> List.sort ~cmp:String.compare
    |> List.map ~f:v
;;
