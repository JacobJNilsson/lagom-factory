## Plan tasks

This applies to a task that asks for a plan as `plan.md`. It has no `## Repo` section.

- Clone the repo named in the task into your workspace with `git clone --filter=blob:none <url>`, or `gh repo clone <owner>/<repo> -- --filter=blob:none` for a GitHub repo. Read what the task changes and the repo's `AGENTS.md`, when it has one.
- When the repo holds code, load the `code-shape` skill before you write the plan.
- Write `plan.md` and nothing else. Change nothing in the repo. Commit nothing to the cloned repo. Push nothing.
- Phrase the plan by what the task changes. For code, name the files and functions, and each function's job. For a docs repo, name the pages and sections, and what each one says after the change. Add the checks, the order of commits, the risks, and the open questions. A worker must be able to implement the plan without design decisions.
- When the task leaves a decision open, never make it. List it under the open questions with the options and the facts.
- Leave the clone in your workspace. The lead removes it after the review.
