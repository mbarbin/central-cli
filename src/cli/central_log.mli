(*_********************************************************************************)
(*_  central - Manage history between sub-repos and their monorepo                *)
(*_  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*_  SPDX-License-Identifier: MIT                                                 *)
(*_********************************************************************************)

(** A module to log messages at the application level. *)

(** A convenient wrapper for [skip] dedicated to skipping actions when a
    next-step is not applicable. *)
val skip_step : Central.Next_step.t -> unit
