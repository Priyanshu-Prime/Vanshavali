# Git hooks

Local hooks that guard pushes for this repo. They live in version control (unlike
`.git/hooks/`) so everyone can share them.

## One-time setup

Point Git at this folder (run once per clone):

```sh
git config core.hooksPath .githooks
```

## What's here

- **pre-push** — runs `flutter analyze` and `flutter test` before a push and
  blocks it if either fails. This is the local mirror of `ci.yml`, catching
  breakage before it ever reaches the remote.

If you're on Windows, run the command from Git Bash (the hooks are POSIX `sh`
scripts, which Git for Windows executes with its bundled shell).

Emergency bypass (avoid unless truly necessary): `git push --no-verify`.
