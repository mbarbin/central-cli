(*_********************************************************************************)
(*_  central - Manage history between sub-repos and their monorepo                *)
(*_  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*_  SPDX-License-Identifier: MIT                                                 *)
(*_********************************************************************************)

(*_ This is a trimmed copy of a [prompt] library maintained elsewhere by the
  same author, relicensed here as MIT. Only [ask_yn], [Confirm_mode] and
  [styled] (and their [ask_internal]/[choose] dependency chain) are copied
  over; [ask], [Choice] and [ask_gen] are not needed by [push] and were
  dropped.

  [prompt] itself was inspired by [async_interactive.v0.17.0]
  (https://github.com/janestreet/async_interactive), released under MIT:

  Copyright (c) 2014--2024 Jane Street Group, LLC <opensource-contacts@janestreet.com>

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all
  copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE. *)

(** A library to prompt the user for simple answers in the terminal. *)

val ask_yn : prompt:string -> default:bool option -> bool

module Confirm_mode : sig
  type t =
    | Interactive
    | Yes
    | Dry_run

  val arg : t Command.Arg.t
end

(** You can use this to insert style in the prompt. *)
val styled : Pp_tty.Style.t -> string -> string
