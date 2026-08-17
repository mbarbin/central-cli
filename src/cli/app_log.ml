(*********************************************************************************)
(*  central - Manage history between sub-repos and their monorepo                *)
(*  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*  SPDX-License-Identifier: MIT                                                 *)
(*********************************************************************************)

module Status = struct
  type t =
    [ `Ok
    | `Fail
    | `Skip
    ]

  let to_string = function
    | `Ok -> " OK "
    | `Fail -> "FAIL"
    | `Skip -> "SKIP"
  ;;
end

let result status pp =
  Log.app (fun () ->
    Pp.O.
      [ Pp_tty.brackets
          (Pp_tty.ansi
             (module Status)
             status
             (match status with
              | `Ok -> [ `Fg_green ]
              | `Fail -> [ `Fg_red ]
              | `Skip -> [ `Fg_yellow ]))
        ++ Pp.space
        ++ pp
      ])
;;

module String = struct
  type t = string

  let to_string s = s
end

let success pp = result `Ok pp
let skip pp = result `Skip pp

let status pp =
  Log.app (fun () -> Pp.O.[ Pp_tty.kwd (module String) "-" ++ Pp.verbatim " " ++ pp ])
;;
