# Advance Main, Advance Subrepo

`export` only ever moves a subrepo's `subrepo` branch - it never touches
`main`, so `main` falls one commit behind after every export. Two commands
catch it back up, at different scopes:

- `central advance-main <repo>` fast-forwards that subrepo's local `main`
  branch to match `subrepo`, from the same machine an `export` (or `import`)
  just ran on - the everyday, single-machine case.
- `central advance-subrepo <repo>` is the more thorough version, aimed at a
  *second* machine: after pulling central's own `main` (which brings in
  whatever `.gitrepo` now says), it fast-forwards that subrepo's local
  `subrepo` *and* `main` branches to match - both in one go, provided the
  commit `.gitrepo` points to is already present locally (e.g. already
  fetched from the subrepo's real remote - `advance-subrepo` itself never
  fetches anything).

## Advance-main, right after an export

`export` lands a commit on `widget`'s `subrepo` branch - `main` hasn't
moved:

```ansi
$ central advance-main widget
==================== widget ====================
Updating 1185512..f452a6f
Fast-forward
 README.md | 2 ++
 1 file changed, 2 insertions(+)
```

`main` is fast-forwarded to the same commit `subrepo` already carried:

```ansi
Document installation
Initial commit
```

Right after `Central_test_helpers.create`, there's nothing for `main` to
catch up to:

```ansi
$ central advance-main widget
==================== widget ====================
[SKIP] Skipping [advance-main] (not applicable).
```

## Advance-subrepo, catching up a fresh checkout on another machine

Say a change was already exported and pushed from elsewhere: central's own
`.gitrepo` (as pulled from its real remote) now points at a newer `widget`
commit, already fetched into this machine's own checkout of `widget` (e.g.
by a plain `git fetch`, run once ahead of time), but not yet merged into
either its `subrepo` or `main` branch. `advance-subrepo` brings both up to
date in one command:

```ansi
$ central advance-subrepo widget
==================== widget ====================
Updating f452a6f..1185512
Fast-forward
 README.md | 2 ++
 1 file changed, 2 insertions(+)
Updating f452a6f..1185512
Fast-forward
 README.md | 2 ++
 1 file changed, 2 insertions(+)
```

`subrepo` is on the new commit now:

```ansi
Document installation
Initial commit
```

And so is `main` - both branches now point at the very same commit:

```ansi
Document installation
Initial commit
```
