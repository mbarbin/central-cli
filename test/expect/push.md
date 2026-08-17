# Push

`central push <repo>...` pushes the given repo's (or repos') `main` branch
to its real remote - the final step once a change has made its way all the
way to a subrepo's own `main` (via `export`, then `advance-main` if needed),
or simply for central's own local commits.

By default, before pushing, it opens `gitk --all` to visualize the history
and asks for confirmation; every example below passes `--yes` to skip both,
the way this would run non-interactively (e.g. from a script or CI).

## Nothing to push

Right after `Central_test_helpers.create`, every repo's `main` is already
up to date with its own remote - pushing is a clean no-op:

```ansi
$ central push central --yes
==================== central ====================
[SKIP] Skipping [push] (not applicable).
```

## Pushing central's own commits

Once central has a local commit its remote doesn't have yet, `push` is
applicable, and sends it there. Here, that commit comes from `import`ing an
upstream change from `widget` - the everyday way central ends up with
something to push:

```ansi
$ central import widget
[ OK ] Imported into [main] directly (no merge needed).
Add fake subrepo widget
Initial commit
```

```ansi
$ central push central --yes
==================== central ====================
[ OK ] Pushed.
```

The commit really is on the remote now - reading its log directly
(rather than trusting `central`'s own say-so) confirms it:

```ansi
Import changes from widget
Add fake subrepo widget
Initial commit
```

## Pushing a subrepo

The same, for a subrepo's own `main` - as it would be after a change went
through `export` (and `advance-main`, catching `main` up to the `subrepo`
branch export landed on). Here, to isolate what `push` itself does, `main`
gets a commit directly:

```ansi
$ central push widget --yes
==================== widget ====================
[ OK ] Pushed.
```

```ansi
Direct edit in widget
Initial commit
```

`--dry-run`/interactive mode (the default) opens `gitk --all` to preview the
history before confirming - which needs a real display and isn't something
this book can exercise deterministically. The "not applicable" guard is
checked before the preview, though, so that much is safe to demonstrate
regardless of confirm mode:

```ansi
$ central push central --dry-run
==================== central ====================
[SKIP] Skipping [push] (not applicable).
```
