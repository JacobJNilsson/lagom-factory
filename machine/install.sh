#!/bin/sh
# Set up a machine for sfy workers and reviewers. Safe to run twice.
# Usage: machine/install.sh [--check] [--multiplexer rex|tmux] [--no-tools]
#                           [--no-skills] [--skills-repo DIR] [--clone-skills]
#                           [home]
#   --check            install nothing, list what the machine lacks with the
#                      fix for each item, and exit 1 when anything is missing.
#                      On macOS it skips the Linux sandbox items.
#   --multiplexer NAME with --check, test for this terminal tool: rex (the
#                      default) or tmux
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
mux=rex
home=${HOME:-}
skills_repo=${SKILLS_REPO:-}
while [ $# -gt 0 ]; do
	case $1 in
	--check) check=1 ;;
	--multiplexer)
		case ${2:-} in
		rex | tmux) mux=$2 ;;
		*)
			echo "error: --multiplexer needs rex or tmux" >&2
			exit 2
			;;
		esac
		shift
		;;
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
. "$here/../lib/link.sh"

# probe CMD [ARG...] runs CMD in a subshell with the probe PATH (CHECK_PATH,
# else PATH) and HOME set to the home argument. It returns the status of CMD.
# Every command that inspects the machine goes through probe, and nothing
# else does. A test sets CHECK_PATH to a folder of fakes, and a command that
# skips probe would run the real tool.
probe() (
	PATH=${CHECK_PATH:-$PATH}
	HOME=$home
	export PATH HOME
	"$@"
)

# tool_bin MODULE@VERSION prints the binary name that go install gives: the
# last path element, or the one before it when the last is a major version.
tool_bin() {
	mod=${1%@*}
	name=${mod##*/}
	case $name in
	v[0-9]*)
		case ${name#v} in
		*[!0-9]*) ;;
		*)
			mod=${mod%/*}
			name=${mod##*/}
			;;
		esac
		;;
	esac
	printf '%s\n' "$name"
}

# go_bin_dir prints the folder that go install writes to for the home. It
# fails when go is missing.
go_bin_dir() {
	dir=$(probe go env GOBIN) || return 1
	if [ -z "$dir" ]; then
		dir=$(probe go env GOPATH) || return 1
		dir=$dir/bin
	fi
	printf '%s\n' "$dir"
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
	gobin=$(go_bin_dir)
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
		# A link into the old machine/skills folder is stale, so replace it.
		link "${dir%/}" "$home/.claude/skills/$name" machine/skills
	done
	if [ -f "$skills_repo/skills/why/git-why" ]; then
		link "$skills_repo/skills/why/git-why" "$home/.local/bin/git-why" machine/skills
	fi
}

# The probes. Each succeeds when its requirement holds. All of them go
# through probe.

# on_path NAME succeeds when NAME is on the probe PATH.
on_path() {
	probe command -v "$1" >/dev/null 2>&1
}

# rex_found succeeds when bin/sfy-rex finds a Rex CLI. It uses the copy in
# this repo, so it works before install.sh links the script.
rex_found() {
	probe /bin/sh "$here/../bin/sfy-rex" which >/dev/null 2>&1
}

# apparmor_ok succeeds unless AppArmor blocks user namespaces and no bwrap
# profile exists.
apparmor_ok() {
	restrict=$(probe sysctl -n kernel.apparmor_restrict_unprivileged_userns 2>/dev/null || true)
	[ "$restrict" != 1 ] || [ -f "${APPARMOR_DIR:-/etc/apparmor.d}/bwrap" ]
}

# bwrap_ok succeeds when bwrap is missing (another row reports that) or runs.
bwrap_ok() {
	on_path bwrap || return 0
	probe bwrap --unshare-user --unshare-net --ro-bind / / true >/dev/null 2>&1
}

# git_identity succeeds when the home has a global git name and email.
git_identity() {
	name=$(probe git config --global user.name 2>/dev/null || true)
	email=$(probe git config --global user.email 2>/dev/null || true)
	[ -n "$name" ] && [ -n "$email" ]
}

