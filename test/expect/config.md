# Config

`central` reads two small, optional JSON config files, each with a
`$schema` under `schema/` for editor support:

- `Repo_config` - read from `.central/repo-config.json`, at the root of the
  monorepo itself. Currently just `name`, the string that identifies "the
  central repo" among the positional arguments to commands like `push` and
  `todo` (as opposed to a subrepo) - defaults to `"central"`.
- `User_config` - read from the XDG config directory,
  `~/.config/central/user-config.json`. Empty for now; a placeholder for
  per-user settings to come.

Both are entirely optional: a missing file just means the default.

`Repo_config.find_and_load` is what commands actually call: it looks for
`.central/repo-config.json` in the repo and falls back to the default if
it isn't there.

Unknown fields are rejected rather than silently ignored - a typo in the
config file is a loud error, not a silently-dropped setting:

`User_config` follows the same shape, currently an empty record:
