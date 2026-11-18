#!/bin/sh
# Set up a machine for sfy workers and reviewers. Safe to run twice.
# Usage: machine/install.sh [--check] [--no-tools] [--no-skills]
#                           [--skills-repo DIR] [--clone-skills] [home]
#   --check            install nothing, list what the machine lacks with the
#                      fix for each item, and exit 1 when anything is missing
#   --no-tools         skip the go install step
#   --no-skills        skip linking the skills
#   --skills-repo DIR  agent-workflow checkout to link skills from. The env
#                      var SKILLS_REPO sets it too. The default is
#                      <home>/.local/share/agent-workflow
#   --clone-skills     clone agent-workflow into the skills folder when it is
#                      missing. Without it, the script prints the clone
#                      command and skips the skills
#   home               home folder to install into, defaults to $HOME
set -eu

# One Go tool per line, as module@version. Change a version here to upgrade.
# An overlay that wants other tools runs machine/install.sh --no-tools and installs its own.
# mermaid-ascii has no v-prefixed tags, so it pins the commit of tag 1.6.1.
TOOLS="
github.com/JacobJNilsson/anti-slop-go/cmd/antislop@v1.4.1
github.com/JacobJNilsson/godebt/cmd/godebt@v0.4.0
mvdan.cc/gofumpt@v0.10.0
golang.org/x/tools/cmd/goimports@v0.44.0
github.com/segmentio/golines@v0.13.0
golang.org/x/tools/gopls@v0.21.1
honnef.co/go/tools/cmd/staticcheck@v0.7.0
github.com/AlexanderGrooff/mermaid-ascii@5f00e3d9ac9f
github.com/caveman-ai/trim-1/cmd/trim@v0.1.0
github.com/charmbracelet/glow/v2@v2.1.1
github.com/golangci/golangci-lint/v2/cmd/golangci-lint@v2.10.1
"

skills_url=https://github.com/JacobJNilsson/agent-workflow.git
tools=1
skills=1
clone=0
check=0
home=${HOME:-}
skills_repo=${SKILLS_REPO:-}
while [ $# -gt 0 ]; do
	case $1 in
	--check) check=1 ;;
	--no-tools) tools=0 ;;
	--no-skills) skills=0 ;;
	--clone-skills) clone=1 ;;
	--skills-repo)
		if [ $# -lt 2 ]; then
			echo "error: --skills-repo needs a folder" >&2
			exit 2
		fi
		skills_repo=$2
		shift
		;;
	-*)
		echo "error: unknown flag $1" >&2
		exit 2
		;;
	*) home=$1 ;;
	esac
	shift
done
if [ -z "$home" ]; then
	echo "error: no home folder" >&2
	exit 2
fi
[ -n "$skills_repo" ] || skills_repo=$home/.local/share/agent-workflow

here=$(cd "$(dirname "$0")" && pwd)

# link SOURCE TARGET: make TARGET a symlink to SOURCE.
link() {
	src=$1
	dst=$2
	if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
		echo "ok: $dst already links to $src"
		return
	fi
	# A link into the old machine/skills folder is stale, so replace it.
	if [ -L "$dst" ]; then
		case $(readlink "$dst") in
		*/machine/skills/*)
			rm "$dst"
			echo "removed: $dst pointed into machine/skills"
			;;
		esac
	fi
	if [ -e "$dst" ] || [ -L "$dst" ]; then
		mv "$dst" "$dst.bak"
		echo "moved: $dst to $dst.bak"
	fi
	mkdir -p "$(dirname "$dst")"
	ln -s "$src" "$dst"
	echo "linked: $dst -> $src"
}

install_tools() {
	if ! command -v go >/dev/null 2>&1; then
		echo "error: go is not installed" >&2
		exit 1
	fi
	for tool in $TOOLS; do
		echo "go install $tool"
		HOME="$home" go install "$tool"
	done
	gobin=$(HOME="$home" go env GOBIN)
	[ -n "$gobin" ] || gobin="$(HOME="$home" go env GOPATH)/bin"
	case ":$PATH:" in
	*":$gobin:"*) ;;
	*) echo "note: add $gobin to PATH so agents find the tools" ;;
	esac
}

install_skills() {
	if [ ! -d "$skills_repo/skills" ]; then
		if [ "$clone" = 1 ]; then
			command -v git >/dev/null 2>&1 || {
				echo "error: git is not installed" >&2
				exit 1
			}
			mkdir -p "$(dirname "$skills_repo")"
			git clone "$skills_url" "$skills_repo"
		else
			echo "skipped: no agent-workflow checkout at $skills_repo, so no skills are linked"
			echo "  clone it: git clone $skills_url $skills_repo"
			echo "  then run this script again, or pass --clone-skills"
			return
		fi
	fi
	for dir in "$skills_repo"/skills/*/; do
		[ -d "$dir" ] || continue
		name=$(basename "$dir")
		link "${dir%/}" "$home/.claude/skills/$name"
	done
	if [ -f "$skills_repo/skills/why/git-why" ]; then
		link "$skills_repo/skills/why/git-why" "$home/.local/bin/git-why"
	fi
}

