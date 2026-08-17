# Stitching a rewritten history

A narrower situation than [importing a change](import.md): you `export`ed a
change, then reworked the commit(s) that just landed in the subrepo's own
history - splitting it into a nicer sequence, rewording, reordering -
without changing the content it arrives at. `repo/<name>/.gitrepo` in
central still names the pre-rewrite commit, which doesn't exist on the
subrepo's `subrepo` branch any more.

`import` isn't the right tool here: there is nothing to actually bring in,
since the content hasn't changed - only the commit(s) carrying it have. The
fix is:

```
central stitch <name>
```

which simply repoints `.gitrepo` at the subrepo's new tip and commits that
update itself, with an auto-generated message - central's copy of a subrepo
isn't public history, so unlike `export` there's nothing worth writing by
hand here.

Say `widget`'s README got a couple of new paragraphs, exported as usual:

```ansi
$ central export widget -m "Document feature A and B"
==================== widget ====================
[ OK ] Applied patch in the subrepo.
[ OK ] Exported to [widget].
```

Now imagine that squashed commit gets reworked directly in `widget`'s
own history into two smaller commits instead - reaching the exact same
final `README.md` either way:

```ansi
Document feature B
Document feature A
Initial commit
```

`import` would refuse at this point - the commit `.gitrepo` names is
gone, so it can't tell this apart from history that was reset or
rewritten in some more troubling way. `stitch` recognizes it for what
it is and just catches `.gitrepo` up:

```ansi
$ central stitch widget
==================== widget ====================
[ OK ] Stitched [widget].
```

`central todo` shows the same pattern as after any `export` - `widget`'s
own `main` is one `advance-main` behind, nothing to do with the rewrite
just stitched over:

```ansi
$ central todo
┌──────────┬──────────────┬──────┐
│ Repo     │ Next step    │ Diff │
├──────────┼──────────────┼──────┤
│ central  │ push         │    8 │
│   widget │ advance-main │      │
└──────────┴──────────────┴──────┘
```

`stitch` refuses if the subrepo's tip has any real content diff against what
`.gitrepo` records - that would mean actual changes, not just a rewrite, and
those need `import` instead - or if central has moved on with local changes
of its own under `repo/<name>/` in the meantime.

That covers the two directions changes travel between central and a
subrepo. Either way, once a change has landed in a subrepo's own history,
the last step is [pushing it out for real](push.md).
