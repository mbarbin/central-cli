(*_********************************************************************************)
(*_  central - Manage history between sub-repos and their monorepo                *)
(*_  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*_  SPDX-License-Identifier: MIT                                                 *)
(*_********************************************************************************)

(** Building fake [central] repos for tests, and small helpers shared by
    expect tests exercising them.

    [Central.Subrepo.t] is fully dynamic (a validated directory name, not a
    closed enum), so this harness can pick any subrepo name it likes for a
    test: a temporary directory standing in for the central repo, and one
    additional temporary directory per selected subrepo standing in for what
    would normally live in its own standalone checkout.

    Both are real git repos, wired together with a [.gitrepo] file exactly
    as a real subrepo setup would leave them - so [Subrepo_facts] (and
    everything built on top of it, such as [export]/[import]/[push]) can
    operate on the result unmodified.

    Each of the two also has its own real, separate bare repo standing in
    for its [origin] (see [remote_root] in {!type:Fake_subrepo.t} and
    [central_remote_root] in {!type:Fake_central.t}) - so [push] can be
    exercised for real, not just its next-step computation. *)

module Fake_subrepo : sig
  type t =
    { subrepo : Central.Subrepo.t
    ; repo_root : Vcs.Repo_root.t
      (** The root of the subrepo's own repo - what the [.gitrepo] file's
          [remote] field points to. *)
    ; remote_root : Vcs.Repo_root.t
      (** A real, separate bare repo that [repo_root] genuinely pushes to
          and tracks as [origin] - not to be confused with any real,
          production remote. Read it directly (e.g. with [git log]) to check
          what a [push <subrepo>] actually landed there. *)
    ; initial_rev : Vcs.Rev.t
      (** The single commit created in the subrepo repo, which both its
          [main] and [subrepo] local branches point to. Also the revision
          recorded as [.gitrepo]'s [commit] field in the central repo. *)
    }
end

module Fake_central : sig
  type t =
    { central_root : Vcs.Repo_root.t
    ; central_remote_root : Vcs.Repo_root.t
      (** Same idea as [Fake_subrepo.t.remote_root], for [central_root]. *)
    ; subrepos : Fake_subrepo.t list
    }

  (** Raises if no fake subrepo with this identity was created as part of
      [t]. *)
  val find_exn : t -> subrepo:Central.Subrepo.t -> Fake_subrepo.t
end

(** Create a fresh fake central repo (in a new temporary directory), with one
    fake subrepo (each in its own fresh temporary directory) per element of
    [subrepos].

    Each created directory is a real, standalone git repo:

    - The central repo has an initial commit, then one additional commit per
      subrepo that adds both a made up [repo/<name>/README.md] and the
      corresponding [repo/<name>/.gitrepo] file.
    - Each subrepo repo has a single commit (the same content as the
      [README.md] added to central), with both [main] and [subrepo] local
      branches pointing to it.
    - Both the central repo and each subrepo repo have already pushed
      [main] to their own (also freshly created) bare remote, and track it
      as [origin] - so a fresh [create]d repo looks like a checkout that is
      fully up to date, not one sitting on unpushed commits.

    None of the created directories - repos or remotes alike - are removed
    by this function - callers are expected to run this from a context that
    already takes care of cleaning up temporary directories, or to remove
    them individually when appropriate. *)
val create
  :  vcs:
       < Vcs.Trait.add
       ; Vcs.Trait.branch
       ; Vcs.Trait.commit
       ; Vcs.Trait.config
       ; Vcs.Trait.current_revision
       ; Vcs.Trait.git
       ; Vcs.Trait.init
       ; .. >
         Vcs.t
  -> subrepos:Central.Subrepo.t list
  -> Fake_central.t

(** {1 Small doc/test helpers}

    Not tied to [Fake_central]/[Fake_subrepo] specifically - just small
    conveniences for reading/writing files and printing stable output in an
    expect test. *)

val read_file : repo_root:Vcs.Repo_root.t -> path_in_repo:Vcs.Path_in_repo.t -> string
val print_file : repo_root:Vcs.Repo_root.t -> path_in_repo:Vcs.Path_in_repo.t -> unit

(** [~first_parent] walks a single deterministic chain (git's own
    [--first-parent]) instead of the full history - use it whenever [ref_]'s
    history includes a merge, so the printed order doesn't depend on the
    unstable tie-break between sibling commits created within the same
    second (a real source of flakiness otherwise: git's default order for
    same-timestamp commits isn't guaranteed stable). *)
val print_log_subjects
  :  ?first_parent:bool
  -> vcs:< Vcs.Trait.git ; .. > Vcs.t
  -> repo_root:Vcs.Repo_root.t
  -> ref_:string
  -> unit
  -> unit

(** Prints [git log --graph --format=%s <refs>] - [refs] is passed through
    as-is (revs, branch names, [--all], ...), so a commit not reachable from
    any ref can still be shown by naming it explicitly. *)
val print_graph
  :  vcs:< Vcs.Trait.git ; .. > Vcs.t
  -> repo_root:Vcs.Repo_root.t
  -> refs:string list
  -> unit

(** Creates any missing parent directories under [repo_root] as needed. *)
val write_file
  :  repo_root:Vcs.Repo_root.t
  -> path_in_repo:Vcs.Path_in_repo.t
  -> contents:string
  -> unit

val append_file
  :  repo_root:Vcs.Repo_root.t
  -> path_in_repo:Vcs.Path_in_repo.t
  -> text:string
  -> unit

val commit
  :  vcs:< Vcs.Trait.commit ; Vcs.Trait.current_revision ; .. > Vcs.t
  -> repo_root:Vcs.Repo_root.t
  -> commit_message:string
  -> Vcs.Rev.t
