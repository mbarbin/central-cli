(*********************************************************************************)
(*  central - Manage history between sub-repos and their monorepo                *)
(*  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*  SPDX-License-Identifier: MIT                                                 *)
(*********************************************************************************)

type repo =
  | Central
  | Subrepo of Central.Subrepo.t

let name ~repo_config = function
  | Central -> Central.Repo_config.root_repo_name repo_config
  | Subrepo subrepo -> Central.Subrepo.to_string subrepo
;;

(* Each positional argument is only format-validated at parse time (same
   shape as a subrepo name - non-empty, no '/'); which one of them actually
   refers to the central repo can only be decided once [repo_config] is
   loaded, which requires [repo_root], not known until well after argument
   parsing - see {!val:resolve}. *)
type t =
  | All
  | Default_central
  | Named of Central.Subrepo.t list

let arg ~default_to_central =
  let open Command.Std in
  let+ repos =
    Arg.pos_all
      (Param.validated_string (module Central.Subrepo))
      ~docv:"REPO"
      ~doc:"The repos to operate on."
  and+ all = Arg.flag [ "all" ] ~doc:"Select all repos" in
  match repos, all with
  | [], false ->
    if default_to_central
    then Default_central
    else Err.raise ~exit_code:Err.Exit_code.cli_error [ Pp.text "No repo specified." ]
  | _ :: _, true ->
    Err.raise
      ~exit_code:Err.Exit_code.cli_error
      Pp.O.
        [ Pp.text "Cannot specify both "
          ++ Pp_tty.kwd (module String) "repos"
          ++ Pp.text " and "
          ++ Pp_tty.kwd (module String) "--all"
          ++ Pp.text "."
        ]
  | (_ :: _ as repos), false -> Named repos
  | [], true -> All
;;

let resolve t ~repo_config ~repo_root =
  let classify (subrepo : Central.Subrepo.t) : repo =
    if
      String.equal
        (Central.Subrepo.to_string subrepo)
        (Central.Repo_config.root_repo_name repo_config)
    then Central
    else Subrepo subrepo
  in
  match t with
  | Default_central -> [ Central ]
  | Named repos -> List.map repos ~f:classify
  | All -> Central :: List.map (Central.Subrepo.all ~repo_root) ~f:(fun s -> Subrepo s)
;;

let iter_aux list ~name ~f =
  List.iter list ~f:(fun repo ->
    let name = name repo in
    let sep = String.make 20 '=' in
    let pp_sep = Pp_tty.ansi (module String) sep [ `Dim ] in
    Log.app (fun () ->
      Pp.O.
        [ pp_sep
          ++ Pp.verbatim " "
          ++ Pp_tty.ansi (module String) name [ `Fg_bright_cyan ]
          ++ Pp.verbatim " "
          ++ pp_sep
        ]);
    f repo)
;;

let iter list ~repo_config ~f = iter_aux list ~name:(name ~repo_config) ~f

module Subrepos = struct
  type t =
    | All
    | Named of Central.Subrepo.t list

  let arg =
    let open Command.Std in
    let+ repos =
      Arg.pos_all
        (Param.validated_string (module Central.Subrepo))
        ~docv:"REPO"
        ~doc:"The repos to operate on."
    and+ all = Arg.flag [ "all" ] ~doc:"Select all subrepos." in
    match repos, all with
    | [], false ->
      Err.raise ~exit_code:Err.Exit_code.cli_error [ Pp.text "No subrepo specified." ]
    | _ :: _, true ->
      Err.raise
        ~exit_code:Err.Exit_code.cli_error
        Pp.O.
          [ Pp.text "Cannot specify both "
            ++ Pp_tty.kwd (module String) "subrepos"
            ++ Pp.text " and "
            ++ Pp_tty.kwd (module String) "--all"
            ++ Pp.text "."
          ]
    | (_ :: _ as repos), false -> Named repos
    | [], true -> All
  ;;

  let resolve t ~repo_root =
    match t with
    | Named repos -> repos
    | All -> Central.Subrepo.all ~repo_root
  ;;

  let iter list ~f = iter_aux list ~name:Central.Subrepo.to_string ~f
end
