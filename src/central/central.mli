(*_********************************************************************************)
(*_  central - Manage history between sub-repos and their monorepo                *)
(*_  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*_  SPDX-License-Identifier: MIT                                                 *)
(*_********************************************************************************)

(** [central] is the core library backing the [central] CLI.

    Central helps manage changes and git history between individual
    sub-repos and a monorepo that aggregates them, allowing changes to be
    promoted bidirectionally between the two. This project is under active
    development; modules are added here as they are made available. *)

module Next_step = Next_step
module Repo_config = Repo_config
module Subrepo = Subrepo
module User_config = User_config
