(*_********************************************************************************)
(*_  central - Manage history between sub-repos and their monorepo                *)
(*_  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*_  SPDX-License-Identifier: MIT                                                 *)
(*_********************************************************************************)

include module type of Stdlib.StringLabels

(** The identity function, so [(module String)] can be used where a
    [Stringable]-like interface is expected (e.g. [Pp_tty.kwd]). *)
val to_string : t -> t

val is_empty : t -> bool

(** [prefix t len] returns the first [len] characters of [t], clamped to
    [t]'s own length if [len] exceeds it (or to [""] if [len] is
    negative). *)
val prefix : t -> int -> t

val is_prefix : t -> prefix:t -> bool

(** Trim characters matching [drop] (whitespace by default) from the right
    end only, unlike {!trim}/{!strip} which trim both ends. *)
val rstrip : ?drop:(char -> bool) -> t -> t

(** Trim characters matching [drop] (whitespace by default) from the left
    end only, unlike {!trim}/{!strip} which trim both ends. *)
val lstrip : ?drop:(char -> bool) -> t -> t

(** An alias for {!trim} when [drop] is omitted; otherwise trims characters
    matching [drop] from both ends. *)
val strip : ?drop:(char -> bool) -> t -> t

(** Split on ['\n'], also stripping a trailing ['\r'] from each line (so
    both Unix and Windows line endings are handled), and - unlike a plain
    [split_on_char '\n'] - without a spurious trailing empty line when [t]
    itself ends with a newline. *)
val split_lines : t -> t list
