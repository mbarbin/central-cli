(*_********************************************************************************)
(*_  central - Manage history between sub-repos and their monorepo                *)
(*_  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*_  SPDX-License-Identifier: MIT                                                 *)
(*_********************************************************************************)

(** Helpers for command line arguments. *)

(** Find enclosing repo or raise an error compatible with the command handler in
    use. *)
val find_enclosing_repo_root
  :  < Vcs.Trait.file_system ; .. > Vcs.t
  -> from:Absolute_path.t
  -> Vcs.Repo_root.t

(** When using [Spawn.spawn] we need to supply the full path to the [prog] we
    want to run (e.g. "gitk"). Spawn won't look in the PATH for us, so this
    is what this function does. *)
val resolve_in_path : prog:string -> string

(** Raises if [repo_root] has any uncommitted change (staged or not, tracked
    or untracked) - i.e. if [git status --porcelain] would print anything.
    Meant as a precondition for commands that create commits or move
    branches programmatically (e.g. [export]/[import]): with a dirty
    working tree, "the diff since the last sync" or "checkout, then apply"
    could pick up unrelated local changes, or a [git merge] could refuse in
    a confusing way. *)
val ensure_clean_working_tree
  :  vcs:< Vcs.Trait.git ; .. > Vcs.t
  -> repo_root:Vcs.Repo_root.t
  -> unit
