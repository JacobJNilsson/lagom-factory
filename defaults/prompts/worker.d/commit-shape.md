## Commit shape

This applies to a task with a repo. Each commit of the branch holds one logical change in its final form. Its message describes that final form, not the review rounds.

- Review feedback, a failed check or a CI failure can ask for a change to code that an earlier commit of the branch added. Put that change into that commit. Never stack a fix commit on top.
- Fold it in two steps. Run `git commit --fixup=<sha>`. Then run `GIT_SEQUENCE_EDITOR=true git rebase --autosquash -i <base>`.
- Reword the message of the folded commit when the change no longer matches it.
- Before `sfy report done`, run `git log --oneline <base>..HEAD`. Fold any commit that changes lines an earlier commit of the branch added.
- A repo's own rule wins where it differs. In a comment task, once a human review has started, add `fixup!` commits instead, as the repo's rules say.
- After you rewrite commits that are already pushed, push with `--force-with-lease` as sfy's push note allows. Never force a push without a lease.
