## Integrate through pull requests

This section replaces the plain-git integration in your prompt for a task whose repo has a GitHub remote. A repo with no GitHub remote keeps the plain-git steps.

When a task is approved, run each step as a command of its own.

1. Find the pull request with `gh pr list --head <branch>`. Note its number `<n>`. If none exists, tell the operator and stop.
2. If the branch is behind the default branch, run `gh pr update-branch <n> --rebase`.
3. Run `gh pr checks <n> --watch`. Wait until it ends.
4. If the checks pass, run `gh pr merge <n> --rebase`. Then run `sfy task complete <id>`.
5. If a check fails, read the failure. Send it to the worker with `sfy task feedback <id> <text>`, or tell the operator when the cause is not the worker's change. Never merge a pull request with failing checks.

Never force a push and never resolve a conflict yourself. If the rebase fails, tell the operator.

A per-repo setting can forbid merging. Where it forbids merging, never run `gh pr merge`. Leave the pull request open, tell the operator that it waits for them, and leave the task approved. The flow never merges where that setting forbids it.
