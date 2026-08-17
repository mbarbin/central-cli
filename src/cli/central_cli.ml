(*********************************************************************************)
(*  central - Manage history between sub-repos and their monorepo                *)
(*  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*  SPDX-License-Identifier: MIT                                                 *)
(*********************************************************************************)

let main =
  Command.group
    ~summary:"Central CLI"
    [ "advance-main", Cmd__advance_main.main
    ; "advance-subrepo", Cmd__advance_subrepo.main
    ; "export", Cmd__export.main
    ; "import", Cmd__import.main
    ; "push", Cmd__push.main
    ; "stitch", Cmd__stitch.main
    ; "todo", Cmd__todo.main
    ]
;;

module Cmd__advance_main = Cmd__advance_main
module Cmd__advance_subrepo = Cmd__advance_subrepo
module Cmd__export = Cmd__export
module Cmd__import = Cmd__import
module Cmd__push = Cmd__push
module Cmd__stitch = Cmd__stitch
