(*_********************************************************************************)
(*_  central - Manage history between sub-repos and their monorepo                *)
(*_  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*_  SPDX-License-Identifier: MIT                                                 *)
(*_********************************************************************************)

(** Per-user configuration, read from the XDG config directory (typically
    [~/.config/central/user-config.json]).

    We are using JSON as the serialization format. This is currently an
    empty placeholder - fields will be added as the CLI grows. See
    [schema/central-user-config.schema.json] at the root of this
    repository. *)

type t

val to_json : t -> Json.t

(** {1 Create configs} *)

val create : unit -> t

(** {1 Loading} *)

(** [config_path] is the [central]-specific file under the XDG config
    directory, typically [~/.config/central/user-config.json]. *)
val config_path : Fpath.t Lazy.t

val of_json : Json.t -> loc:Loc.t -> t
val load_exn : path:Fpath.t -> t

(** Reads {!config_path} if it exists, or returns a config equivalent to
    {!create} otherwise. *)
val default : t Lazy.t
