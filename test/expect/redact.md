# Deterministic Revisions

Every command that touches git prints real revisions - commit hashes,
`MERGE_HEAD`, the trailing `>>>>>>> <sha>` on a conflict marker - and a real
revision is different every time a test runs, since it's derived from tree
content, parents, and commit timestamps, none of which stay fixed between
runs. Left alone, that would make every snapshot in this book flaky.

`Central_test_harness` fixes this by redacting: every real revision it sees
is auto-detected and rewritten to a deterministic mock counterpart (see the
conflict example in [Import](import.md) for one in the wild), so the same
command run today or a year from now prints the exact same snapshot.
`to_mock_rev`/`register_rev` map a real revision to its mock; `redact`
applies that mapping - and every abbreviated prefix git might plausibly
print for it - to a piece of text.

A mock revision is itself just a 40-character hex string, indistinguishable
from a real one. That has one sharp edge worth pinning down directly: a
mock revision can coincidentally *contain* a run of characters equal to
some other, unrelated revision's abbreviated prefix. `redact` has to
substitute every registered revision starting from the *original* text in a
single pass, so that a mock revision it has already written out is never
handed back for re-examination - otherwise a later, shorter pattern could
match inside it and corrupt it:

```text
1185512b92d612b25613f2e5b473e5231185512b
```
