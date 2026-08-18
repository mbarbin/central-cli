# Central Test Suite

This is `central`'s own test suite, and also its book: pages are generated
from OCaml source files (via [mdexp](https://github.com/mbarbin/mdexp))
that are also real, running `dune runtest`s, so the narrative prose, the
code, and the snapshots you see embedded in a page are never allowed to
drift from what actually happens when the code runs.

## Layout

- `expect/` holds every test file, both the literate, book-generating ones
  (each carrying `@mdexp` directives and a generated `.md` counterpart,
  checked in next to the `.ml` - see `SUMMARY.md` for the current list of
  pages) and the plain ones (`test__central.ml`).
- `gitrepo/` and `gitrepo-file-parser/` test the `.gitrepo` file parser in
  isolation.

This is part of the effort to move `central`'s subrepo workflow off
`git-subrepo` and onto small, dedicated pieces of OCaml logic: each command
gets a page here explaining what it does and demonstrating it end to end.
The intent is for this book to grow to cover `central` more broadly, not
just the subrepo commands.

## How does it relate to the user documentation?

There is inevitable overlap between this test book and the documentation in
`doc/`. The key difference is intent:

- **`doc/`** is focused on the **user experience** - how to install,
  configure, and use `central`. It omits low-level details.
- **`test/`** is focused on **correctness** - every guardrail, every error
  case, every CLI invocation. It includes details that would overwhelm a
  user guide but are essential for someone modifying the code.

When both cover the same topic, the doc version explains *what to do* while
the test version proves *that it works*.

## Building

```bash
dune runtest
```

regenerates the book's pages from their source `.ml` files, and runs every
other test in the tree. To browse the book itself:

```bash
cd test && mdbook serve --open
```
