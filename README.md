# central-cli

[![CI Status](https://github.com/mbarbin/central-cli/workflows/ci/badge.svg)](https://github.com/mbarbin/central-cli/actions/workflows/ci.yml)
[![Coverage Status](https://coveralls.io/repos/github/mbarbin/central-cli/badge.svg?branch=main)](https://coveralls.io/github/mbarbin/central-cli?branch=main)

A tool to help manage changes and git history between individual sub-repos
and a monorepo that aggregates them.

## Why

Monorepos are convenient, but publishing projects separately - sometimes
under different visibility levels (public vs private) - has real benefits.
`central` supports a workflow that combines both, allowing changes to be
promoted bidirectionally between the monorepo and each sub-repo's own
published history.

This workflow used to rely on
[git-subrepo](https://github.com/ingydotnet/git-subrepo). `.gitrepo` files
written by `central` follow the same conventions as git-subrepo's, so that
the two tools' workflows stay compatible. However, `central` does not aim
to be a full reimplementation of git-subrepo: it only ports, to OCaml, the
handful of workflows we actually rely on day to day. Exact compatibility
with git-subrepo is not thoroughly tested - the goal is to reduce our
overall dependency footprint, and eventually remove git-subrepo from our
critical path.

## Status

This repository is an early, evolving skeleton. Expect the shape of the
library, CLI, and commands to change as functionality is added.
