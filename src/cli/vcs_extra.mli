(*_********************************************************************************)
(*_  central - Manage history between sub-repos and their monorepo                *)
(*_  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*_  SPDX-License-Identifier: MIT                                                 *)
(*_********************************************************************************)

(*_ This is a trimmed copy of a [vcs_extra] library maintained elsewhere by
  the same author, relicensed here as MIT. Only what [export]/[import]/
  [push] actually need is copied over: [find_local_branch_exn],
  [find_remote_tracking_node_exn] and their [branch_tracking] dependency
  chain. *)

(** Return the remote branch that is configured as the branch that a local
    branch is tracking. Reports to [Err] when looking for tracking information
    failed. *)
val branch_tracking_opt_exn
  :  < Vcs.Trait.git ; .. > Vcs.t
  -> repo_root:Vcs.Repo_root.t
  -> branch_name:Vcs.Branch_name.t
  -> Vcs.Remote_branch_name.t option

(** A convenient wrapper for [branch_tracking] that reports to [Err] when no
    remote tracking branch is found. *)
val branch_tracking_exn
  :  < Vcs.Trait.git ; .. > Vcs.t
  -> repo_root:Vcs.Repo_root.t
  -> branch_name:Vcs.Branch_name.t
  -> Vcs.Remote_branch_name.t

val find_local_branch_exn
  :  repo_root:Vcs.Repo_root.t
  -> graph:Vcs.Graph.t
  -> branch_name:Vcs.Branch_name.t
  -> Vcs.Graph.Node.t

val find_remote_tracking_node_exn
  :  < Vcs.Trait.git ; .. > Vcs.t
  -> repo_root:Vcs.Repo_root.t
  -> graph:Vcs.Graph.t
  -> branch_name:Vcs.Branch_name.t
  -> Vcs.Graph.Node.t
