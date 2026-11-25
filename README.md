# lagom-factory

lagom-factory, short name lfy, is a software factory implementation on sfy ([simple-factory](https://github.com/JacobJNilsson/simple-factory)). It adds config, prompt additions and Rex templates. "Lagom" is Swedish for "just the right amount": more than simple, not complex. `lfy` is also the command that starts a lagom factory. It works like `sfy` and loads the lagom defaults. The license is MIT, see `LICENSE`.

## Getting started

lagom-factory turns sfy into a working software factory. You talk to one main agent, and it hands tasks to workers and reviewers that run in terminal panes. This section takes you from a clean macOS or Linux machine to a running factory.

### Prerequisites

- [Claude Code](https://docs.claude.com/en/docs/claude-code/overview), logged in. Run `claude` once and sign in.
- [git](https://git-scm.com/downloads) and the [GitHub CLI `gh`](https://cli.github.com/). The pull request flow needs `gh`.
- [Go](https://go.dev/dl/), to build the helper tools.
- [sfy](https://github.com/JacobJNilsson/simple-factory), the core that lagom-factory configures.
- A terminal tool, either Rex, a terminal app that you install on its own, or [tmux](https://github.com/tmux/tmux/wiki/Installing). lagom-factory uses Rex by default. Without Rex, use tmux (see [No Rex? Use tmux](#no-rex-use-tmux)).
- On Linux only: `bubblewrap` and `socat` for the Claude Code sandbox. Ubuntu 24.04 and later also need an AppArmor profile. macOS needs neither.
- The skills from [agent-workflow](https://github.com/JacobJNilsson/agent-workflow). `machine/install.sh` clones and links them for you.

Steps 1 to 4 below cover all of these. [docs/new-machine.md](docs/new-machine.md) lists each command in full.

### Install steps

Do these steps in order.

1. Install git, `gh`, Go, Claude Code, and Rex or tmux. On Linux, also install `bubblewrap` and `socat` and load the AppArmor profile. Follow [docs/new-machine.md](docs/new-machine.md) for your system.
2. Install sfy. On macOS run `brew install jacobjnilsson/tap/sfy`. On Linux download the release tarball, as [docs/new-machine.md](docs/new-machine.md) describes.
3. Set a git identity with `git config --global`, then run `gh auth login` and `gh auth refresh -h github.com -s workflow`.
4. Clone this repo and install the tools and skills. Add `--multiplexer tmux` to the check if you use tmux.

   ```sh
   git clone https://github.com/JacobJNilsson/lagom-factory.git
   cd lagom-factory
   machine/install.sh --clone-skills
   machine/install.sh --check
   ```

   `--check` lists everything that is still missing, each with its fix. Repeat until it prints `ok: nothing is missing`. Add `~/go/bin` and `~/.local/bin` to your `PATH` if the script says so.
5. Link `lfy` and the other scripts into `~/.local/bin`, and the Rex templates into `~/.sfy/config.d`: run `./install.sh` in the clone. Running it twice changes nothing.

### Start your first factory

A factory belongs to a folder. Make the folder and start lfy there. With tmux, run `tmux` first and start lfy inside it.

```sh
mkdir ~/my-factory
cd ~/my-factory
lfy
```

lfy creates the factory folder `~/.sfy/factories/lfy-my-factory/`, links the lagom defaults from `defaults/` into it, and passes the command to sfy. It writes nothing into your folder. Every other command works the same way: `lfy status`, `lfy down`, `lfy restart`. The name prefix `lfy-` keeps a factory that you start with `sfy` in the same folder apart from the lagom factory.

A `git pull` in the clone updates the defaults of every lfy factory. Run `lfy restart` to apply them, or after a move of the clone. `sfy restart --update` updates sfy only. lfy needs sfy 0.3.0 or later.

### What to expect

- The main agent starts in your terminal as a Claude Code session. Describe what you want built. It writes task files and starts workers.
- Each worker works in its own git worktree. A fresh reviewer checks each result.
- A worker or reviewer stops at Claude Code's trust dialog the first time a task uses a new repo. Run `lagom-trust pending` to list the waiting agents. Accept one with `lagom-trust accept`, or attach to its session. To skip the dialog, run `lagom-trust sync` before you start tasks for a new repo. See [Folder trust](#folder-trust).
- With Rex, `notes.md` and `status.md` open in panes beside the main agent. Workers and reviewers appear as windows in the Rex session of the factory, named `<prefix>agents`. See [Sessions in Rex](#sessions-in-rex). A name without a prefix goes to `sfy-agents`.
- With tmux, no panes open. Run `sfy status` for the task list. Run `tmux ls` to list the agent sessions, and `tmux attach -t worker-<id>` to watch one.
- Run `sfy down` from a terminal outside the agent sessions to stop everything. Run `sfy up` in the same folder to start again.

### No Rex? Use tmux

sfy ships a tmux template set, so no template in this repo is needed. `install.sh` links `machine/rex.toml` into `~/.sfy/config.d`, and that file sets `multiplexer = "rex"`. A key in `~/.sfy/config.toml` wins over the files of `config.d`. Put the override there:

```sh
printf 'multiplexer = "tmux"\n' > ~/.sfy/config.toml
```

Run `lfy` inside a tmux pane. sfy then makes that pane the main agent. Outside tmux, sfy starts the main agent in a new tmux session, and `tmux ls` shows its name.

What the tmux path loses, because these features call Rex through `bin/sfy-rex`:

- The `notes.md` and `status.md` panes. The tmux set has no `show_lead` template. Open both files from `~/.sfy/factories/<name>/` in any viewer, or run `sfy status`.
- One shared Rex session for the workers and reviewers of a factory. Each worker and reviewer gets its own tmux session.

Everything else works the same: prompts, branch names, the pull request flow, plan first, and the writing rules.

## Layout

- `defaults/` holds the lagom defaults in the shape of an sfy factory definition. `defaults/config.toml` holds sfy's settings. `defaults/prompts/<kind>.d/*.md` holds prompt additions, which sfy appends to the prompt of each agent kind (`lead`, `worker`, `reviewer`, `worker-repo`). `defaults/prompts/shared/*.md` holds text that several kinds share, and `worker.d` and `reviewer.d` reach it through links. lfy links each entry of `defaults/` into the factory folder.
- `machine/rex.toml` holds the Rex multiplexer templates. They are machine settings, so `install.sh` links the file into `~/.sfy/config.d/50-lagom-rex.toml`.
- `bin/lfy` is the command that starts a lagom factory.
- `config.toml` and `prompts/` stay for installs that use `install.sh --factory`. They hold the old layout and link into `defaults/`. They go when the migration to lfy ends.
- `test/fixtures/factories/` holds the factories that the tests install.

## Defaults

Each default below works out of the box. The table says how to override it. Override a default in the `.sfy/` folder of your working folder, such as `~/work/.sfy/`. It has the shape of a factory definition: `config.toml`, `config.d/`, `prompts/<kind>.d/` and `skills/`. The nearest `.sfy/` folder wins key by key. [simple-factory](https://github.com/JacobJNilsson/simple-factory) documents how prompt files and skills from several folders combine.

| Default | Where | Override |
| --- | --- | --- |
| `max_workers = 4` | `defaults/config.toml` | `max_workers` in `.sfy/config.toml` |
| Code Mode for the lead: `env = { CLAUDE_CODE_EXPERIMENTAL_CODE_MODE = "1" }` in `[session_settings.lead]` | `defaults/config.toml` | `env` in `[session_settings.lead]` of `.sfy/config.toml` |
| Rex as multiplexer | `machine/rex.toml`, `bin/sfy-rex` | `multiplexer` in `~/.sfy/config.toml` |
| Plan model `claude-opus-5-5` | `defaults/prompts/lead.d/plan-first.md` | `.sfy/prompts/lead.d/plan-first.md` |
| Branch names | `defaults/prompts/lead.d/branch-type.md`, `defaults/prompts/worker.d/branch-names.md` | the files of the same names in `.sfy/prompts/` |
| Notes rules | `defaults/prompts/lead.d/notes.md` | `.sfy/prompts/lead.d/notes.md` |
| Writing rules | `defaults/prompts/shared/writing.md` | `.sfy/prompts/worker.d/writing.md` and `reviewer.d/writing.md` |
| Go tools | `TOOLS` in `machine/install.sh` | `machine/install.sh --no-tools`, then your own installs |
| Skills from agent-workflow | `machine/install.sh` | `--skills-repo DIR` or `SKILLS_REPO`, or `--no-skills` |

The writing rules need the `technical-writing` and `unslop` skills from agent-workflow.

### Override a default in the working folder

A factory for `~/work/web` reads the lagom defaults, then `~/.sfy`, then `~/work/.sfy/` and `~/work/web/.sfy/`. To allow six workers in every factory under `~/work`, and four in `~/work/web`:

```sh
mkdir -p ~/work/.sfy ~/work/web/.sfy
printf 'max_workers = 6\n' > ~/work/.sfy/config.toml
printf 'max_workers = 4\n' > ~/work/web/.sfy/config.toml
lfy restart
```

Run `lfy config` to see which file each setting comes from. sfy skips a `.sfy/` folder that you do not own or that others can write, and `lfy config` names it.

### Branch names

Name a branch `<type>/<slug>`.

- `<type>` is one Conventional Commits type: feat, fix, docs, chore, refactor, test, perf, ci or build.
- `<slug>` is a short summary of the change in lower case, with words joined by `-`, in about 50 characters or fewer.
- Never reuse a name that exists locally or on the remote. Add `-2`, `-3` and so on instead.
- Examples: `feat/add-export-command`, `fix/reject-empty-config-file`, `docs/new-machine-install`.

Two prompt additions apply the rule. `prompts/main.d/branch-type.md` tells the main agent to put a `## Type` section in each task file, so sfy can name the task branch. `prompts/worker.d/branch-names.md` repeats the rule for branches a worker creates itself. Workers cannot read this README, so the worker file holds its own copy. Change all three together.

## Pull request flow

sfy pushes the task branch and integrates it with plain git by default. Two prompt additions add pull requests on GitHub with `gh` for repos with a GitHub remote.

- `prompts/worker.d/pull-request.md`: after the push that sfy asks for, the worker opens a pull request against the default branch with `gh pr create --title '<title>' --body-file <file>`. It writes the body with the `pr-description` skill, never commits the file and deletes it right after. If the pull request is open, the worker only pushes to it. Then it reports pushed.
- `prompts/main.d/pull-request.md`: for an approved task, the main agent finds the pull request with `gh pr list --head <branch>`, runs `gh pr update-branch <n> --rebase` when the branch is behind, and waits with `gh pr checks <n> --watch`. It merges with `gh pr merge <n> --rebase` only when the checks pass, then runs `sfy task complete <id>`. A failed check goes to the worker with `sfy task feedback`, or to the operator. The flow never merges where a per-repo no-merge setting forbids it. A repo with no GitHub remote keeps sfy's plain-git default.

The GitHub rules sit in `prompts/worker.d/github.md` and `prompts/reviewer.d/github.md`. Both forbid comments, replies and reviews on PRs and issues. Only the worker file lets the flow change a PR. The writing rules live once in `prompts/shared/writing.md`. `install.sh` links that file into the worker and reviewer folders, so each of those folders is a real folder of file links.

## Code standards in review

`prompts/reviewer.d/code-standards.md` applies to a task with a repo whose diff changes code or tests. It tells the reviewer to load the `review-code` and `legible-code` skills and apply them to the diff. It also tells the reviewer to read the repo's `REVIEW.md` when one exists. The reviewer fails the round on a concern or a critical finding from these, with the finding in the verdict. A task that changes only prose follows the writing rules instead. `install.sh` links the file into every factory's reviewer folder.

## Commit shape

Each commit of a branch holds one logical change in its final form. Three prompt files apply the rule.

- `prompts/worker.d/commit-shape.md`: the worker folds a review or CI fix into the commit it fixes, with `git commit --fixup=<sha>` and `GIT_SEQUENCE_EDITOR=true git rebase --autosquash -i <base>`. Before it reports done, it checks `git log --oneline <base>..HEAD`. A repo's own rule wins, such as `fixup!` commits in a comment task after a human review starts.
- `prompts/reviewer.d/code-standards.md`: the reviewer reads `git log <base>..HEAD`. It fails the round when a commit changes lines an earlier commit of the branch added, or when a message describes a review round. It names the commits to fold.
- `prompts/main.d/commit-shape.md`: when the lead sends a CI failure or a flaw back with `sfy task feedback`, it names the commit that the fix belongs in and asks the worker to fold it there.

## Notifications

Only the main agent pings the operator. `config.toml` sets `preferredNotifChannel = "notifications_disabled"` in `[session_settings.worker]` and `[session_settings.reviewer]`, because each wait of a worker or reviewer would otherwise send a desktop notification. sfy writes these keys into the settings file of each session of that kind (sfy 0.1.11 or later). The `main` table has no notification key, so the main agent keeps its notifications.

## Attribution

Claude Code adds a `Co-Authored-By` trailer to commits and a `Generated with Claude Code` line to pull request descriptions. `config.toml` sets `includeCoAuthoredBy = false` in `[session_settings.main]`, `[session_settings.worker]` and `[session_settings.reviewer]`. That setting turns off both the trailer and the line. It is the older flat key. The newer `attribution` setting is a nested table, and the sfy config loader accepts only flat keys in these tables. The worker pull request rules also tell workers to add no attribution lines.

## Sessions in Rex

The config works on macOS and Linux. Each template is one line that calls `bin/sfy-rex`, which holds all the Rex logic. The templates call it by `$HOME/.local/bin/sfy-rex`, because the sfy process may have a minimal `PATH`. `install.sh` links the script there. The script finds the Rex CLI with `command -v rex`, so a `rex` on the `PATH` wins (`/usr/local/bin/rex` on Linux). When the `PATH` has none, it uses the binary inside the Rex app bundle under `$HOME/Library/Application Support`. If neither exists, it prints `sfy-rex: rex not found; install it or add it to PATH` and exits 127. `sfy-rex which` prints the path it finds, and `machine/install.sh --check` uses it. Run `make test` to run every test in `test/`.

Each state folder gets its own Rex session for its workers and reviewers. Its name is `<prefix>agents`, where `<prefix>` is everything before `worker-` or `review-` in the agent name. For example, `work-worker-t3` goes to `work-agents`. A name without a prefix goes to `sfy-agents`. Each agent is a window named after the agent, for example `worker-t48` or `review-t48-2`.

- `start` creates the agents session if it is missing, then opens the window with `rex window new --keep-open --focus=false`. A new session holds one placeholder window that runs `tail -f /dev/null`, so the session stays after the last worker window closes. `--focus=false` keeps the operator's view where it is when a worker starts.
- Workers that start at once can not both create the session. `start` takes a lock file, `$TMPDIR/<session>-start.lock`, around the check and the create, and releases it before it opens the window. The shell creates the file with noclobber (`set -C`), so only one start wins. Each session has its own lock, so one factory's start never waits for another's. The lock is not `mkdir`, because two concurrent `mkdir` calls on one path both succeeded on the CI runner. A start that waits more than 10 seconds goes on without the lock, so a lock left by a killed start does not block workers. `sh test/start-race.sh` tests this.
- `send`, `alive` and `stop` address the window with `-s <session> -w <name>`. `stop` closes the window, also when its process has ended.
- Worker windows start with `--keep-open`. When the command exits, the window stays open and shows the last output, so an error at start stays readable. `alive` reports the agent as gone. Rex answers `rex block call ... process` with a `child` object for a live window, and with a `last_exit` object and no `child` for a dead one. A missing window answers "not found". `alive` exits 0 for a live child, 1 for a dead or missing window, and 2 for any other reply. `stop` is the only thing that removes the window. The saved replies are in `test/process-*`.
- The main agent and the sfy process keep their own sessions, started with `--keep-open`. The templates recognize them by the name `main` or `sfy`, or the same with a prefix such as `work-main`. `send`, `alive` and `stop` also treat a name that starts with `session:` as a session. That is the address `whoami` prints for the main agent, and sfy passes it back as the name.
- There is no `show` template. Folding one shared session with `session.collapse` would hide every window, so the session stays as Rex shows it.

### Main agent layout

`show_lead` opens two panes beside the main agent. `notes.md` goes to the right and `status.md` goes above. Both files come from the running factory's state folder, for example `~/.sfy/factories/app`. `machine/rex.toml` passes it as `show-main {home}`, and `SFY_HOME`, which sfy sets for every template command, is the second source. With neither, `show-main` prints an error and exits 1 instead of falling back to `~/.sfy`, so two factories at once each show their own files. Each pane runs `~/.local/bin/mdwatch` on the file when it exists, and focus stays on the main agent. `bin/mdwatch` renders the file with `glow` into a temp file and shows it in `less`, so the view starts at the top. When the modification time, the size or the pane width changes, a watcher ends `less` with `pkill -P` and the script renders again. It works with GNU and BSD `stat` and `pkill`, and it renders with `cat` when `glow` is missing. Links show only their text. `glow` prints every URL after the link text, so `mdwatch` first rewrites reference links and inline links into their text between two zero-width markers and drops the definition lines. Code spans, fenced code and images stay as they are. After `glow` runs, each marker pair becomes an OSC 8 hyperlink to the URL, so the text is clickable and the URL stays hidden. The markers have zero width, so a long URL never changes where `glow` wraps a line. A link that wraps closes at the end of its line and opens again on the next. Bare URLs in the text stay as they are. `mdwatch --render FILE` prints one render to stdout, and the tests use it. The terminal must support OSC 8, and `less` 581 or newer passes it through with `-R`. `install.sh` links it into `~/.local/bin`, and `machine/install.sh` installs `glow`. Without mdwatch, each pane runs `sh -c 'while :; do clear; cat "$1"; sleep 2; done' sh FILE`, which redraws the file every 2 seconds. The labels and the check against a second pair of panes stay the same.

- The template splits `$REX_BLOCK`, or the session's focused block when `$REX_BLOCK` is unset. It does nothing when neither `$REX_BLOCK` nor `$REX_SESSION` is set.
- The state folder is the `{home}` argument, then `$SFY_HOME`. With neither, `show-main` prints an error and exits 1, with no `~/.sfy` fallback.
- Each pane gets a label, `sfy-notes` and `sfy-status`, through `rex split --label`. Before it splits, the template runs `rex block ls` with the same scope as the split (`-b "$REX_BLOCK"`, or `-s "$REX_SESSION"` when only the session is set) and `--json`, and searches the output for each label with `case`. A pane that already has its label is not opened again, so a second run adds nothing. If `block ls` fails, the template exits non-zero and opens no panes, so a failed check never duplicates them. The template does not use jq.

Run `sh test/show_main.sh` to test this against a fake `rex` and `test/block-ls.json`, a reply from `rex block ls -s sfy-main --json` (rex 0.1.0 beta) with the ids replaced.

Run `sh test/names.sh` to test the name branching, the `alive` exit codes and the Rex lookup. It calls `bin/sfy-rex` directly with a fake `rex` on the `PATH` and checks the calls for `main`, `sfy`, prefixed names and workers.

## Folder trust

Claude Code shows a trust dialog the first time it runs in a folder it has not seen. A worker or reviewer waits at that dialog until someone accepts it. In a factory it appears once for each new repo, because Claude Code keys trust on the repo's main checkout and every worktree shares it. [docs/claude-trust.md](docs/claude-trust.md) explains the rules and which folders prompt.

`bin/lagom-trust` handles the dialog for the factory in `SFY_HOME`. `install.sh` links it to `~/.local/bin/lagom-trust`. It has two parts: commands that mark folders as trusted before an agent starts, and commands that find and accept a dialog that already shows.

### Mark folders as trusted

Trust is a security choice. A trusted folder can run hooks, MCP servers and settings from its `.claude` folder without a question. Nothing in lagom-factory runs these commands for you. Run them only for repos whose content you trust.

- `lagom-trust sync [--config FILE]` marks every folder of the factory: the repo of each task in `<sfy_home>/tasks/*/task.md`, archived ones too, each git repo under `<sfy_home>/repos`, the main checkout of each worktree under `<sfy_home>/work`, and `<sfy_home>/work` itself. It skips a task's repo path that no longer exists, with a note on stderr.
- `lagom-trust add REPO [--config FILE]` marks one repo. For a worktree it marks the main checkout. For a folder outside git it marks the folder.

Both commands set `projects.<folder>.hasTrustDialogAccepted` to `true` in Claude Code's config file and keep every other key. The file is the `--config` value, then `$LAGOM_TRUST_CONFIG`, then `.claude.json` in `$CLAUDE_CONFIG_DIR` or `$HOME`. They write a temporary file next to it and rename it over the config. When the config changes while they work, they start again. A run that marks nothing new leaves the file as it was. They print `trusted: FOLDER` for each new mark and `ok: FOLDER is trusted` when nothing changed. They need `jq`. They exit 0 on success, 1 when the config is not valid JSON, cannot be written or keeps changing, or when `REPO` does not exist, and 64 on a usage error. `sync` also exits 64 when `SFY_HOME` is not set or not a folder.

### Accept a dialog that shows

A web UI or a script can call these two commands. Both find the agents of the factory from the folders in `<sfy_home>/sessions` and look only at names that hold `worker-` or `review-`. The main agent and the sfy process are left out, because their panes are the operator's own. Both read the multiplexer from `--multiplexer rex|tmux`, then `multiplexer` in `<sfy_home>/config.toml`, then in `~/.sfy/config.toml`, and default to `rex`.

With Rex, an agent's pane is the window named after the agent in the session `<prefix>agents`, the same rule as `bin/sfy-rex`. The commands capture it with `rex capture -s <session> -w <agent> --unwrap --trim`. With tmux, the pane is the active pane of the tmux session named after the agent, captured with `tmux capture-pane -p -J`.

The commands treat a pane as showing the dialog when its last 40 lines hold the dialog's question, then a folder line, then the cursor on option 1, "Yes". A dialog with the cursor on another option does not count.

`lagom-trust pending [--json] [--multiplexer rex|tmux]` lists each agent whose pane shows the dialog. It skips an agent whose pane is missing. The text output has one line per agent, the agent name and the folder with a tab between them. The `--json` output is one array on one line, empty when no agent waits:

```json
[{"agent":"worker-t3","folder":"/home/user/src/example-repo"}]
```

`pending` exits 0, also when no agent waits. It exits 64 on a usage error or a missing `SFY_HOME`, and 3 when it cannot find Rex.

`lagom-trust accept AGENT FOLDER [--multiplexer rex|tmux]` captures the agent's pane again. It sends one Enter to that pane only when the dialog still shows, names `FOLDER` exactly and has the cursor on "Yes". It sends no other input and touches no other pane. Pass the folder as `pending` printed it. It prints `accepted: AGENT FOLDER` on success. Each refusal prints a short reason on stderr. The exit codes:

| Code | Meaning |
| --- | --- |
| 0 | The dialog showed for `FOLDER`, and the command sent Enter. |
| 1 | Refused: the pane shows no dialog, the dialog names another folder, or the cursor is not on "Yes". |
| 2 | Refused: `AGENT` is not a worker or reviewer of this factory. |
| 3 | The multiplexer failed: the pane is missing, the capture failed, the key did not reach the pane, or Rex is not found. |
| 64 | Usage error, or `SFY_HOME` is not set or not a folder. |

`lagom-trust detect` reads a captured screen on stdin and prints the folder of its dialog. It exits 0 when a dialog shows and 1 when none does. The tests use it.

Run `sh test/trust.sh` to test the commands. It runs the detector on the screens in `test/fixtures/trust`, runs `pending` and `accept` against a fake `rex` and a fake `tmux`, and runs `sync` and `add` against a scratch config file. The screens are written by hand, because the worker that wrote them could not capture a live pane. The live dialog test has not run.

## Plan first

Every factory runs a task that changes a repo in two steps. `prompts/main.d/plan-first.md` tells the main agent how, and it names the plan model. That file is the one place to change the model.

1. A plan task with `## Model` set to the plan model and no `## Repo`. The planner clones the repo blobless, reads it and writes `plan.md`. The plan names what changes: files and functions in a code repo, pages and sections in a docs repo. It also holds the checks, the order of commits, the risks and the open questions. `prompts/worker.d/plan-tasks.md` holds the planner's rules. It writes `plan.md` only, changes nothing, pushes nothing and lists undecided points as open questions.
2. The reviewer judges whether the plan is sketched enough, with `prompts/reviewer.d/plan-tasks.md`. A failed review sends it back to the planner.
3. When the plan task is approved, the main agent reads `plan.md` and asks the operator about open questions that are the operator's to decide.
4. The main agent creates the implementation task with `## Repo`, `## Type`, no `## Model` and the plan in its Description.

The main agent skips the plan task for trivial changes (a one-line config change, a typo, a rebase, a prompt edit) and for tasks with no repo, such as research. The flow needs the `## Model` and `## After` task sections of simple-factory.

## Install

1. Clone this repo: `git clone https://github.com/JacobJNilsson/lagom-factory.git`.
2. Run `./install.sh`.
3. Run `lfy restart` in each lagom factory. To update later, run `git pull` in the clone, then `lfy restart`.

The links use absolute paths. After a move of the clone, run `./install.sh` again, then `lfy restart` in each lagom factory. For a factory from `install.sh --factory`, run `./install.sh --factory <name>` again.

`install.sh` links `bin/lfy`, `bin/mdwatch`, `bin/sfy-rex` and `bin/lagom-trust` into `~/.local/bin`, and `machine/rex.toml` into `~/.sfy/config.d/50-lagom-rex.toml`. It links no `config.toml` and no prompt file into `~/.sfy`, because lfy links `defaults/` into the factory folder. If a target exists and is not the right link, the script moves it to `<target>.bak` and says so. The script takes an optional first argument, a home folder to install into. It defaults to `$HOME`. Running the script twice changes nothing the second time.

## Install a factory

This section describes `install.sh --factory`, the older way to set up a factory. It stays until the migration to lfy ends. A new factory starts with `lfy` and needs no install.

sfy reads prompt additions only from a factory's own state folder. So each factory of this kind needs its own install. Keep factory folders in a separate repo, so a fork or a pull of this repo never holds them.

```sh
./install.sh --factory web --factories ~/lfy-factories
LFY_FACTORIES=~/lfy-factories ./install.sh --factory web
```

This installs into `~/.sfy/factories/web/`. Add a home folder as last argument to install elsewhere. The flag wins over the variable. The variable is ignored without `--factory`, so a plain `./install.sh` works when the variable is set in your profile. The links use the absolute path of the folder.

`install.sh` looks for `<name>` in this order: `DIR/<name>`, then `factories/<name>` in this repo. A user who adds a factory folder inside a clone still gets it.

The folder `DIR/<name>/` holds the set. It has two optional parts:

- `prompts/<kind>.d/*.md` is installed on top of the shared `prompts/` files. A file with the name of a base or shared file replaces it. Every other base file stays.
- `config.toml` is linked to `<state>/config.toml`. sfy reads `~/.sfy/config.toml` first and the factory file overrides it key by key, so it holds only what differs. The install does not touch `~/.sfy/config.toml` or `~/.sfy/prompts`. Run `./install.sh` too for the default factory and the Rex setup.

Run it once, then restart the factory. Running it twice changes nothing. `sh test/install-factory.sh` tests the install in a temporary home, against `test/fixtures/factories`.

## Set up a machine

For a fresh macOS or Linux machine, follow the ordered checklist in [docs/new-machine.md](docs/new-machine.md). Run `machine/install.sh --check` to list what is missing. Add `--multiplexer tmux` if you use tmux and not Rex. On macOS the check skips the Linux sandbox items. The check probes every tool in `TOOLS`.

`machine/install.sh` sets up a machine for sfy workers and reviewers. It installs Go tools and links skills.

### What it installs

- Eleven Go tools with `go install`: antislop, godebt, gofumpt, goimports, golines, gopls, staticcheck, mermaid-ascii, trim, glow (the renderer for `mdwatch`) and golangci-lint. The `TOOLS` list at the top of the script holds the versions. An upgrade is a one-line change.
- Skills from [agent-workflow](https://github.com/JacobJNilsson/agent-workflow). This repo holds factory setup only. Skills hold preferences about code and review, so they live in the `skills/` folder of agent-workflow. The script links each skill folder of a checkout into `~/.claude/skills/<name>` and links `git-why` into `~/.local/bin`. It leaves other entries in `~/.claude/skills/` alone, and it replaces a link that points into the old `machine/skills/` folder.
- Rules for sfy agents in `defaults/prompts/worker.d/github.md`, `defaults/prompts/reviewer.d/github.md` and `defaults/prompts/shared/writing.md`. lfy links `defaults/` into the factory folder, so only agents of a lagom factory get them. They forbid comments on PRs and issues, forbid PR state changes outside the pull request flow, and require the technical-writing and unslop skills for all lasting text.

### What it needs first

- Go, on `PATH`.
- git.
- `gh`, logged in with `gh auth login`. The pull request flow needs it.
- Claude Code, logged in.

### Run it

```sh
machine/install.sh
```

Then run the root `./install.sh` and restart sfy. Add the Go bin folder to `PATH` if the script says so.

Flags: `--check` installs nothing, prints each missing item with its fix, and exits 1 when anything is missing. `--multiplexer rex|tmux` picks which terminal tool `--check` looks for, and it defaults to `rex`. `--no-tools` skips `go install`. `--no-skills` skips the skill links. `--skills-repo DIR` names the agent-workflow checkout. The `SKILLS_REPO` env var does the same, and the default is `~/.local/share/agent-workflow`. When the checkout is missing, the script prints `git clone https://github.com/JacobJNilsson/agent-workflow.git DIR` and skips the skills. `--clone-skills` makes it run that clone instead. A folder argument installs into that home instead of `$HOME`, for example `machine/install.sh --no-tools /tmp/test-home`.

Running it twice is safe. `go install` is idempotent, and a skill link that already points at the right folder changes nothing. A different file at a skill path moves to `<path>.bak`.