# check: report each missing item with its fix. Exits 1 when any is missing.
# APPARMOR_DIR overrides /etc/apparmor.d, so a test can use a fake folder.
run_check() {
	missing=0
	miss() {
		echo "MISSING: $1"
		echo "  fix: $2"
		missing=1
	}
	for t in bwrap socat; do
		command -v "$t" >/dev/null 2>&1 || miss "$t is not on PATH" "sudo apt install bubblewrap socat"
	done
	command -v rex >/dev/null 2>&1 || miss "rex is not on PATH" "install Rex, then link its CLI to /usr/local/bin/rex"
	command -v claude >/dev/null 2>&1 || miss "claude is not on PATH" "install Claude Code, then: sudo ln -s ~/.local/bin/claude /usr/local/bin/claude"
	command -v go >/dev/null 2>&1 || miss "go is not on PATH" "install Go to /usr/local/go and add /usr/local/go/bin to PATH"
	command -v git >/dev/null 2>&1 || miss "git is not on PATH" "sudo apt install git"
	command -v gh >/dev/null 2>&1 || miss "gh is not on PATH" "sudo apt install gh"
	for t in glow golangci-lint antislop; do
		command -v "$t" >/dev/null 2>&1 || miss "$t is not on PATH" "machine/install.sh (go install into ~/go/bin), and put ~/go/bin on PATH"
	done

	aa=${APPARMOR_DIR:-/etc/apparmor.d}
	restrict=$(sysctl -n kernel.apparmor_restrict_unprivileged_userns 2>/dev/null || true)
	if [ "$restrict" = 1 ] && [ ! -f "$aa/bwrap" ]; then
		miss "AppArmor blocks user namespaces and no bwrap profile exists" "sudo cp $here/apparmor/bwrap /etc/apparmor.d/bwrap && sudo apparmor_parser -r /etc/apparmor.d/bwrap"
	fi
	if command -v bwrap >/dev/null 2>&1; then
		bwrap --unshare-user --unshare-net --ro-bind / / true >/dev/null 2>&1 ||
			miss "the bwrap probe failed" "see docs/new-machine.md, section AppArmor"
	fi

	if [ -z "$(HOME="$home" git config --global user.name 2>/dev/null || true)" ] ||
		[ -z "$(HOME="$home" git config --global user.email 2>/dev/null || true)" ]; then
		miss "no global git identity" "git config --global user.name NAME && git config --global user.email ID+LOGIN@users.noreply.github.com"
	fi
	if command -v gh >/dev/null 2>&1; then
		gh auth status 2>&1 | grep -q workflow ||
			miss "the gh token lacks the workflow scope" "gh auth refresh -h github.com -s workflow"
	fi

	if [ "$missing" = 0 ]; then
		echo "ok: nothing is missing"
	fi
	exit "$missing"
}

if [ "$check" = 1 ]; then
	run_check
fi
if [ "$tools" = 1 ]; then
	install_tools
fi
if [ "$skills" = 1 ]; then
	install_skills
fi
