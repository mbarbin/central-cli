# License

This project is released under the terms of the `MIT` license.

This notice file documents the organization of files and headers that relate to licenses, and the third-party code vendored into this repository.

## License, copyright & notices

- **COPYING.HEADER** contains the copyright and license notice. It is added as a header to every file in the project.

- **LICENSE** contains a copy of the full MIT license.

- **NOTICE.md** (this file) documents the project licensing and third-party vendored code.

## Third party licenses

Under `third-party-license/` we include the license of software used as vendored code. The vendored code retains its original upstream license; only that vendored code is so licensed, not this project as a whole.

## mbarbin/parsing-utils

The library in `src/parsing-utils/` vendors
[parsing-utils](https://github.com/mbarbin/parsing-utils), released under
`MIT` by the same author as this project, unchanged from upstream. Its dune
library is named `central_parsing_utils` (rather than `parsing_utils`) so
that apps that end up linking both the original package and this vendored
copy do not hit a library name conflict; since the library name differs
from the file name, dune itself exposes the vendored module as
`Central_parsing_utils.Parsing_utils` - no wrapper file is needed. See
`src/parsing-utils/parsing_utils.ml`.

A copy of the license file for parsing-utils is located under
`third-party-license/mbarbin/parsing-utils/LICENSE`.

## Gazagnaire ocaml-merge3 (Myers diff)

The Myers shortest-edit-script computation in `src/merge3/merge3.ml` is
vendored from [ocaml-merge3](https://tangled.sh/@gazagnaire.org/monopampam)
by Thomas Gazagnaire (released under `ISC`). Only the pure diff computation
is vendored; the parts unused by this project are not included. The exact
provenance and list of changes are documented at the top of
`src/merge3/merge3.ml` and in `src/merge3/vendor.json`.

A copy of the license file for ocaml-merge3 is located under
`third-party-license/gazagnaire/ocaml-merge3/LICENSE.md`.

## Windtrap (unified-diff renderer)

The unified-diff renderer in `src/myers/myers.ml` is vendored from
[windtrap](https://github.com/invariant-hq/windtrap) by Invariant Systems
(released under `ISC`). The exact provenance and list of changes are
documented at the top of `src/myers/myers.ml` and in `src/myers/vendor.json`.

A copy of the license file for windtrap is located under
`third-party-license/invariant-hq/windtrap/LICENSE`.

## A note about Base

A few helpers from the [Base](https://github.com/janestreet/base) project (released under `MIT`) are reproduced in our local `Stdlib` extensions, to avoid taking on `base` as a direct dependency.

The relevant file is `src/stdlib/string0.ml`. It carries a notice at the top of the file, and the copied functions are clearly indicated next to the code.

A copy of the license file for Base is located under
`third-party-license/janestreet/base/LICENSE.md`.

## Highlight.js

The syntax highlighter used by the doc book pages,
`doc/book/shared-theme/highlight.js` (and its copy under
`doc/book/introduction-to-central-cli/shared-theme/`), is
[Highlight.js](https://highlightjs.org), released under `BSD-3-Clause`.
The file carries its own license header.

A copy of the license file for Highlight.js is located under
`third-party-license/highlightjs/highlight.js/LICENSE`.

## A note about ZolaNight

The templates and styles under `doc/templates/` and `doc/sass/` are derived
from the [ZolaNight](https://github.com/mxaddict/zolanight) theme by
mxaddict, released under `MIT`. See `doc/NOTICE-zolanight`.
