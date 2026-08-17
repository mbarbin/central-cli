(*********************************************************************************)
(*  central - Manage history between sub-repos and their monorepo                *)
(*  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*  SPDX-License-Identifier: MIT                                                 *)
(*********************************************************************************)

type t =
  { subrepo : Central.Subrepo.t
  ; subrepo_repo_root : Vcs.Repo_root.t
  ; subrepo_graph : Vcs.Graph.t
  ; subrepo_head : Vcs.Graph.Node.t
  ; subrepo_base : Vcs.Rev.t
  ; central_num_status : Vcs.Num_status.t
  ; gitrepo_file_path : Vcs.Path_in_repo.t
  ; gitrepo_file : Gitrepo_file.t
  ; next_step_facts : Central.Next_step.Facts.t
  }

let gitrepo_file t = t.gitrepo_file
let gitrepo_file_path t = t.gitrepo_file_path
let next_step_facts t = t.next_step_facts
let subrepo_graph t = t.subrepo_graph
let subrepo_head t = t.subrepo_head
let subrepo_repo_root t = t.subrepo_repo_root
let base t = t.subrepo_base

let is_subrepo_path ~subrepo ~central_path =
  let subrepo_root = Central.Subrepo.root subrepo |> Vcs.Path_in_repo.to_string in
  let central_path = Vcs.Path_in_repo.to_string central_path in
  String.starts_with ~prefix:(subrepo_root ^ "/") central_path
  && not (String.equal central_path (subrepo_root ^ "/.gitrepo"))
;;

let subrepo_branch_name = Vcs.Branch_name.v "subrepo"

