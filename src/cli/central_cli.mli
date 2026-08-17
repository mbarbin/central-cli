(*_********************************************************************************)
(*_  central - Manage history between sub-repos and their monorepo                *)
(*_  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*_  SPDX-License-Identifier: MIT                                                 *)
(*_********************************************************************************)

val main : unit Command.t

(** [central_cli] is otherwise an "unwrapped main module" that only exposes
    {!val:main} - these submodules are exposed separately so that other
    tools built on top of the same conventions (a monorepo with subrepos
    vendored under [repo/<name>/]) can embed these commands directly,
    without going through command-line parsing or a subprocess. *)
module Cmd__advance_main = Cmd__advance_main

module Cmd__advance_subrepo = Cmd__advance_subrepo
module Cmd__export = Cmd__export
module Cmd__import = Cmd__import
module Cmd__push = Cmd__push
module Cmd__stitch = Cmd__stitch
