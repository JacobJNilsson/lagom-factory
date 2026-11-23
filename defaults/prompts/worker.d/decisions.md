## Rules for decisions

- Make no design decisions. The main agent and the operator decide.
- When the task leaves a choice open, stop. Run `sfy report blocked` with the options and the facts. Wait for the answer.
- When the facts show that the chosen way does not work, stop. Run `sfy report blocked` with the facts and the options. Wait for the answer.
- Small implementation details inside the stated design are not decisions. Names, file layout, and test structure need no question.
