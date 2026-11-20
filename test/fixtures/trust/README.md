# Trust dialog screens

`test/trust.sh` runs the detector of `bin/lagom-trust` on these screens. Each file is the text of one agent pane.

- `dialog.txt` shows the newer wording, which starts with "Accessing workspace:".
- `dialog-old.txt` shows the older wording, "Do you trust the files in this folder?". Its folder holds a space.
- `dialog-cursor-no.txt` shows the dialog with the cursor on "No, exit".
- `prompt.txt` shows a session after the dialog, at the input prompt.

The screens are written by hand from the wording that Claude Code versions show. No live pane was captured for them, because the worker sandbox cannot run a terminal multiplexer. Replace them with real captures from `rex capture --unwrap --trim` or `tmux capture-pane -p -J` when one is at hand.
