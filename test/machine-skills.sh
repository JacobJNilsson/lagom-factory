#!/bin/sh
# Tests how machine/install.sh links skills from an agent-workflow checkout.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
repo=$(dirname "$here")
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0
ok() { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }
install() { sh "$repo/machine/install.sh" --no-tools "$@" 2>&1; }

[ ! -e "$repo/machine/skills" ] || bad "machine/skills still exists"

home=$tmp/home
co=$tmp/aw
mkdir -p "$co/skills/alpha" "$co/skills/why" "$home/.claude/skills/own"
printf 'a\n' > "$co/skills/alpha/SKILL.md"
printf '#!/bin/sh\n' > "$co/skills/why/git-why"

# Missing checkout: skip, print the clone command, exit 0.
out=$(install --skills-repo "$tmp/none" "$home") || bad "missing checkout failed"
case $out in
*"git clone https://github.com/JacobJNilsson/agent-workflow.git $tmp/none"*) ok "missing checkout prints clone command" ;;
*) bad "no clone command in: $out" ;;
esac
[ ! -e "$home/.claude/skills/alpha" ] && ok "missing checkout links nothing" || bad "linked without checkout"

# No flag and no variable: the skip message names the default folder.
h0=$tmp/h0
mkdir -p "$h0"
out=$(env -u SKILLS_REPO sh "$repo/machine/install.sh" --no-tools "$h0" 2>&1) || bad "default folder run failed"
case $out in
*"$h0/.local/share/agent-workflow"*) ok "default skills folder named" ;;
*) bad "default folder missing in: $out" ;;
esac

# Existing checkout: each skill folder is linked, git-why too.
old=$home/.claude/skills/stale
ln -s "/somewhere/machine/skills/stale" "$old"
install --skills-repo "$co" "$home" > /dev/null
[ "$(readlink "$home/.claude/skills/alpha")" = "$co/skills/alpha" ] && ok "skill linked" || bad "alpha not linked"
[ "$(readlink "$home/.local/bin/git-why")" = "$co/skills/why/git-why" ] && ok "git-why linked" || bad "git-why not linked"
[ -d "$home/.claude/skills/own" ] && [ ! -L "$home/.claude/skills/own" ] && ok "other skill untouched" || bad "other skill changed"

# A link into the old machine/skills path is replaced, not moved to .bak.
ln -sfn "/old/machine/skills/alpha" "$home/.claude/skills/alpha"
install --skills-repo "$co" "$home" > /dev/null
[ "$(readlink "$home/.claude/skills/alpha")" = "$co/skills/alpha" ] && ok "old link replaced" || bad "old link kept"
[ ! -e "$home/.claude/skills/alpha.bak" ] && ok "old link left no .bak" || bad "old link moved to .bak"

# Second run changes nothing. The SKILLS_REPO env var works too.
out=$(SKILLS_REPO=$co install "$home")
case $out in
*linked:* | *moved:*) bad "second run changed something: $out" ;;
*) ok "second run changes nothing" ;;
esac

# --no-skills links nothing.
h2=$tmp/h2
mkdir -p "$h2"
install --no-skills --skills-repo "$co" "$h2" > /dev/null
[ ! -e "$h2/.claude/skills" ] && ok "--no-skills links nothing" || bad "--no-skills linked"

# --clone-skills clones from a local repo through a fake git.
mkdir -p "$tmp/fakebin"
printf '#!/bin/sh\nmkdir -p "$3/skills/beta"\n' > "$tmp/fakebin/git"
chmod +x "$tmp/fakebin/git"
h3=$tmp/h3
mkdir -p "$h3"
PATH="$tmp/fakebin:$PATH" install --clone-skills "$h3" > /dev/null
[ -L "$h3/.claude/skills/beta" ] && ok "--clone-skills clones and links" || bad "--clone-skills failed"

exit $fail
