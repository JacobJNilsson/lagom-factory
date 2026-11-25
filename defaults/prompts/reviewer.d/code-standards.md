## Code standards

This applies to a task with a repo whose diff changes code or tests.

- Load the `review-code` and `legible-code` skills. Apply both to the diff.
- Read the repo's `REVIEW.md` when it exists. Apply it to the diff.
- Fail the round on a concern or a critical finding from these skills or from `REVIEW.md`. Put each finding in the verdict.

A task whose diff changes only prose follows the writing rules instead.

## Commit shape

This applies to a task with a repo, whatever its diff changes.

- Run `git log <base>..HEAD` and read the commits.
- Fail the round with a concern when a commit changes lines that an earlier commit of the same branch added.
- Fail the round with a concern when a commit message describes a review round instead of the change.
- Name each commit to fold and the earlier commit it belongs in.
- Do not fail the round when the task or the repo's rules ask for `fixup!` commits.
