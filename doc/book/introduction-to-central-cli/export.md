# Exporting a change

Most day-to-day edits to a subrepo happen the easy way: you just edit files
under `repo/<name>/` directly in central, like you would any other file, and
commit as usual. The one extra step is telling central to carry that change
out into the subrepo's own history:

```
central export <name> -m "<message>"
```

Say you've just edited `widget`'s README and committed that in central. Not
sure what to do next? `central todo` always knows:

```ansi
$ central todo
┌──────────┬───────────┬──────┐
│ Repo     │ Next step │ Diff │
├──────────┼───────────┼──────┤
│ central  │ push      │    2 │
│   widget │ export    │    2 │
└──────────┴───────────┴──────┘
```

Following it means exporting:

```ansi
$ central export widget -m "Document installation"
==================== widget ====================
[ OK ] Applied patch in the subrepo.
[ OK ] Exported to [widget].
```

`widget` now has a real new commit, with your message, on top of its
`subrepo` branch:

```ansi
Document installation
Initial commit
```

Checking back in with `central todo` shows `widget`'s row is still
there, but the next step changed: `export` only advances the
`subrepo` branch, so `widget`'s own `main` is now behind it - a
genuine second step, covered in
[Pushing your changes](push.md), not a leftover of the first:

```ansi
$ central todo
┌──────────┬──────────────┬──────┐
│ Repo     │ Next step    │ Diff │
├──────────┼──────────────┼──────┤
│ central  │ push         │    6 │
│   widget │ advance-main │      │
└──────────┴──────────────┴──────┘
```

`export` always squashes everything you changed under `repo/<name>/` since
the last export into that one new commit - it doesn't try to replay your
central commits one by one. If you made several commits in central along
the way, only the final state matters; `-m` is the message the subrepo
commit gets.

## If there's nothing to export

Running `export` again right away, with nothing new under `repo/<name>/`,
is a clean error rather than an empty commit - a useful sanity check if
you're not sure whether your change already went out:

```ansi
$ central export widget -m "Nothing changed"
==================== widget ====================
Error: Nothing to export: no changes under "repo/widget" since the last sync.
[123]
```

## Exporting several subrepos at once

Some changes are chores that touch many subrepos the same way - bumping a
shared convention, applying the same fix everywhere. `export` accepts more
than one `REPO` on the command line (or `--all` for every subrepo), and
exports them one after another, in the order given, reusing the same `-m`
message for each:

```ansi
$ central export widget gadget sprocket -m "Add license footer"
==================== widget ====================
[ OK ] Applied patch in the subrepo.
[ OK ] Exported to [widget].
==================== gadget ====================
[ OK ] Applied patch in the subrepo.
[ OK ] Exported to [gadget].
==================== sprocket ====================
[ OK ] Applied patch in the subrepo.
[ OK ] Exported to [sprocket].
```

```ansi
$ central todo
┌────────────┬──────────────┬──────┐
│ Repo       │ Next step    │ Diff │
├────────────┼──────────────┼──────┤
│ central    │ push         │   18 │
│   gadget   │ advance-main │      │
│   sprocket │ advance-main │      │
│   widget   │ advance-main │      │
└────────────┴──────────────┴──────┘
```

If one of them fails partway through - say a subrepo's `subrepo` branch
moved on its own since the last sync - `export` stops right there: the
repos before it keep whatever they already got exported, and the ones after
it are never even attempted. See `test/expect/export.ml` for that scenario
in detail, along with every other guardrail covered above.

That's the everyday case covered. The next chapter,
[Importing a change](import.md), covers the other direction - bringing
commits made directly in a subrepo's own history back into central.
