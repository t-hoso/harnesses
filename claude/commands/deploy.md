---
description: Deploy the claude/ hooks payload to a target (global or a project)
argument-hint: --global | --project <path> [--dry-run] [--force]
---
Deploy this repository's hooks/commands/skills payload by running its installer.

Run: `./install.sh $ARGUMENTS`

If no arguments were provided, ask whether to target `--global` (the user's
`~/.claude`) or `--project <path>`, then run the installer with that choice.
Prefer `--dry-run` first to show the diff before applying.
