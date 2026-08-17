(*********************************************************************************)
(*  central - Manage history between sub-repos and their monorepo                *)
(*  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*  SPDX-License-Identifier: MIT                                                 *)
(*********************************************************************************)

(* This is a trimmed copy of a [prompt] library maintained elsewhere by the
   same author, relicensed here as MIT. See prompt.mli. *)

let read_line () =
  match In_channel.input_line In_channel.stdin with
  | Some line -> line
  | None -> raise End_of_file
;;

let aprintf fmt =
  Format.kasprintf
    (fun str ->
       Out_channel.output_string Out_channel.stdout str;
       Out_channel.flush Out_channel.stdout)
    fmt
;;

let read_char () =
  let str = read_line () in
  let len = String.length str in
  if len = 1
  then Ok (Some (Char.lowercase_ascii str.[0]))
  else if len = 0
  then Ok None
  else Error ()
;;

let styled style s =
  if Pp_tty.Private.Color_mode.should_enable_color Unix.stdout
  then Pp_tty.to_string (Pp.tag style (Pp.verbatim s))
  else s
;;

let choose (type a) ~(choices : (char * a) list) : char option -> (a, unit) Result.t
  = function
  | None ->
    (match
       List.filter choices ~f:(fun (c, _) -> Char.equal (Char.uppercase_ascii c) c)
     with
     | _ :: _ :: _ as l ->
       raise
         (Invalid_argument
            (Printf.sprintf
               "[Prompt.choose] supplied multiple defaults %S."
               (String.concat ~sep:"" (List.map l ~f:(fun (c, _) -> String.make 1 c)))))
     | [ (_, a) ] -> Ok a
     | [] -> Error ())
  | Some ch ->
    let filter (reply, _) =
      Char.equal (Char.lowercase_ascii reply) (Char.lowercase_ascii ch)
    in
    (match List.find_opt choices ~f:filter with
     | Some (_, a) -> Ok a
     | None -> Error ())
;;

let ask_internal (type a) ~prompt ~(choices : (char * a) list) =
  let prompt =
    let cs = List.map choices ~f:(fun (c, _) -> String.make 1 c) in
    Printf.sprintf "%s [%s]" prompt (String.concat ~sep:"/" cs)
  in
  let please_answer () =
    let num_choices = List.length choices in
    let choices =
      List.mapi choices ~f:(fun i (char, _value) ->
        let sep = if i = 0 then "" else if i = num_choices - 1 then " or " else ", " in
        Printf.sprintf "%s'%c'" sep (Char.lowercase_ascii char))
      |> String.concat ~sep:""
    in
    aprintf "[%s] Please answer %s.\n\n" (styled Error "!") choices
  in
  let rec loop () =
    aprintf "[%s] %s: " (styled Warning "?") prompt;
    match read_char () with
    | Error () ->
      please_answer ();
      loop ()
    | Ok char ->
      (match choose ~choices char with
       | Ok res -> res
       | Error () ->
         please_answer ();
         loop ())
  in
  loop ()
;;

let ask_yn ~prompt ~default =
  let y, n =
    match default with
    | None -> 'y', 'n'
    | Some true -> 'Y', 'n'
    | Some false -> 'y', 'N'
  in
  ask_internal ~prompt ~choices:[ y, true; n, false ]
;;

module Confirm_mode = struct
  type t =
    | Interactive
    | Yes
    | Dry_run

  let arg =
    let open Command.Std in
    let+ yes = Arg.flag [ "yes" ] ~doc:"Do not prompt for confirmation."
    and+ dry_run =
      Arg.flag [ "dry-run" ] ~doc:"Run without prompting and without side effects."
    in
    match yes, dry_run with
    | false, false -> Interactive
    | true, false -> Yes
    | false, true -> Dry_run
    | true, true ->
      Err.raise
        ~exit_code:Err.Exit_code.cli_error
        [ Pp.text "Conflicting flags --yes and --dry-run. Please choose one." ]
  ;;
end
