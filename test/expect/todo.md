# Todo

`central todo` is the dashboard: one row for central itself, plus one row
per subrepo that has something outstanding - each with its `Next step`
(what `central` command to run next) and, for subrepos, `Diff` (how many
lines under `repo/<name>/` differ from what's already been dealt with).
Subrepos with nothing outstanding simply don't appear, so the table only
ever shows what actually needs attention - see [the day-to-day
workflow](workflow.md) for it used end to end.

`central`'s own row uses `Repo_config.root_repo_name` as its label - `"central"` by
default, but configurable per-repo (see [config.md](config.md)).

Once `repo/widget/` has an uncommitted-to-upstream change, `widget` shows
up with `export` as its next step, and `central` itself already needs a
`push` for the commit that introduced it:

After `export`, `widget`'s next step becomes `advance-main` - the `Diff`
column goes blank, since there's no longer a content diff to size, only a
branch to fast-forward:

And with a `.central/repo-config.json` setting a custom `name`, that name -
not `"central"` - is what labels the top row:
