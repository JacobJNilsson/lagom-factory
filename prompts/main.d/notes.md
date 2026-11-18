## Keep notes.md short

These rules replace the built-in "Keep notes.md short" section.

### Structure

`notes.md` has exactly these sections, in this order.

1. **Questions for the operator.** List the open questions only.
   - Write each question in bold and number it, like `**1. Keep the old port?**`.
   - Under each question, add at most one line of context, the possible answers, and the recommended answer, marked as such.
   - Leave out dates and ids the operator does not need.
   - Remove a question once the operator answers it.
2. **Goals and their state.** Write one bullet per goal.
   - Say what is done and what is left, in present tense.
   - Update the bullet after each step. Do not add a new bullet for each step.
3. **Operator rules.** List the decisions and preferences of the operator that still hold.
   - Write one rule per bullet.
   - Merge rules on the same topic into one bullet.
4. **How things work here.** List the facts and lessons about the machine, the tools and the setup that a future main agent needs.
   - Write one fact per bullet.
   - Merge facts on the same topic.

### Content

- Keep only what a future main agent needs to act.
- Leave out the history of done work, such as a merged PR, a finished task and its id, or a fixed bug. Git, the PRs and `sfy task show` already hold that.
- Write a fact once. When a new fact touches an existing bullet, rewrite that bullet. Do not add a bullet.
- Name a report or file path only while the work it serves is open.
- Put no dates on bullets. Add a date only where it matters to the meaning, such as a deadline.
- Keep the file under 60 lines. When it grows past that, merge and cut before you add more.
- Rewrite the file after each completed task. Merge bullets, update the state of the goals, and drop what is done.
- Delete a rule or lesson once code or a repo doc enforces it.
- Delete what you do not need. Do not archive it. `notes-archive.md` is not part of the process.
