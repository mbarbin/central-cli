(*_********************************************************************************)
(*_  central - Manage history between sub-repos and their monorepo                *)
(*_  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*_  SPDX-License-Identifier: MIT                                                 *)
(*_********************************************************************************)

(** Per-repository configuration, optionally read from
    [.central/repo-config.json] at the root of the enclosing monorepo.

    We are using JSON as the serialization format. This is an early,
    minimal version of the config - more fields will be added as the CLI
    grows. See [schema/central-repo-config.schema.json] at the root of this
    repository. *)

type t

val to_json : t -> Json.t

(** {1 Fields} *)

(** The name of the monorepo itself, as shown e.g. in [central todo]'s
    table, and used to resolve [central] as a "which repos" selector on the
    command line. Defaults to ["central"]. *)
val root_repo_name : t -> string

(** {1 Create configs} *)

val create : ?root_repo_name:string -> unit -> t

(** The config used when no [.central/repo-config.json] file is found. *)
val default : t

(** {1 Loading} *)

(** [path_in_repo] is [.central/repo-config.json], relative to the root of
    the enclosing monorepo. *)
val path_in_repo : Vcs.Path_in_repo.t

val of_json : Json.t -> loc:Loc.t -> t
val load_exn : path:Fpath.t -> t

(** [find_and_load ~repo_root] reads {!path_in_repo} under [repo_root] if
    it exists, or returns {!default} otherwise. *)
val find_and_load : repo_root:Vcs.Repo_root.t -> t
