(*_********************************************************************************)
(*_  central - Manage history between sub-repos and their monorepo                *)
(*_  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*_  SPDX-License-Identifier: MIT                                                 *)
(*_********************************************************************************)

(** Selecting which repo(s) a command should operate on.

    [Central.Subrepo.t] isn't a static enum, so [--all] can't be resolved to
    a concrete list of repos at argument-parsing time (that requires walking
    the filesystem from the monorepo root, which isn't known yet at that
    point). Likewise, which positional argument (if any) refers to the
    central repo itself depends on {!Central.Repo_config.root_repo_name}, which also
    requires [repo_root] to load. Instead, {!val:arg} returns a [t] that
    defers both; call {!val:resolve} once [repo_root] and the loaded
    {!Central.Repo_config.t} are known (typically right after
    [Common_helpers.find_enclosing_repo_root]). *)

type repo =
  | Central
  | Subrepo of Central.Subrepo.t

val name : repo_config:Central.Repo_config.t -> repo -> string

type t =
  | All
  | Default_central
  | Named of Central.Subrepo.t list

val arg : default_to_central:bool -> t Command.Arg.t

val resolve
  :  t
  -> repo_config:Central.Repo_config.t
  -> repo_root:Vcs.Repo_root.t
  -> repo list

val iter : repo list -> repo_config:Central.Repo_config.t -> f:(repo -> unit) -> unit

module Subrepos : sig
  type t =
    | All
    | Named of Central.Subrepo.t list

  val arg : t Command.Arg.t
  val resolve : t -> repo_root:Vcs.Repo_root.t -> Central.Subrepo.t list
  val iter : Central.Subrepo.t list -> f:(Central.Subrepo.t -> unit) -> unit
end
