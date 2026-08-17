# Stitch

`central stitch <repo>` is for a narrower situation than `import`:
someone `export`ed a change, then reworked the commit(s) that just landed in
the subrepo's own history - splitting one commit into a nicer sequence,
squashing, reordering, rewording - without changing the tree they arrive at.
`repo/<repo>/.gitrepo` in central still names the pre-rewrite commit, which
no longer exists on the subrepo's `subrepo` branch.

Running `import` at this point would either fail outright (the old commit
isn't an ancestor of the new tip any more) or, if it somehow went through,
apply an empty patch for no reason - there is nothing to actually bring in,
since the tree hasn't changed. `stitch` is the narrow fix: it just repoints
`.gitrepo` at the subrepo's new tip, and commits that update with an
auto-generated message - central's copy of a subrepo isn't public history,
so unlike `export` there's nothing worth writing by hand here.

The required pre-conditions:

1. The `subrepo` branch has actually moved since the last sync.
2. There is no real content diff between the commit recorded in `.gitrepo`
   and the subrepo's current tip - i.e. this really is a pure history
   rewrite.
3. Central has no local changes of its own under `repo/<repo>/` since the
   last sync.

## Rewriting history after an export

Suppose a change lands in central and gets exported as usual, as one
squashed commit:

```ansi
$ central export widget -m "Document feature A and B"
==================== widget ====================
[ OK ] Applied patch in the subrepo.
[ OK ] Exported to [widget].
```

Now, imagine that squashed commit gets reworked directly in `widget`'s
own history into two smaller, better organized commits - reaching the
exact same final `README.md` either way. `.gitrepo` still names the
abandoned squash commit, which no longer exists on `subrepo`:

`import` would refuse here - the commit `.gitrepo` names is gone, so it
can't tell this apart from a more troubling rewrite. `stitch` recognizes
it for what it is and just catches `.gitrepo` up, committing the update
itself with an auto-generated message:

```ansi
$ central stitch widget
==================== widget ====================
[ OK ] Stitched [widget].
```

```ansi
Stitch repo widget
export widget
Document feature A and B
Add fake subrepo widget
Initial commit
```

Running `stitch` again right away is a clean error - `.gitrepo` is
already caught up, so there is nothing left to stitch:

```ansi
$ central stitch widget
==================== widget ====================
File "$CENTRAL_ROOT/repo/widget/.gitrepo", line 1, characters 0-0:
Error: Nothing to stitch: the [subrepo] branch of [widget] is already the
commit recorded in [.gitrepo].
[123]
```

And `central todo` confirms both sides agree - `widget`'s own `main`
just needs to catch up, same as after any ordinary `export`:

```ansi
$ central todo
┌──────────┬──────────────┬──────┐
│ Repo     │ Next step    │ Diff │
├──────────┼──────────────┼──────┤
│ central  │ push         │    8 │
│   widget │ advance-main │      │
└──────────┴──────────────┴──────┘
```

## Guardrails

`stitch` only repoints `.gitrepo` - it never brings in real content changes.
If the subrepo's tip actually differs in substance from what `.gitrepo`
records, this isn't a pure history rewrite any more, and `stitch` refuses
rather than silently pretending the trees still match:

```ansi
$ central stitch widget
==================== widget ====================
File "$CENTRAL_ROOT/repo/widget/.gitrepo", line 1, characters 0-0:
Error: Nothing to stitch: the [subrepo] branch of [widget] is already the
commit recorded in [.gitrepo].
[123]
```

```ansi
$ central stitch widget
==================== widget ====================
File "$CENTRAL_ROOT/repo/widget/.gitrepo", line 1, characters 0-0:
Error: Cannot stitch: "repo/widget" has content changes between the commit
recorded in [.gitrepo] and its current tip - this isn't a pure history
rewrite.
Hint: Use [central import] instead to bring those changes in.
[123]
```

And if central itself has moved on with local changes of its own under
`repo/<repo>/` since the last sync - even alongside an otherwise legitimate
history rewrite upstream - `stitch` refuses too, since a plain re-pointing
of `.gitrepo` can no longer account for the full picture:

```ansi
$ central export widget -m "Document feature A"
==================== widget ====================
[ OK ] Applied patch in the subrepo.
[ OK ] Exported to [widget].
```

```ansi
$ central stitch widget
==================== widget ====================
File "$CENTRAL_ROOT/repo/widget/.gitrepo", line 1, characters 0-0:
Error: Cannot stitch: central has local changes of its own under
"repo/widget" since the last sync.
Hint: Export or import those changes first, then stitch.
[123]
```

And as a precondition, `stitch` first checks that `central`'s own working
tree is clean - an unstaged edit is rejected outright, before anything else
is even looked at:

```ansi
$ central stitch widget
Error: Repo "$CENTRAL_ROOT" has uncommitted changes -
commit or stash them first.
Hint: M README.md
[123]
```
