#!/bin/sh
# Installs into a temporary home. Checks that lfy and the scripts land in
# ~/.local/bin, that rex.toml lands in ~/.sfy/config.d, that no config.toml and
# no prompt reaches ~/.sfy, that the reviewer gets no PR-creation prompt, and
# that a second run changes nothing.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
repo=$(dirname "$here")
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fail() {
	echo "FAIL: $*" >&2
	exit 1
}

"$repo/install.sh" "$tmp" > /dev/null

for name in lfy mdwatch sfy-rex lagom-trust; do
	[ "$(readlink "$tmp/.local/bin/$name")" = "$repo/bin/$name" ] || fail "$name is not linked into ~/.local/bin"
done
[ "$(readlink "$tmp/.sfy/config.d/50-lagom-rex.toml")" = "$repo/machine/rex.toml" ] || fail "rex.toml is not linked into ~/.sfy/config.d"

[ ! -e "$tmp/.sfy/config.toml" ] || fail "install linked config.toml into ~/.sfy"
[ ! -e "$tmp/.sfy/prompts" ] || fail "install linked prompts into ~/.sfy"

if grep -q 'gh pr create\|Creating a PR' "$repo/defaults/prompts/reviewer.d/github.md"; then
	fail "reviewer rules mention PR creation"
fi

second=$("$repo/install.sh" "$tmp")
case "$second" in
*linked:* | *moved:*) fail "second run changed something: $second" ;;
esac

echo "ok"
