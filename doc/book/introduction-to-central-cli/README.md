# Introduction to central

*A user-facing tour of the `central` CLI.*

This book is a short, user-facing tour of `central` - the command-line tool
that manages the relationship between a monorepo and the standalone git
repos ("subrepos") that live inside it.

> This is an introductory read, not the full reference. Where it matters,
> it points at `central <command> --help` for the details it leaves out.
> For a detailed, developer/agent-facing account of exactly how each
> command behaves, including every guardrail and error case, see central's
> own [test suite](../../../test/expect), which doubles as executable
> documentation.

## Why subrepos?

A number of independent projects are sometimes developed together, in one
place, so that changes spanning several of them can be made and reviewed
atomically. But each of those projects is *also* a real, standalone
open-source repository with its own history, its own remote, and its own
life outside the monorepo.

`central` is what keeps those two things true at once. Each subrepo lives
under `repo/<name>/` in the monorepo, with a small `.gitrepo` file
recording where its own, independent git history currently stands relative
to the monorepo's. Two commands keep that relationship moving:

- **`central export`** - takes changes made directly under
  `repo/<name>/` in the monorepo and turns them into a real commit in the
  subrepo's own history.
- **`central import`** - brings commits made in the subrepo's own
  history (typically fetched from its real, public remote) back into
  the monorepo.

Together, they mean you can edit a subrepo's code from within the monorepo
like any other file, and separately, its own history stays a normal,
coherent git history - not a copy, not a submodule, a real independent repo
that happens to also be mirrored here.

## What's in this book

- [Exporting a change](export.md) - the everyday case: you edited something
  under `repo/<name>/`, and want it to become a proper commit in that
  subrepo's own history.
- [Importing a change](import.md) - the other direction: bringing commits
  made directly in a subrepo's own history back into the monorepo,
  conflicts included.
- [Stitching a rewritten history](stitch.md) - a narrower case: the
  subrepo's history was reworked after an export without changing its
  content, so there's nothing to import, only `.gitrepo` to catch up.
- [Pushing your changes](push.md) - the last step: getting a change that's
  landed in a subrepo's own history (or in the monorepo's) out to its real
  remote.

`central todo` - a dashboard of outstanding work across every subrepo -
comes up throughout as the constant thread tying these commands together.
More chapters will follow as `central` grows, notably recovering from less
common situations (a subrepo pushed to directly).
