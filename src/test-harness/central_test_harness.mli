(*_********************************************************************************)
(*_  central - Manage history between sub-repos and their monorepo                *)
(*_  SPDX-FileCopyrightText: 2024-2026 Mathieu Barbin <mathieu.barbin@gmail.com>  *)
(*_  SPDX-License-Identifier: MIT                                                 *)
(*_********************************************************************************)

(** Running the real [central] executable from within expect tests.

    This spawns the actual compiled binary as a subprocess, so a test built
    on this harness shows precisely what a [central] user would see typing
    the same command in their terminal, including its command-line parsing,
    its exit code, and anything it prints.

    [central] has no server to manage, so this is much simpler than a
    client/server harness: create one [t] per test, then call {!run} once per
    command. *)

type t

(** [repo_root] is required so a harness can never forget to mask it: any
    occurrence of its absolute path in a transcript is rewritten to
    [$CENTRAL_ROOT]. *)
val create : repo_root:Vcs.Repo_root.t -> t

(** {1 Mock revisions}

    {!run} auto-detects and rewrites full 40-character git revisions
    wherever they appear in a transcript. It cannot do the same for
    *abbreviated* ones (e.g. the "Updating a1b2c3d..e4f5678" summary line
    printed by a fast-forward [git merge]) unless the full revision was
    already registered - either because it appeared in full somewhere
    earlier in the same transcript, or because it was registered ahead of
    time with one of the functions below. *)

(** Map a real revision to its deterministic mock counterpart, and register
    it (and every abbreviated prefix a person might plausibly see printed by
    git for it) for rewriting. Idempotent: calling it multiple times with the
    same revision returns the same mock. *)
val to_mock_rev : t -> rev:Vcs.Rev.t -> Vcs.Rev.t

(** Same as {!to_mock_rev}, discarding the result - use when you only need
    the side effect of registering [rev] for output rewriting. *)
val register_rev : t -> rev:Vcs.Rev.t -> unit

(** Apply the same rewriting {!run} applies to a command's captured output to
    an arbitrary piece of text - e.g. a file read directly off disk (which
    doesn't go through {!run} at all), such as one left with unresolved merge
    conflict markers, whose trailing [>>>>>>> <sha>] would otherwise be
    non-deterministic. *)
val redact : t -> string -> string

(** [run t ~cwd [ [ "export"; "foo" ]; [ "-m"; "msg" ] ]] spawns the real
    [central] executable with the concatenation of the given argument groups,
    with [cwd] as its working directory (so [central]'s own "find the
    enclosing repo" logic resolves against a fake repo built by
    [Central_test_helpers], exactly as it would resolve against a real
    checkout), and prints a cram-like transcript: a header line built from
    the groups (kept visually grouped, the way a person would type them),
    then the process's stdout and stderr (in that order - the two streams
    are captured separately, so true interleaving is not preserved), with
    any registered repo roots substituted and any 40-character hex string (a
    git revision) rewritten to a deterministic mock so the transcript is
    stable across runs. A non-zero exit code is appended as a trailing
    [[N]] line, matching cram's own convention.

    The grouping exists purely for readability of the printed header - e.g.
    [ [ "export"; "foo" ]; [ "-m"; "msg" ] ] and
    [ [ "export"; "foo"; "-m"; "msg" ] ] run the identical command; split
    into groups when that reads more like something a person would actually
    type. *)
val run : t -> cwd:Vcs.Repo_root.t -> string list list -> unit

(** [let@ central = with_cli t ~cwd in central [ [ "todo" ] ]] - the same as
    {!run}, curried so a test can bind [central] once per scenario and call
    it like a shell prompt for each command that follows. *)
val with_cli : t -> cwd:Vcs.Repo_root.t -> ((string list list -> unit) -> unit) -> unit
