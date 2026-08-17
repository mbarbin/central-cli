(*_********************************************************************************)
(*_  central - Manage history between sub-repos and their monorepo                *)
(*_  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*_  SPDX-License-Identifier: MIT                                                 *)
(*_********************************************************************************)

(** A module to log messages at the application level. *)

(** A general log message, such as writing a message before running a slow
    action. *)
val status : Pp_tty.t -> unit

(** A success message reported after the fact. *)
val success : Pp_tty.t -> unit

(** {1 Skipping elements} *)

val skip : Pp_tty.t -> unit
