(*_********************************************************************************)
(*_  central - Manage history between sub-repos and their monorepo                *)
(*_  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*_  SPDX-License-Identifier: MIT                                                 *)
(*_********************************************************************************)

val push
  :  vcs:< Vcs.Trait.git ; .. > Vcs.t
  -> repo_root:Vcs.Repo_root.t
  -> is_applicable:bool
  -> force:bool
  -> confirm_mode:Prompt.Confirm_mode.t
  -> unit

val main : unit Command.t
