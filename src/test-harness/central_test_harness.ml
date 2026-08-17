(*********************************************************************************)
(*  central - Manage history between sub-repos and their monorepo                *)
(*  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*  SPDX-License-Identifier: MIT                                                 *)
(*********************************************************************************)

(* Resolved once, before any test has a chance to [chdir] away (see [run]) -
   the copy of the [central] executable that dune's [(deps central.exe)]
   places next to the test binary, at whatever the test runner's cwd was at
   startup. *)
let executable = Filename.concat (Sys.getcwd ()) "central.exe"

let is_hex_char = function
  | '0' .. '9' | 'a' .. 'f' -> true
  | _ -> false
;;

(* Finds 40-character lowercase hex substrings (git revisions) not embedded
   in a longer run of hex characters. *)
let find_shas text =
  let len = String.length text in
  let results = ref [] in
  let i = ref 0 in
  while !i <= len - 40 do
    let preceded_by_hex = !i > 0 && is_hex_char text.[!i - 1] in
    let followed_by_hex = !i + 40 < len && is_hex_char text.[!i + 40] in
    if (not preceded_by_hex) && not followed_by_hex
    then (
      let ok = ref true in
      for j = 0 to 39 do
        if not (is_hex_char text.[!i + j]) then ok := false
      done;
      if !ok
      then (
        results := String.sub text ~pos:!i ~len:40 :: !results;
        i := !i + 40)
      else incr i)
    else incr i
  done;
  List.rev !results
;;

let replace_all text ~pattern ~with_ =
  let plen = String.length pattern in
  let tlen = String.length text in
  if plen = 0 || plen > tlen
  then text
  else (
    let buf = Buffer.create tlen in
    let i = ref 0 in
    while !i <= tlen - plen do
      if String.equal (String.sub text ~pos:!i ~len:plen) pattern
      then (
        Buffer.add_string buf with_;
        i := !i + plen)
      else (
        Buffer.add_char buf text.[!i];
        incr i)
    done;
    if !i < tlen then Buffer.add_string buf (String.sub text ~pos:!i ~len:(tlen - !i));
    Buffer.contents buf)
;;

type t =
  { mock_revs : Vcs.Mock_revs.t
  ; repo_root : string * string (* (absolute path, "$CENTRAL_ROOT") *)
  ; mutable registered_revs : (string * string) list (* (full sha, full mock sha) *)
  }

let create ~repo_root =
  { mock_revs = Vcs.Mock_revs.create ()
  ; repo_root = Vcs.Repo_root.to_string repo_root, "$CENTRAL_ROOT"
  ; registered_revs = []
  }
;;

let to_mock_rev t ~rev =
  let sha = Vcs.Rev.to_string rev in
  let mock = Vcs.Mock_revs.to_mock t.mock_revs ~rev in
  let mock_sha = Vcs.Rev.to_string mock in
  if not (List.exists t.registered_revs ~f:(fun (r, _) -> String.equal r sha))
  then t.registered_revs <- (sha, mock_sha) :: t.registered_revs;
  mock
;;

let register_rev t ~rev = ignore (to_mock_rev t ~rev : Vcs.Rev.t)

(* Longest match first, so a full sha is substituted before its own shorter
   (abbreviated) prefix. *)
let sorted_by_length_desc pairs =
  List.sort pairs ~cmp:(fun (a, _) (b, _) ->
    Int.compare (String.length b) (String.length a))
;;

(* git's own abbreviated shas (as printed by e.g. [git merge --ff-only]'s
   "Updating X..Y" summary) don't have a fixed length - [core.abbrev]
   defaults to the shortest prefix that is currently unambiguous in the
   repo, which for a small test repo is usually 7 characters but isn't
   guaranteed to be. Rather than assume a length, register every prefix in
   the range git realistically uses ([min_abbrev_len] up to the full sha),
   longest first, so whatever length actually shows up in the text finds an
   exact match. *)
let min_abbrev_len = 4

let prefixes_of_rev ~sha ~mock_sha =
  List.init
    ~len:(String.length sha - min_abbrev_len + 1)
    ~f:(fun i ->
      let len = String.length sha - i in
      String.prefix sha len, String.prefix mock_sha len)
;;

(* Abbreviated shas are only caught here if their full-length counterpart was
   already registered - either auto-detected via [find_shas] earlier in this
   same text, or registered explicitly with [register_rev] beforehand. *)
let replacements t text =
  let shas = find_shas text in
  List.iter shas ~f:(fun sha -> ignore (to_mock_rev t ~rev:(Vcs.Rev.v sha) : Vcs.Rev.t));
  let rev_replacements =
    List.concat_map t.registered_revs ~f:(fun (sha, mock_sha) ->
      prefixes_of_rev ~sha ~mock_sha)
  in
  sorted_by_length_desc (t.repo_root :: rev_replacements)
