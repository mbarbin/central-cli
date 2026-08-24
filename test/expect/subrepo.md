# Subrepo

`Central.Subrepo.t` identifies one of the sub-repos vendored under `repo/`
in the enclosing monorepo. It isn't a fixed, hand-maintained enum: it's just
a validated string (the directory name under `repo/`), and the set of known
sub-repos is discovered dynamically by walking the filesystem.

## Discovery

`all` walks `repo/`'s direct children and keeps the ones that contain a
`.gitrepo` file, sorted by name:

`find_on_disk` looks a sub-repo name up against `all` - unlike `of_string`,
it validates that the name actually names a vendored sub-repo, not merely
that it has the right shape:

## Manipulating paths

Unlike `all` and `find_on_disk` above, everything in this section is pure
path manipulation: none of it reads the filesystem, or confirms that
anything it is given actually exists on disk.

`root` and `gitrepo_file_path` locate a sub-repo's own directory, and its
`.gitrepo` file, as paths in the enclosing monorepo:

`central_path` and `subrepo_path` convert a path back and forth between the
two frames of reference a path can be expressed in: relative to the
sub-repo's own root (what the sub-repo's standalone checkout sees), or
relative to the enclosing monorepo (prefixed with `root`, what the monorepo
checkout sees):

```text
repo/widget/src/dune
```

`subrepo_path` returns `None` for a path that doesn't belong to the
sub-repo at all - and, since a path in the sub-repo's own repo is never
empty, for the sub-repo's root itself:
