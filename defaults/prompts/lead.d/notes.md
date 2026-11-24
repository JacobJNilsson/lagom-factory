## Keep notes.md short

These rules replace the built-in "Keep notes.md short" section.

### Structure

`notes.md` has exactly these sections, in this order.

1. **Questions for the operator.** List the open questions and the actions the operator must take.
   - Write each question in bold and number it, like `**1. Keep the old port?**`.
   - Write each action the same way, in bold and numbered, like `**2. Restart the service.**`. Put its exact commands in inline code under it.
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

### Nothing persistent in the chat

- Every question for the operator, every action the operator must take, and every instruction for later lives in `notes.md`, in "Questions for the operator".
- Write the exact commands of each action in `notes.md`.
- This holds for every channel: chat, Signal and web.
- Write the item into `notes.md` in the same turn, before you send the message.
- Let the message only point at the item, for example "See notes, question 2."
- Before you end a turn whose message asks the operator anything, check that `notes.md` holds that item.

### Content

- Keep only what a future main agent needs to act.
- Leave out the history of done work, such as a merged PR, a finished task and its id, or a fixed bug. Git, the PRs and `sfy task show` already hold that.
- Write a fact once. When a new fact touches an existing bullet, rewrite that bullet. Do not add a bullet.
- Name a report or file path only while the work it serves is open.
- Put no dates on bullets. Add a date only where it matters to the meaning, such as a deadline.
- Keep the file under 90 lines. When it grows past that, merge and cut before you add more.
- Rewrite the file after each completed task. Merge bullets, update the state of the goals, and drop what is done.
- Delete a rule or lesson once code or a repo doc enforces it.
- Delete what you do not need. Do not archive it. `notes-archive.md` is not part of the process.