;;

let redact t text =
  List.fold_left (replacements t text) ~init:text ~f:(fun acc (pattern, with_) ->
    replace_all acc ~pattern ~with_)
;;

(* Keep the first group attached to the program name when it doesn't start
   with a flag (so e.g. [$ central export foo] reads on one line rather than
   [$ central \ export foo]), box each group so it doesn't break internally,
   and join groups with a soft break that only kicks in if the whole command
   doesn't fit on one line - in which case continuation lines get a trailing
   [\] like a shell command split across lines. *)
let command_pp_to_string pp =
  let buffer = Buffer.create 23 in
  let formatter = Format.formatter_of_buffer buffer in
  Format.fprintf formatter "%a%!" Pp.to_fmt pp;
  Buffer.contents buffer
  |> String.split_lines
  |> List.map ~f:String.rstrip
  |> String.concat ~sep:" \\\n"
;;

(* A person typing [-m Several words] at a shell would need to quote it as
   [-m "Several words"] for it to be seen as one argument rather than three -
   so the printed header does the same whenever an argument isn't a single
   shell "word" on its own. *)
let needs_quoting arg =
  String.is_empty arg
  || String.exists arg ~f:(fun c ->
    match c with
    | ' '
    | '\t'
    | '\n'
    | '"'
    | '\''
    | '\\'
    | '$'
    | '`'
    | '*'
    | '?'
    | '['
    | ']'
    | '('
    | ')'
    | '{'
    | '}'
    | ';'
    | '&'
    | '|'
    | '<'
    | '>'
    | '~'
    | '#' -> true
    | _ -> false)
;;

let quote_arg_if_needed arg = if needs_quoting arg then Printf.sprintf "%S" arg else arg

let command_header groups =
  let groups =
    match groups with
    | (first_arg :: _ as first_group) :: rest
      when not (String.is_prefix first_arg ~prefix:"-") ->
      ("central" :: first_group) :: rest
    | _ -> [ "central" ] :: groups
  in
  let groups =
    List.map groups ~f:(fun group ->
      Pp.hbox
        (Pp.concat_map group ~sep:Pp.space ~f:(fun arg ->
           Pp.verbatim (quote_arg_if_needed arg))))
  in
  Pp.concat [ Pp.verbatim "$ "; Pp.hvbox ~indent:2 (Pp.concat ~sep:Pp.space groups) ]
  |> command_pp_to_string
;;

let run t ~cwd groups =
  let args = List.concat groups in
  print_endline (command_header groups);
  let original_cwd = Sys.getcwd () in
  Sys.chdir (Vcs.Repo_root.to_string cwd);
  let temp_stdout = Filename.temp_file "central_test_harness" ".stdout" in
  let temp_stderr = Filename.temp_file "central_test_harness" ".stderr" in
  Fun.protect
    ~finally:(fun () ->
      Sys.chdir original_cwd;
      (try Sys.remove temp_stdout with
       | Sys_error _ -> ());
      try Sys.remove temp_stderr with
      | Sys_error _ -> ())
    (fun () ->
       let stdout_fd =
         Unix.openfile temp_stdout [ Unix.O_WRONLY; Unix.O_CREAT; Unix.O_TRUNC ] 0o666
       in
       let stderr_fd =
         Unix.openfile temp_stderr [ Unix.O_WRONLY; Unix.O_CREAT; Unix.O_TRUNC ] 0o666
       in
       let pid =
         Fun.protect
           ~finally:(fun () ->
             Unix.close stdout_fd;
             Unix.close stderr_fd)
           (fun () ->
              Unix.create_process
                executable
                (Array.of_list (executable :: args))
                Unix.stdin
                stdout_fd
                stderr_fd)
       in
       let _, status = Unix.waitpid [] pid in
       let flush_output () =
         let read_file path =
           In_channel.with_open_bin path In_channel.input_all |> redact t
         in
         let out = read_file temp_stdout in
         if not (String.equal out "") then print_string out;
         let err = read_file temp_stderr in
         if not (String.equal err "") then print_string err
       in
       match status with
       | Unix.WEXITED 0 -> flush_output ()
       | Unix.WEXITED code ->
         flush_output ();
         Printf.printf "[%d]\n" code
       | Unix.WSIGNALED signal ->
         flush_output ();
         Printf.printf "Killed by signal %d\n" signal
       | Unix.WSTOPPED signal ->
         flush_output ();
         Printf.printf "Stopped by signal %d\n" signal)
;;

let with_cli t ~cwd f = f (run t ~cwd)
