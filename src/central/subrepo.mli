(*_********************************************************************************)
(*_  central - Manage history between sub-repos and their monorepo                *)
(*_  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*_  SPDX-License-Identifier: MIT                                                 *)
(*_********************************************************************************)

(** Identifies one of the sub-repos vendored under [repo/] in the enclosing
    monorepo.

    [t] is not a fixed, hand-maintained enum: it is just a validated string
    (the directory name under [repo/]), and the set of known sub-repos is
    discovered dynamically by {!all}, by walking the filesystem. *)

type t

val to_string : t -> string
val of_string : string -> (t, [ `Msg of string ]) Result.t
val v : string -> t
val equal : t -> t -> bool
val compare : t -> t -> int
val hash : t -> int
val to_dyn : t -> Dyn.t

(** [repo/NAME], relative to the root of the enclosing monorepo. *)
val root : t -> Vcs.Path_in_repo.t

(** [repo/NAME/.gitrepo], relative to the root of the enclosing monorepo. *)
val gitrepo_file_path : t -> Vcs.Path_in_repo.t

(** Discover the sub-repos vendored under [repo/] in [repo_root]: this walks
    its direct children and keeps the ones that contain a [.gitrepo] file.
    The result is sorted by name. *)
val all : repo_root:Vcs.Repo_root.t -> t list

(** Look [name] (a sub-repo name, e.g. what {!to_string} returns - not a
    path) up against {!all}. Unlike {!of_string}, this validates that the
    name actually names a vendored sub-repo (not merely that it has the
    right shape). This reads the filesystem (via {!all}). *)
val find_on_disk : repo_root:Vcs.Repo_root.t -> name:string -> t option

(** {1 Manipulating paths}

    Pure path manipulation: unlike {!find_on_disk}, neither of these reads
    the filesystem, and neither confirms that the sub-repo or the path it is
    given actually exist on disk. *)

(** [central_path t ~subrepo_path] is [subrepo_path], expressed as a path in
    the enclosing monorepo (i.e. prefixed with {!root}). *)
val central_path : t -> subrepo_path:Vcs.Path_in_repo.t -> Vcs.Path_in_repo.t

(** [subrepo_path t ~central_path] is [central_path], expressed relative to
    [t]'s own root, if [central_path] is strictly under {!root} (not equal to
    it - a path in the subrepo's own repo is never empty). *)
val subrepo_path : t -> central_path:Vcs.Path_in_repo.t -> Vcs.Path_in_repo.t option
