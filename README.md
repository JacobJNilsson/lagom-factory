# lagom-factory

lagom-factory, short name lfy, is a software factory implementation on sfy ([simple-factory](https://github.com/JacobJNilsson/simple-factory)). It adds config, prompt additions and Rex templates. "Lagom" is Swedish for "just the right amount": more than simple, not complex. lfy is a name for prose, not a command. The license is MIT, see `LICENSE`.

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
5. Link the config and the Rex script into `~/.sfy` and `~/.local/bin`: run `./install.sh` in the clone. Running it twice changes nothing.
6. Install the factory itself. sfy reads prompt additions only from the factory's own state folder, so each factory needs this step. The factory name is the lower-case base name of the folder where you will run `sfy up`. This example uses `my-factory`.

   ```sh
   mkdir -p ~/lfy-factories/my-factory
   ./install.sh --factory my-factory --factories ~/lfy-factories
   ```

   With tmux, run `printf 'multiplexer = "tmux"\n' > ~/lfy-factories/my-factory/config.toml` between the two commands. See [No Rex? Use tmux](#no-rex-use-tmux).

### Start your first factory

A factory belongs to a folder. Make the folder and start sfy there. With tmux, run `tmux` first and start sfy inside it.

```sh
mkdir ~/my-factory
cd ~/my-factory
sfy up
```

sfy keeps the factory state in `~/.sfy/factories/my-factory/` and writes nothing into your folder. [Install a factory](#install-a-factory) explains the factory folder in full.

### What to expect

- The main agent starts in your terminal as a Claude Code session. Describe what you want built. It writes task files and starts workers.
- Each worker works in its own git worktree. A fresh reviewer checks each result.
- A worker or reviewer may stop at Claude Code's trust dialog the first time. Attach to its session and accept it.
- With Rex, `notes.md` and `status.md` open in panes beside the main agent. Workers and reviewers appear as windows in the Rex session of the factory, named `<prefix>agents`. See [Sessions in Rex](#sessions-in-rex). A name without a prefix goes to `sfy-agents`.
- With tmux, no panes open. Run `sfy status` for the task list. Run `tmux ls` to list the agent sessions, and `tmux attach -t worker-<id>` to watch one.
- Run `sfy down` from a terminal outside the agent sessions to stop everything. Run `sfy up` in the same folder to start again.

### No Rex? Use tmux

sfy ships a tmux template set, so no template in this repo is needed. lagom-factory sets `multiplexer = "rex"` in `config.toml`. A factory's own `config.toml` overrides that key, because sfy loads it on top of `~/.sfy/config.toml` key by key. Put the override in the factory folder before you install it (step 6):

```sh
mkdir -p ~/lfy-factories/my-factory
printf 'multiplexer = "tmux"\n' > ~/lfy-factories/my-factory/config.toml
./install.sh --factory my-factory --factories ~/lfy-factories
```

Run `sfy up` inside a tmux pane. sfy then makes that pane the main agent. Outside tmux, sfy starts the main agent in a new tmux session, and `tmux ls` shows its name.

What the tmux path loses, because these features call Rex through `bin/sfy-rex`:

- The `notes.md` and `status.md` panes. The tmux set has no `show_main` template. Open both files from `~/.sfy/factories/<name>/` in any viewer, or run `sfy status`.
- One shared Rex session for the workers and reviewers of a factory. Each worker and reviewer gets its own tmux session.

Everything else works the same: prompts, branch names, the pull request flow, plan first, and the writing rules.

## Layout

- `config.toml` holds sfy's settings and the multiplexer template set. sfy reads it from `~/.sfy/config.toml`.
- `prompts/<kind>.d/*.md` holds prompt additions. sfy appends them to the prompt of each agent kind (`main`, `worker`, `reviewer`, `worker-repo`). sfy reads them from `~/.sfy/prompts/<kind>.d`. `prompts/shared/*.md` holds text that several kinds share.
- `install.sh` links these files into `~/.sfy`. `install.sh --factory <name>` installs a factory set into `~/.sfy/factories/<name>/`.
- `test/fixtures/factories/` holds the factories that the tests install.

## Defaults

Each default below works out of the box. The table says how a factory overrides it.

| Default | Where | Override |
| --- | --- | --- |
| `max_workers = 4` | `config.toml` | `max_workers` in the factory's `config.toml` |
| Rex as multiplexer | `config.toml`, `bin/sfy-rex` | `multiplexer` and the templates in the factory's `config.toml` |
| Plan model `claude-opus-5-5` | `prompts/main.d/plan-first.md` | the factory's `main.d/plan-first.md` |
| Branch names | `prompts/main.d/branch-type.md`, `prompts/worker.d/branch-names.md` | the factory's files of the same names |
| Notes rules | `prompts/main.d/notes.md` | the factory's `main.d/notes.md` |
| Writing rules | `prompts/shared/writing.md` | the factory's `worker.d/writing.md` and `reviewer.d/writing.md` |
| Go tools | `TOOLS` in `machine/install.sh` | `machine/install.sh --no-tools`, then your own installs |
| Skills from agent-workflow | `machine/install.sh` | `--skills-repo DIR` or `SKILLS_REPO`, or `--no-skills` |

The writing rules need the `technical-writing` and `unslop` skills from agent-workflow.

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

## Notifications

Only the main agent pings the operator. `config.toml` sets `preferredNotifChannel = "notifications_disabled"` in `[session_settings.worker]` and `[session_settings.reviewer]`, because each wait of a worker or reviewer would otherwise send a desktop notification. sfy writes these keys into the settings file of each session of that kind (sfy 0.1.11 or later). The `main` table has no notification key, so the main agent keeps its notifications.

## Attribution

Claude Code adds a `Co-Authored-By` trailer to commits and a `Generated with Claude Code` line to pull request descriptions. `config.toml` sets `includeCoAuthoredBy = false` in `[session_settings.main]`, `[session_settings.worker]` and `[session_settings.reviewer]`. That setting turns off both the trailer and the line. It is the older flat key. The newer `attribution` setting is a nested table, and the sfy config loader accepts only flat keys in these tables. The worker pull request rules also tell workers to add no attribution lines.

## Sessions in Rex

The config works on macOS and Linux. Each template is one line that calls `bin/sfy-rex`, which holds all the Rex logic. The templates call it by `$HOME/.local/bin/sfy-rex`, because the sfy process may have a minimal `PATH`. `install.sh` links the script there. The script finds the Rex CLI with `command -v rex`, so a `rex` on the `PATH` wins (`/usr/local/bin/rex` on Linux). When the `PATH` has none, it uses the binary inside the Rex app bundle under `$HOME/Library/Application Support`. If neither exists, it prints `sfy-rex: rex not found; install it or add it to PATH` and exits 127. Run `make test` to run every test in `test/`.

Each state folder gets its own Rex session for its workers and reviewers. Its name is `<prefix>agents`, where `<prefix>` is everything before `worker-` or `review-` in the agent name. For example, `work-worker-t3` goes to `work-agents`. A name without a prefix goes to `sfy-agents`. Each agent is a window named after the agent, for example `worker-t48` or `review-t48-2`.

- `start` creates the agents session if it is missing, then opens the window with `rex window new --keep-open --focus=false`. A new session holds one placeholder window that runs `tail -f /dev/null`, so the session stays after the last worker window closes. `--focus=false` keeps the operator's view where it is when a worker starts.
- Workers that start at once can not both create the session. `start` takes a lock file, `$TMPDIR/<session>-start.lock`, around the check and the create, and releases it before it opens the window. The shell creates the file with noclobber (`set -C`), so only one start wins. Each session has its own lock, so one factory's start never waits for another's. The lock is not `mkdir`, because two concurrent `mkdir` calls on one path both succeeded on the CI runner. A start that waits more than 10 seconds goes on without the lock, so a lock left by a killed start does not block workers. `sh test/start-race.sh` tests this.
- `send`, `alive` and `stop` address the window with `-s <session> -w <name>`. `stop` closes the window, also when its process has ended.
- Worker windows start with `--keep-open`. When the command exits, the window stays open and shows the last output, so an error at start stays readable. `alive` reports the agent as gone. Rex answers `rex block call ... process` with a `child` object for a live window, and with a `last_exit` object and no `child` for a dead one. A missing window answers "not found". `alive` exits 0 for a live child, 1 for a dead or missing window, and 2 for any other reply. `stop` is the only thing that removes the window. The saved replies are in `test/process-*`.
- The main agent and the sfy process keep their own sessions, started with `--keep-open`. The templates recognize them by the name `main` or `sfy`, or the same with a prefix such as `work-main`. `send`, `alive` and `stop` also treat a name that starts with `session:` as a session. That is the address `whoami` prints for the main agent, and sfy passes it back as the name.
- There is no `show` template. Folding one shared session with `session.collapse` would hide every window, so the session stays as Rex shows it.

### Main agent layout

`show_main` opens two panes beside the main agent. `notes.md` goes to the right and `status.md` goes above. Both files come from the running factory's state folder, for example `~/.sfy/factories/app`. `config.toml` passes it as `show-main {home}`, and `SFY_HOME`, which sfy sets for every template command, is the second source. With neither, `show-main` prints an error and exits 1 instead of falling back to `~/.sfy`, so two factories at once each show their own files. Each pane runs `~/.local/bin/mdwatch` on the file when it exists, and focus stays on the main agent. `bin/mdwatch` renders the file with `glow` into a temp file and shows it in `less`, so the view starts at the top. When the modification time, the size or the pane width changes, a watcher ends `less` with `pkill -P` and the script renders again. It works with GNU and BSD `stat` and `pkill`, and it renders with `cat` when `glow` is missing. Links show only their text. `glow` prints every URL after the link text, so `mdwatch` first rewrites reference links and inline links into their text between two zero-width markers and drops the definition lines. Code spans, fenced code and images stay as they are. After `glow` runs, each marker pair becomes an OSC 8 hyperlink to the URL, so the text is clickable and the URL stays hidden. The markers have zero width, so a long URL never changes where `glow` wraps a line. A link that wraps closes at the end of its line and opens again on the next. Bare URLs in the text stay as they are. The terminal must support OSC 8, and `less` 581 or newer passes it through with `-R`. `install.sh` links it into `~/.local/bin`, and `machine/install.sh` installs `glow`. Without mdwatch, each pane runs `sh -c 'while :; do clear; cat "$1"; sleep 2; done' sh FILE`, which redraws the file every 2 seconds. The labels and the check against a second pair of panes stay the same.

- The template splits `$REX_BLOCK`, or the session's focused block when `$REX_BLOCK` is unset. It does nothing when neither `$REX_BLOCK` nor `$REX_SESSION` is set.
- The state folder is the `{home}` argument, then `$SFY_HOME`. With neither, `show-main` prints an error and exits 1, with no `~/.sfy` fallback.
- Each pane gets a label, `sfy-notes` and `sfy-status`, through `rex split --label`. Before it splits, the template runs `rex block ls` with the same scope as the split (`-b "$REX_BLOCK"`, or `-s "$REX_SESSION"` when only the session is set) and `--json`, and searches the output for each label with `case`. A pane that already has its label is not opened again, so a second run adds nothing. If `block ls` fails, the template exits non-zero and opens no panes, so a failed check never duplicates them. The template does not use jq.

Run `sh test/show_main.sh` to test this against a fake `rex` and `test/block-ls.json`, a reply from `rex block ls -s sfy-main --json` (rex 0.1.0 beta) with the ids replaced.

Run `sh test/names.sh` to test the name branching, the `alive` exit codes and the Rex lookup. It calls `bin/sfy-rex` directly with a fake `rex` on the `PATH` and checks the calls for `main`, `sfy`, prefixed names and workers.

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
3. Restart sfy.

The links use absolute paths. After a move of the clone, run `./install.sh` and `./install.sh --factory <name>` again for each factory.

`install.sh` links `config.toml`, `bin/mdwatch` into `~/.local/bin`, and each file of `prompts/<kind>.d` into a real folder `~/.sfy/prompts/<kind>.d` with `ln -s`. It also links `prompts/shared/*.md` into the worker and reviewer folders. An older install that linked the whole folder moves to `<folder>.bak`. If a target exists and is not the right link, the script moves it to `<target>.bak` and says so. The script takes an optional first argument, a home folder to install into. It defaults to `$HOME`. Running the script twice changes nothing the second time.

## Install a factory

sfy reads prompt additions only from a factory's own state folder. Only `config.toml` falls back to `~/.sfy`. So each factory needs its own install. Keep factory folders in a separate repo, so a fork or a pull of this repo never holds them.

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

For a fresh macOS or Linux machine, follow the ordered checklist in [docs/new-machine.md](docs/new-machine.md). Run `machine/install.sh --check` to list what is missing. Add `--multiplexer tmux` if you use tmux and not Rex. On macOS the check skips the Linux sandbox items.

`machine/install.sh` sets up a machine for sfy workers and reviewers. It installs Go tools and links skills.

### What it installs

- Eleven Go tools with `go install`: antislop, godebt, gofumpt, goimports, golines, gopls, staticcheck, mermaid-ascii, trim, glow (the renderer for `mdwatch`) and golangci-lint. The `TOOLS` list at the top of the script holds the versions. An upgrade is a one-line change.
- Skills from [agent-workflow](https://github.com/JacobJNilsson/agent-workflow). This repo holds factory setup only. Skills hold preferences about code and review, so they live in the `skills/` folder of agent-workflow. The script links each skill folder of a checkout into `~/.claude/skills/<name>` and links `git-why` into `~/.local/bin`. It leaves other entries in `~/.claude/skills/` alone, and it replaces a link that points into the old `machine/skills/` folder.
- Rules for sfy agents in `prompts/worker.d/github.md`, `prompts/reviewer.d/github.md` and `prompts/shared/writing.md`. The root `install.sh` links them into `~/.sfy/prompts`, so only sfy agents get them. They forbid comments on PRs and issues, forbid PR state changes outside the pull request flow, and require the technical-writing and unslop skills for all lasting text.

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