let compute ~vcs ~central_root ~central_graph ~subrepo =
  let gitrepo_file_path = Central.Subrepo.gitrepo_file_path subrepo in
  let gitrepo_file =
    Parsing_utils.parse_file_exn
      (module Gitrepo_file_parser)
      ~path:(Vcs.Repo_root.append central_root gitrepo_file_path :> Fpath.t)
  in
  let subrepo_repo_root =
    match gitrepo_file.remote.txt with
    | `Repo_root repo_root -> repo_root
  in
  let subrepo_graph = Vcs.graph vcs ~repo_root:subrepo_repo_root in
  let subrepo_head =
    match
      Vcs.Graph.find_ref
        subrepo_graph
        ~ref_kind:(Local_branch { branch_name = subrepo_branch_name })
    with
    | Some node -> node
    | None ->
      Err.raise
        Pp.O.
          [ Pp.text "Cannot find branch "
            ++ Pp_tty.kwd (module String) "subrepo"
            ++ Pp.text "."
          ; Dyn.pp (Dyn.Record [ "subrepo", Central.Subrepo.to_dyn subrepo ])
          ]
  in
  let subrepo_main_head =
    Vcs_extra.find_local_branch_exn
      ~repo_root:subrepo_repo_root
      ~graph:subrepo_graph
      ~branch_name:Vcs.Branch_name.main
  in
  let subrepo_remote_main_head =
    Vcs_extra.find_remote_tracking_node_exn
      vcs
      ~repo_root:subrepo_repo_root
      ~graph:subrepo_graph
      ~branch_name:Vcs.Branch_name.main
  in
  let central_head = Vcs.current_revision vcs ~repo_root:central_root in
  let subrepo_base =
    let parent_rev = gitrepo_file.parent.txt in
    match Vcs.Graph.find_rev central_graph ~rev:parent_rev with
    | None ->
      Err.raise
        [ Pp.text "Cannot find subrepo parent rev."
        ; Dyn.pp
            (Dyn.Record
               [ "subrepo", Central.Subrepo.to_dyn subrepo
               ; "parent_rev", Vcs.Rev.to_dyn parent_rev
               ])
        ]
    | Some parent_node ->
      (* To be perfectly safe, in case the parent had multiple children, we
         should only select the one that has modified the gitrepo file to
         set its parent revision. *)
      let is_child_revision ~rev =
        match
          Vcs.show_file_at_rev vcs ~repo_root:central_root ~rev ~path:gitrepo_file_path
        with
        | `Absent -> false
        | `Present file_contents ->
          let gitrepo_file =
            Parsing_utils.parse_lexbuf_exn
              (module Gitrepo_file_parser)
              ~path:(Vcs.Repo_root.append central_root gitrepo_file_path :> Fpath.t)
              ~lexbuf:(Lexing.from_string (file_contents :> string))
          in
          Vcs.Rev.equal gitrepo_file.parent.txt parent_rev
      in
      let node_count = Vcs.Graph.node_count central_graph in
      let rec find_child index =
        if index >= node_count
        then
          Err.raise
            [ Pp.text "Cannot find subrepo parent rev child."
            ; Dyn.pp
                (Dyn.Record
                   [ "subrepo", Central.Subrepo.to_dyn subrepo
                   ; "parent_rev", Vcs.Rev.to_dyn parent_rev
                   ])
            ]
        else (
          let node = Vcs.Graph.get_node_exn central_graph ~index in
          match
            let rev = Vcs.Graph.rev central_graph ~node in
            if
              List.exists (Vcs.Graph.parents central_graph ~node) ~f:(fun parent ->
                Vcs.Graph.Node.equal parent parent_node)
            then if is_child_revision ~rev then Some rev else None
            else None
          with
          | Some rev -> rev
          | None -> find_child (index + 1))
      in
      find_child (Vcs.Graph.node_index parent_node + 1)
  in
  let central_changed =
    Vcs.Name_status.Changed.Between { src = subrepo_base; dst = central_head }
  in
  let central_name_status =
    Vcs.name_status vcs ~repo_root:central_root ~changed:central_changed
  in
  let central_num_status =
    Vcs.num_status vcs ~repo_root:central_root ~changed:central_changed
  in
  let central_has_changes_in_subrepo =
    List.exists (Vcs.Name_status.files central_name_status) ~f:(fun central_path ->
      is_subrepo_path ~subrepo ~central_path)
  in
  let subrepo_head_status : Central.Next_step.Facts.Subrepo_head_status.t =
    let gitrepo_rev = gitrepo_file.commit.txt in
    match Vcs.Graph.find_rev subrepo_graph ~rev:gitrepo_rev with
    | None -> Unknown_central_gitrepo_rev
    | Some gitrepo_node ->
      Central_gitrepo_rev_compared_to_subrepo_head
        { descendance = Vcs.Graph.descendance subrepo_graph gitrepo_node subrepo_head }
  in
  { subrepo
  ; subrepo_repo_root
  ; subrepo_graph
  ; subrepo_head
  ; subrepo_base
  ; central_num_status
  ; gitrepo_file_path
  ; gitrepo_file
  ; next_step_facts =
      { central_has_changes_in_subrepo
      ; subrepo_head_status
      ; main_is_strict_ancestor_of_subrepo =
          Vcs.Graph.is_strict_ancestor
            subrepo_graph
            ~ancestor:subrepo_main_head
            ~descendant:subrepo_head
      ; remote_main_is_strict_ancestor_of_local_main =
          Vcs.Graph.is_strict_ancestor
            subrepo_graph
            ~ancestor:subrepo_remote_main_head
            ~descendant:subrepo_main_head
      }
  }
;;

let next_step t = Central.Next_step.compute t.next_step_facts

let num_lines_to_review t =
  let is_subrepo_path ~central_path = is_subrepo_path ~subrepo:t.subrepo ~central_path in
  let num_status =
    List.filter t.central_num_status ~f:(fun (change : Vcs.Num_status.Change.t) ->
      match change.key with
      | One_file central_path -> is_subrepo_path ~central_path
      | Two_files { src; dst } ->
        is_subrepo_path ~central_path:src || is_subrepo_path ~central_path:dst)
  in
  List.fold_left num_status ~init:0 ~f:(fun acc (change : Vcs.Num_status.Change.t) ->
    acc
    +
    match change.num_stat with
    | Num_lines_in_diff n -> Vcs.Num_lines_in_diff.total n
    | Binary_file -> 1)
;;