# gh_workflow succeeds when gh is missing (another row reports that) or its
# token has the workflow scope.
gh_workflow() {
	on_path gh || return 0
	out=$(probe gh auth status 2>&1 || true)
	case $out in
	*workflow*) return 0 ;;
	esac
	return 1
}

# requirements prints the table that run_check reads, one row per line:
#   probe|message|linux fix|darwin fix
# An empty fix means that OS does not need the row. No field may contain "|".
# The probe field is a function name and at most one argument without spaces.
# It reads $home, $here, $gobin and $mux.
requirements() {
	apt_sandbox="sudo apt install bubblewrap socat"
	printf '%s|%s|%s|%s\n' "on_path bwrap" "bwrap is not on PATH" "$apt_sandbox" ""
	printf '%s|%s|%s|%s\n' "on_path socat" "socat is not on PATH" "$apt_sandbox" ""
	if [ "$mux" = tmux ]; then
		printf '%s|%s|%s|%s\n' "on_path tmux" "tmux is not on PATH" "sudo apt install tmux" "brew install tmux"
	else
		printf '%s|%s|%s|%s\n' "rex_found" "rex is not on PATH" \
			"install Rex, then link its CLI to /usr/local/bin/rex, or run this check with --multiplexer tmux" \
			"install the Rex app, which bin/sfy-rex finds in its app bundle, or run this check with --multiplexer tmux"
	fi
	printf '%s|%s|%s|%s\n' "on_path claude" "claude is not on PATH" \
		"install Claude Code, then: sudo ln -s $home/.local/bin/claude /usr/local/bin/claude" \
		"install Claude Code, then put $home/.local/bin on PATH"
	printf '%s|%s|%s|%s\n' "on_path go" "go is not on PATH" \
		"install Go to /usr/local/go and add /usr/local/go/bin to PATH" "brew install go"
	printf '%s|%s|%s|%s\n' "on_path git" "git is not on PATH" "sudo apt install git" "brew install git"
	printf '%s|%s|%s|%s\n' "on_path gh" "gh is not on PATH" "sudo apt install gh" "brew install gh"
	for tool in $TOOLS; do
		bin=$(tool_bin "$tool")
		fix="machine/install.sh (go install $tool into $gobin), and put $gobin on PATH"
		printf '%s|%s|%s|%s\n' "on_path $bin" "$bin is not on PATH" "$fix" "$fix"
	done
	printf '%s|%s|%s|%s\n' "apparmor_ok" "AppArmor blocks user namespaces and no bwrap profile exists" \
		"sudo cp $here/apparmor/bwrap /etc/apparmor.d/bwrap && sudo apparmor_parser -r /etc/apparmor.d/bwrap" ""
	printf '%s|%s|%s|%s\n' "bwrap_ok" "the bwrap probe failed" \
		'see "Allow bwrap to create user namespaces" in docs/new-machine.md' ""
	fix="git config --global user.name NAME && git config --global user.email ID+LOGIN@users.noreply.github.com"
	printf '%s|%s|%s|%s\n' "git_identity" "no global git identity" "$fix" "$fix"
	fix="gh auth refresh -h github.com -s workflow"
	printf '%s|%s|%s|%s\n' "gh_workflow" "the gh token lacks the workflow scope" "$fix" "$fix"
}

# run_check reports each missing item with its fix. Exits 1 when any is missing.
# Test hooks:
#   CHECK_OS      overrides uname -s.
#   APPARMOR_DIR  overrides /etc/apparmor.d.
#   CHECK_PATH    is the PATH that the probes search and run with. It defaults
#                 to PATH. The script itself always runs on PATH.
run_check() {
	missing=0
	miss() {
		echo "MISSING: $1"
		echo "  fix: $2"
		missing=1
	}
	os=${CHECK_OS:-$(uname -s 2>/dev/null || true)}
	gobin=$(go_bin_dir 2>/dev/null) || gobin=$home/go/bin
	# The loop reads a here-document and not a pipe, so it keeps $missing.
	while IFS='|' read -r probe_cmd message linux_fix darwin_fix; do
		if [ "$os" = Darwin ]; then
			fix=$darwin_fix
		else
			fix=$linux_fix
		fi
		[ -n "$fix" ] || continue
		$probe_cmd || miss "$message" "$fix"
	done <<EOF
$(requirements)
EOF
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
