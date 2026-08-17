(*********************************************************************************)
(*  central - Manage history between sub-repos and their monorepo                *)
(*  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*  SPDX-License-Identifier: MIT                                                 *)
(*********************************************************************************)

let skip_step step =
  App_log.skip
    Pp.O.(
      Pp.text "Skipping "
      ++ Pp_tty.id (module Central.Next_step) step
      ++ Pp.text " (not applicable).")
;;
