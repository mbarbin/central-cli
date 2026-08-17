# Pushing your changes

`export` (and `advance-main`, when needed) bring a change all the way to a
subrepo's own `main` branch - but only in your local checkout. The last
step is getting it out to the subrepo's real remote:

```
central push <name>
```

`central` itself needs the same treatment: any local commit not yet on its
own remote (including, as you're about to see, the one `export` itself just
made to update `.gitrepo`). By default `push` opens `gitk` to show you what
you're about to push and asks for confirmation; pass `--yes` to skip both
and push right away.

## Finishing the loop

Picking up where [Exporting a change](export.md) left off: `widget`'s
README was edited in central and committed there. `central todo` is the
constant thread through all of this - it's what tells you export is next:

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

Checking back in, `widget`'s next step changed - `export` only moved
its `subrepo` branch, so `main` is now behind it:

```ansi
$ central todo
┌──────────┬──────────────┬──────┐
│ Repo     │ Next step    │ Diff │
├──────────┼──────────────┼──────┤
│ central  │ push         │    6 │
│   widget │ advance-main │      │
└──────────┴──────────────┴──────┘
```

`advance-main` catches it up:

```ansi
$ central advance-main widget
==================== widget ====================
Updating 1185512..f452a6f
Fast-forward
 README.md | 2 ++
 1 file changed, 2 insertions(+)
```

Now both central and `widget` have local commits their remotes don't
have yet - the dashboard agrees, with the same next step for both:

```ansi
$ central todo
┌──────────┬───────────┬──────┐
│ Repo     │ Next step │ Diff │
├──────────┼───────────┼──────┤
│ central  │ push      │    6 │
│   widget │ push      │      │
└──────────┴───────────┴──────┘
```

`push` sends them all in one go:

```ansi
$ central push central widget --yes
==================== central ====================
[ OK ] Pushed.
==================== widget ====================
[ OK ] Pushed.
```

And the dashboard is clear - back where it started, the change now
genuinely out, all the way to both real remotes:

```ansi
$ central todo
```

That's the full loop, start to finish: edit under `repo/<name>/`, `export`
it, `advance-main` if `main` is left behind, `push` - and `central todo`
tells you what's next at every step along the way.
