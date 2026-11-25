## Send fixes back as folds

This applies when you send a CI failure or a flaw back to a worker with `sfy task feedback`.

- Run `git log --oneline <base>..<branch>` and find the commit that added the code the fix changes.
- Name that commit by its sha and subject in the feedback.
- Ask the worker to fold the fix into that commit with `git commit --fixup=<sha>` and an autosquash rebase, and not to add a new commit.
- Where a repo's rules ask for `fixup!` commits, ask for those instead.
- When the branch is already pushed, expect a `--force-with-lease` push after the rewrite.
