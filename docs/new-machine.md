# New machine

This checklist sets up a fresh Ubuntu machine (tested on 24.04, arm64) for sfy. Work through it in order. Run `machine/install.sh --check` at any point. It lists each missing item with its fix and exits 1 when something is missing.

## Linux

1. Install the sandbox packages. Without them Claude's sandbox cannot start and every worker exits at once.

   ```sh
   sudo apt install bubblewrap socat git gh
   ```

2. Allow bwrap to create user namespaces. Ubuntu 24.04 blocks this for unprivileged programs. Install the AppArmor profile from this repo and load it.

   ```sh
   sudo cp machine/apparmor/bwrap /etc/apparmor.d/bwrap
   sudo apparmor_parser -r /etc/apparmor.d/bwrap
   bwrap --unshare-user --unshare-net --ro-bind / / true
   ```

   The last command prints nothing when the sandbox works.

3. Install Go from go.dev into `/usr/local/go`. Install Claude Code, which puts `claude` in `~/.local/bin`. Install Rex and link its CLI to `/usr/local/bin/rex`.

4. Put every tool folder on the `PATH` of the sfy process, not only of the login shell: `~/.local/bin`, `/usr/local/go/bin` and `~/go/bin`. A minimal `PATH` once lost `claude`. Link it into `/usr/local/bin` as well, then restart sfy from a full login shell.

   ```sh
   sudo ln -s ~/.local/bin/claude /usr/local/bin/claude
   sfy restart
   ```

5. Install sfy. Homebrew does not exist on Linux, so download the release binary to `~/.local/bin/sfy`. Link it once with sudo. Later updates replace the binary and need no sudo.

   ```sh
   sudo ln -s ~/.local/bin/sfy /usr/local/bin/sfy
   ```

6. Set a global git identity, or workers cannot commit. Use the GitHub noreply address.

   ```sh
   git config --global user.name "Your Name"
   git config --global user.email "ID+LOGIN@users.noreply.github.com"
   ```

7. Log in to GitHub, and give the token the `workflow` scope so workers can push CI files.

   ```sh
   gh auth login
   gh auth refresh -h github.com -s workflow
   ```

8. Install the Go tools and link the skills, including `git-why`. This adds golangci-lint v2.10.1 and antislop v1.4.1 so workers can run `make check`.

   ```sh
   machine/install.sh
   ./install.sh
   ```

9. Test the setup. Check the whole list, then test the sandbox in a worker folder.

   ```sh
   machine/install.sh --check
   claude -p --settings ~/.sfy/sessions/worker-<id>/settings.json "hi"
   ```

## macOS

- Install sfy with Homebrew. There is no `/usr/local/bin` link step.
- The sandbox uses Seatbelt. You need neither bubblewrap, socat nor the AppArmor profile, and `--check` reports them as missing. Ignore those lines.
- Rex runs as an app. The config falls back to the path inside the app bundle when `rex` is not on the `PATH`.
- Go comes from Homebrew or go.dev, and Go tools land in `~/go/bin`. Put that folder on the `PATH` as on Linux.
- The git identity and the `workflow` scope steps are the same.
