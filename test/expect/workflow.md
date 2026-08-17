# A day-to-day workflow

This walks through the everyday loop of working in `central`: edit
something, check `central todo` for what needs attention, act on it, and
confirm the dashboard is clear again.

`central todo`'s dashboard covers every subrepo `central` knows about, so
this fake repo (unlike the one on the [Export](export.md) page) is built
with a few of them, not just `widget` - enough to show the dashboard
correctly narrows down to only what needs attention.

With nothing out of the ordinary going on, the dashboard is empty:

```ansi
$ central todo
```

## Editing directly in central

Suppose someone edits `repo/widget/README.md` directly from within `central`
and commits it there - the way most day-to-day changes happen.

`central todo` now shows `widget` needs attention:

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

`widget`'s row is still there, but the next step changed: `export` only
advances the subrepo's `subrepo` branch, so `widget`'s own `main` branch
is now behind it. This is a genuine second step, not a leftover of the
first:

```ansi
$ central todo
┌──────────┬──────────────┬──────┐
│ Repo     │ Next step    │ Diff │
├──────────┼──────────────┼──────┤
│ central  │ push         │    6 │
│   widget │ advance-main │      │
└──────────┴──────────────┴──────┘
```

`advance-main` is exactly that: catch `widget`'s `main` branch up:

```ansi
$ central advance-main widget
==================== widget ====================
Updating 1185512..f452a6f
Fast-forward
 README.md | 2 ++
 1 file changed, 2 insertions(+)
```

`widget` is left with a `push` next step, same as `central` itself: both
now have local commits their own remote doesn't have yet - central's
edit and the `.gitrepo` update `export` made, and the commit
`advance-main` just fast-forwarded `widget`'s own `main` to:

```ansi
$ central todo
┌──────────┬───────────┬──────┐
│ Repo     │ Next step │ Diff │
├──────────┼───────────┼──────┤
│ central  │ push      │    6 │
│   widget │ push      │      │
└──────────┴───────────┴──────┘
```

`push` closes the loop for both at once - a real `git push` to each
one's own remote:

```ansi
$ central push central widget --yes
==================== central ====================
[ OK ] Pushed.
==================== widget ====================
[ OK ] Pushed.
```

And the dashboard is clear again - back where we started, the change
now genuinely out, all the way to both real remotes:

```ansi
$ central todo
```
