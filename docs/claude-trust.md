# How Claude Code trusts a factory's folders

Claude Code asks "Do you trust the files in this folder?" before it runs in a folder it has not seen. A worker or reviewer that hits this dialog waits until someone accepts it. This page explains how Claude Code decides that a folder is trusted, which folder the dialog names in a factory, and why `bin/lagom-trust` marks the folders it does.

## Where Claude Code records trust

Claude Code keeps trust in its global config file, `.claude.json`. The file sits in the home folder, or in `CLAUDE_CONFIG_DIR` when that variable is set. Each trusted folder has an entry under `projects` with `hasTrustDialogAccepted` set to `true`:

```json
{
  "projects": {
    "/home/user/src/example-repo": {
      "hasTrustDialogAccepted": true
    }
  }
}
```

The [permissions page](https://code.claude.com/docs/en/permissions.md#project-allow-rules-and-workspace-trust) of the Claude Code docs documents this key as the way to trust a folder by hand. The docs name no CLI flag, setting, or environment variable that marks a folder as trusted. `claude -p` shows no dialog, but it does not mark the folder either. The home folder is a special case: Claude Code keeps its trust for one session and never writes it.

## Which folder the key names

The key is not always the folder that Claude Code starts in.

- Inside a git repo, the key is the repo's root folder. Trust covers the whole repo, except a git repo nested inside it, such as a submodule.
- Inside a git worktree, the key is the root of the main checkout, not the worktree.
- Outside a git repo, the key is the folder itself, and the trust covers every subfolder.

A trusted parent folder does not cover a git repo inside it. Trust of `/home/user/src` does not help a session in `/home/user/src/example-repo` when that folder is a git repo.

## Which folder prompts in a factory

sfy starts each worker and each reviewer with its working folder at `<sfy_home>/work/<id>`. For a task with a repo, that folder is a git worktree. Its common git folder is the `.git` folder of the operator's source repo, so Claude Code looks up the source repo's root. The dialog therefore appears once for each new source repo, the first time any task uses it. Each later worktree of that repo is covered.

For a repo without a local source, sfy keeps a clone at `<sfy_home>/repos/<name>-<hash>`. These clones also appear as keys in `.claude.json`, so each clone prompts once too.

A task without a repo, such as a plan task, runs in a plain folder under `<sfy_home>/work`. That folder is no git repo, so trust of `<sfy_home>/work` covers it.

## What lagom-trust marks

`lagom-trust sync` marks these folders for the factory in `SFY_HOME`:

- The repo root of the `## Repo` path in each task file, `<sfy_home>/tasks/<id>/task.md`. Archived tasks count too.
- The root of each git repo under `<sfy_home>/repos`.
- The main checkout of each worktree under `<sfy_home>/work`.
- `<sfy_home>/work` itself.

`lagom-trust add <repo>` marks one repo. For a worktree it marks the main checkout. The [README](../README.md#folder-trust) lists the commands, their output and their exit codes.

## Why an edit of the config file is safe enough

Claude Code itself writes `.claude.json` often, so a running session can write the file at the same time as `lagom-trust`. `lagom-trust` keeps the risk small in three ways:

1. It writes a temporary file next to the config and renames it over the config. A reader sees the old file or the new one, never a partial file.
2. It compares a checksum of the config before and after jq builds the new file. When the config changed in between, it starts again, up to five times.
3. It changes only `projects.<folder>.hasTrustDialogAccepted` and keeps every other key.

A gap remains between the checksum check and the rename. If Claude Code writes the config in that gap, one of the two writes is lost. A lost trust mark brings back the dialog, which is the state before `lagom-trust` ran. A lost Claude Code write loses one update, such as a startup count. The gap lasts one `cksum` call and one `mv` call. When nothing marks a new folder, `sync` and `add` do not write the file at all.

Trust is a security choice. A trusted folder can run hooks, MCP servers and settings from its `.claude` folder without a question. Run `sync` only for repos whose content you trust.

## What was tested

The docs facts above come from the Claude Code docs. The factory facts come from a check of a running factory outside the worker sandbox. The worker that wrote this page could not run a live dialog test, because its sandbox blocks the sockets that tmux and Rex need. The trust dialog screens in `test/fixtures/trust` are written by hand from the wording that Claude Code shows. Replace them with real captures when one is at hand.
