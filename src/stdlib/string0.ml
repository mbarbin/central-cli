(*********************************************************************************)
(*  central - Manage history between sub-repos and their monorepo                *)
(*  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*  SPDX-License-Identifier: MIT                                                 *)
(*********************************************************************************)

(* Some functions below are copied from [Base] version [v0.17], which is
   released under MIT and may be found at
   [https://github.com/janestreet/base].

   See Base's LICENSE below:

   ----------------------------------------------------------------------------

   The MIT License

   Copyright (c) 2016--2024 Jane Street Group, LLC <opensource-contacts@janestreet.com>

   Permission is hereby granted, free of charge, to any person obtaining a copy
   of this software and associated documentation files (the "Software"), to deal
   in the Software without restriction, including without limitation the rights
   to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
   copies of the Software, and to permit persons to whom the Software is
   furnished to do so, subject to the following conditions:

   The above copyright notice and this permission notice shall be included in
   all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
   SOFTWARE.

   ----------------------------------------------------------------------------

   When this is the case, we clearly indicate it next to the copied function. *)

include Stdlib.StringLabels

let to_string t = t

let prefix t len =
  let len = if len < 0 then 0 else if len > length t then length t else len in
  sub t ~pos:0 ~len
;;

let is_prefix t ~prefix =
  let plen = length prefix in
  length t >= plen && Stdlib.String.equal (sub t ~pos:0 ~len:plen) prefix
;;

let is_whitespace = function
  | ' ' | '\t' | '\n' | '\r' | '\012' -> true
  | _ -> false
;;

(* ---------------------------------------------------------------------------- *)
(* The functions below are copied from [Base]. See notice at the top of the
   file for licensing information. *)

let rfindi t ~f =
  let rec loop i = if i < 0 then None else if f i t.[i] then Some i else loop (i - 1) in
  let pos = length t - 1 in
  (loop pos [@nontail])
;;

let lfindi ?(pos = 0) t ~f =
  let n = length t in
  let rec loop i = if i = n then None else if f i t.[i] then Some i else loop (i + 1) in
  (loop pos [@nontail])
;;

let last_non_drop ~drop t = rfindi t ~f:(fun _ c -> not (drop c)) [@nontail]
let first_non_drop ~drop t = lfindi t ~f:(fun _ c -> not (drop c)) [@nontail]

let rstrip ?(drop = is_whitespace) t =
  match last_non_drop t ~drop with
  | None -> ""
  | Some i -> if i = length t - 1 then t else sub t ~pos:0 ~len:(i + 1)
;;

let lstrip ?(drop = is_whitespace) t =
  match first_non_drop t ~drop with
  | None -> ""
  | Some 0 -> t
  | Some n -> sub t ~pos:n ~len:(length t - n)
;;

let strip ?drop t =
  match drop with
  | None -> trim t
  | Some drop -> lstrip ~drop (rstrip ~drop t)
;;

(* ---------------------------------------------------------------------------- *)

(* The function [split_lines] below was copied from [Base.String0.split_lines]
   version [v0.17], which is released under MIT and may be found at
   [https://github.com/janestreet/base]. See notice at the top of the file
   for licensing information. *)

let split_lines =
  let back_up_at_newline ~t ~pos ~eol =
    pos := !pos - if !pos > 0 && Stdlib.Char.equal t.[!pos - 1] '\r' then 2 else 1;
    eol := !pos + 1
  in
  fun t ->
    let n = length t in
    if n = 0
    then []
    else (
      (* Invariant: [-1 <= pos < eol]. *)
      let pos = ref (n - 1) in
      let eol = ref n in
      let ac = ref [] in
      (* We treat the end of the string specially, because if the string ends with a
         newline, we don't want an extra empty string at the end of the output. *)
      if Stdlib.Char.equal t.[!pos] '\n' then back_up_at_newline ~t ~pos ~eol;
      while !pos >= 0 do
        if not (Stdlib.Char.equal t.[!pos] '\n')
        then decr pos
        else (
          (* Because [pos < eol], we know that [start <= eol]. *)
          let start = !pos + 1 in
          ac := sub t ~pos:start ~len:(!eol - start) :: !ac;
          back_up_at_newline ~t ~pos ~eol)
      done;
      sub t ~pos:0 ~len:!eol :: !ac)
;;
