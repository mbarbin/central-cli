(*********************************************************************************)
(*  central - Manage history between sub-repos and their monorepo                *)
(*  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*  SPDX-License-Identifier: MIT                                                 *)
(*********************************************************************************)

module Row = struct
  type t =
    { repo : Which_repos.repo
    ; next_step : Central.Next_step.t option
    ; num_lines_to_review : int
    }

  let is_shown { repo = _; next_step; num_lines_to_review } =
    Option.is_some next_step || num_lines_to_review > 0
  ;;
end

module Todo_table = struct
  type t = Row.t list

  let int_hum_if_not_zero i = if i = 0 then "" else Int.to_string i

  (* Subrepo rows are indented under central's own, to visually group them
     as "belonging to" the enclosing monorepo in the table. *)
  let repo_label ~repo_config (repo : Which_repos.repo) =
    match repo with
    | Central -> Which_repos.name ~repo_config repo
    | Subrepo _ -> "  " ^ Which_repos.name ~repo_config repo
  ;;

  let columns ~repo_config =
    Print_table.O.
      [ Column.make ~header:"Repo" (fun (t : Row.t) ->
          Cell.text (repo_label ~repo_config t.repo))
      ; Column.make ~header:"Next step" (fun (t : Row.t) ->
          Cell.text
            (match t.next_step with
             | None -> ""
             | Some next_step -> Central.Next_step.to_string_hum next_step))
      ; Column.make ~align:Right ~header:"Diff" (fun (t : Row.t) ->
          Cell.text (int_hum_if_not_zero t.num_lines_to_review))
      ]
  ;;

  let to_string t ~repo_config =
    Print_table.to_string_text (Print_table.make ~columns:(columns ~repo_config) ~rows:t)
  ;;

  (* This should be generalized to be more like [Subrepo_facts]/[Next_step],
     when we need more next steps for central's own row. *)
  let central_row ~vcs ~central_graph ~central_root =
    let central_head = Vcs.current_revision vcs ~repo_root:central_root in
    let central_head_node =
      match Vcs.Graph.find_rev central_graph ~rev:central_head with
      | Some node -> node
      | None ->
        Err.raise
          [ Pp.textf "Cannot find central head '%s'." (Vcs.Rev.to_string central_head) ]
    in
    let central_remote_main_head =
      Vcs_extra.find_remote_tracking_node_exn
        vcs
        ~repo_root:central_root
        ~graph:central_graph
        ~branch_name:Vcs.Branch_name.main
    in
    let num_lines_to_review =
      let num_status =
        Vcs.num_status
          vcs
          ~repo_root:central_root
          ~changed:
            (Between
               { src = Vcs.Graph.rev central_graph ~node:central_remote_main_head
               ; dst = central_head
               })
      in
      List.fold_left num_status ~init:0 ~f:(fun acc (change : Vcs.Num_status.Change.t) ->
        acc
        +
        match change.num_stat with
        | Num_lines_in_diff n -> Vcs.Num_lines_in_diff.total n
        | Binary_file -> 1)
    in
    let next_step =
      if
        Vcs.Graph.is_strict_ancestor
          central_graph
          ~ancestor:central_remote_main_head
          ~descendant:central_head_node
      then Some Central.Next_step.Push
      else None
    in
    { Row.repo = Which_repos.Central; next_step; num_lines_to_review }
  ;;

  let subrepo_row ~vcs ~central_root ~central_graph subrepo =
    let facts = Subrepo_facts.compute ~vcs ~central_root ~central_graph ~subrepo in
    { Row.repo = Which_repos.Subrepo subrepo
    ; next_step = Subrepo_facts.next_step facts
    ; num_lines_to_review = Subrepo_facts.num_lines_to_review facts
    }
  ;;

  let compute ~vcs ~central_root : t =
    let central_graph = Vcs.graph vcs ~repo_root:central_root in
    let rows =
      central_row ~vcs ~central_graph ~central_root
      :: List.map
           (Central.Subrepo.all ~repo_root:central_root)
           ~f:(subrepo_row ~vcs ~central_root ~central_graph)
    in
    List.filter rows ~f:Row.is_shown
  ;;
end

let main =
  Command.make
    ~summary:"Build and print central's todo table."
    (let open Command.Std in
     let+ () = Log_cli.set_config () in
     let vcs = Volgo_git_unix.create () in
     let cwd = Unix.getcwd () |> Absolute_path.v in
     let central_root = Common_helpers.find_enclosing_repo_root vcs ~from:cwd in
     let repo_config = Central.Repo_config.find_and_load ~repo_root:central_root in
     let todo_table = Todo_table.compute ~vcs ~central_root in
     print_string (Todo_table.to_string todo_table ~repo_config))
;;
