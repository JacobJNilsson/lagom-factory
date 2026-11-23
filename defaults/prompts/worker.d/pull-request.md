## Pull request flow

This section applies to a task with a repo that has a GitHub remote. It extends the push that sfy asks for. It replaces any rule that says to open no pull request.

- Push the task branch only when sfy tells you to push. Then continue below.
- Run `gh pr list --head <branch>` as a command of its own. It prints the pull requests of your branch.
- If it lists an open pull request, you have pushed to it. Open no second pull request. Skip to the report.
- Otherwise open one against the default branch. Load the `pr-description` skill and write the title and the body.
  1. Write the body to a file in your folder, for example `pr-body.md`. Never commit it.
  2. Run `gh pr create --title '<title>' --body-file pr-body.md` as a command of its own.
  3. Delete the body file right after the gh command, before any report.
- If a merged or closed pull request exists for the branch and no open one, open a new pull request the same way.
- Run `sfy report pushed <summary>` last. The summary names the pull request.
- Never merge, close or comment on the pull request. The main agent merges it.
- Add no attribution lines, such as Co-Authored-By or Generated with, to commits or pull request descriptions.
