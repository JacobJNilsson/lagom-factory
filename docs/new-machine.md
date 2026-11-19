# New machine

This checklist sets up a fresh machine for sfy and lagom-factory. Pick your system, then work through its list in order. The [README](../README.md#getting-started) shows the short path. Run `machine/install.sh --check` at any point. It lists each missing item with its fix and exits 1 when something is missing.

Both lists end with the same steps: a git identity, a GitHub login, and `machine/install.sh`. Use `--multiplexer tmux` with `--check` if you use tmux and not Rex.

## Linux

The steps use `apt`, tested on Ubuntu 24.04 (arm64). On another distribution, install the same packages with your package manager.

1. Install the sandbox packages and git. Without bubblewrap and socat, Claude's sandbox cannot start and every worker exits at once. Install `gh` from [cli.github.com](https://github.com/cli/cli/blob/trunk/docs/install_linux.md) if your repository has no package.

   ```sh
   sudo apt install bubblewrap socat git gh
   ```

2. Allow bwrap to create user namespaces. Ubuntu 24.04 and later block this for unprivileged programs. Install the AppArmor profile from this repo and load it. Skip this step on a system without AppArmor.

   ```sh
   sudo cp machine/apparmor/bwrap /etc/apparmor.d/bwrap
   sudo apparmor_parser -r /etc/apparmor.d/bwrap
   bwrap --unshare-user --unshare-net --ro-bind / / true
   ```

   The last command prints nothing when the sandbox works.

3. Install Go from [go.dev](https://go.dev/dl/) into `/usr/local/go`. Install [Claude Code](https://docs.claude.com/en/docs/claude-code/overview), which puts `claude` in `~/.local/bin`, then run `claude` once to log in.

4. Install a terminal tool. Use tmux for the shortest path, or Rex if you have it.

   - tmux: `sudo apt install tmux`. Then follow [No Rex? Use tmux](../README.md#no-rex-use-tmux) in the README.
   - Rex: install the app and link its CLI to `/usr/local/bin/rex`.

5. Install sfy. Download the amd64 or arm64 tarball from the [simple-factory releases](https://github.com/JacobJNilsson/simple-factory/releases) and put `sfy` in `~/.local/bin`. Link it once with sudo. Later updates with `sfy restart --update` replace the binary and need no sudo.

   ```sh
   sudo ln -s ~/.local/bin/sfy /usr/local/bin/sfy
   ```

   Homebrew also runs on Linux. The tap's `sfy` cask lists Linux tarballs for arm64 and amd64, so `brew install jacobjnilsson/tap/sfy` may work if your Homebrew installs casks on Linux. This repo did not test that route. The tarball is the tested one.

6. Put every tool folder on the `PATH` of the sfy process, not only of the login shell: `~/.local/bin`, `/usr/local/go/bin` and `~/go/bin`. A minimal `PATH` once lost `claude`. Link it into `/usr/local/bin` as well, then restart sfy from a full login shell. Skip `sfy restart` before the first start.

   ```sh
   sudo ln -s ~/.local/bin/claude /usr/local/bin/claude
   sfy restart
   ```

7. Set a global git identity, or workers cannot commit. Use your own name and the address that you commit with. A GitHub noreply address keeps the real address private.

   ```sh
   git config --global user.name "Your Name"
   git config --global user.email "ID+LOGIN@users.noreply.github.com"
   ```

8. Log in to GitHub, and give the token the `workflow` scope so workers can push CI files.

   ```sh
   gh auth login
   gh auth refresh -h github.com -s workflow
   ```

9. Install the Go tools and link the skills, including `git-why`. `--clone-skills` clones [agent-workflow](https://github.com/JacobJNilsson/agent-workflow) when it is missing. The tools include golangci-lint v2.10.1 and antislop v1.4.1, so workers can run `make check`.

   ```sh
   machine/install.sh --clone-skills
   ./install.sh
   ```

10. Test the setup. Check the whole list, then test the sandbox in a worker folder.

    ```sh
    machine/install.sh --check
    claude -p --settings ~/.sfy/sessions/worker-<id>/settings.json "hi"
    ```

    The second command needs a worker session, so run it after your first factory has started a worker.

Then install a factory and start it, as in the [README](../README.md#install-steps).

## macOS

1. Install [Homebrew](https://brew.sh), then the tools. Homebrew puts them on the `PATH`.

   ```sh
   brew install git gh go tmux
   brew install jacobjnilsson/tap/sfy
   ```

   Leave out `tmux` if you use Rex. The sandbox uses Seatbelt, so you need neither bubblewrap, socat nor the AppArmor profile. `machine/install.sh --check` skips them on macOS.

2. Install [Claude Code](https://docs.claude.com/en/docs/claude-code/overview), then run `claude` once to log in.

3. Install a terminal tool. With tmux, follow [No Rex? Use tmux](../README.md#no-rex-use-tmux). Rex runs as an app, and `bin/sfy-rex` finds its CLI inside the app bundle when `rex` is not on the `PATH`.

4. Put `~/go/bin` and `~/.local/bin` on the `PATH`, in your shell profile. Go tools land in `~/go/bin`, or in `GOBIN` when you set it.

5. Set the git identity, log in to GitHub with the `workflow` scope, and run `machine/install.sh --clone-skills` and `./install.sh`. These are steps 7, 8 and 9 of the Linux list.

6. Run `machine/install.sh --check`, with `--multiplexer tmux` if you use tmux. Fix each item it lists.

Then install a factory and start it, as in the [README](../README.md#install-steps).
