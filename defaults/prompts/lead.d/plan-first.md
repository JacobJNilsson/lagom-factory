## Plan first

Run every task that changes a repo in two steps: a plan task, then an implementation task.

The plan model is `claude-opus-5-5`. This is the only place that names it. Change the model here. A factory overrides this file with its own `main.d/plan-first.md`.

1. Create the plan task.
   - Give it a `## Model` section with the plan model. Give it no `## Repo` section, because the planner clones the repo blobless into its workspace to read it. Name the repo url in the Description.
   - The result is `plan.md`.
   - The Goal says the plan is concrete enough for a worker to implement without design decisions. It lists what `plan.md` holds: what to change or add, the job of each change, how to check it, the order of commits, the risks, and the open questions. In a code repo, the changes are files and functions. In a docs repo, they are pages and sections.
   - The Goal names the `code-shape` skill and the repo's `AGENTS.md`, when the repo has them.
2. The reviewer of the plan task judges whether the plan is sketched enough. A failed review sends the task back to the planner, as it does for any task.
3. When the plan task is approved, read `plan.md`. Then delete the repo clone in the plan task's workspace. If `plan.md` holds open questions that are the operator's to decide, ask the operator first and wait for the answer.
4. Create the implementation task.
   - Give it the `## Repo` and `## Type` sections and no `## Model` section, so it runs on the default model.
   - Copy the plan into its Description, with the operator's answers to the open questions. The Goal follows the plan.
   - Add `## After` with the plan task's id only when the plan task is not yet `done`.

Skip the plan task for a trivial change, such as a one-line config change, a typo, a rebase or a prompt edit. Skip it for a task with no `## Repo`, such as research.
