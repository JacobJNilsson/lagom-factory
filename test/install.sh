#!/bin/sh
# Installs into a temporary home. Checks that the shared writing rules reach the
# worker and reviewer folders, that the reviewer gets no PR-creation prompt, that
# an old folder link moves aside, and that a second run changes nothing.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
repo=$(dirname "$here")
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fail() {
	echo "FAIL: $*" >&2
	exit 1
}

mkdir -p "$tmp/.sfy/prompts"
ln -s "$repo/prompts/worker.d" "$tmp/.sfy/prompts/worker.d"

"$repo/install.sh" "$tmp" > /dev/null

[ ! -L "$tmp/.sfy/prompts/worker.d" ] || fail "worker.d is still a folder link"
[ -d "$tmp/.sfy/prompts/worker.d.bak" ] || [ -L "$tmp/.sfy/prompts/worker.d.bak" ] || fail "old link not moved"
for kind in worker reviewer; do
	[ -L "$tmp/.sfy/prompts/$kind.d/writing.md" ] || fail "$kind.d has no writing.md"
	[ -L "$tmp/.sfy/prompts/$kind.d/github.md" ] || fail "$kind.d has no github.md"
done
for kind in main worker reviewer; do
	[ -L "$tmp/.sfy/prompts/$kind.d/decisions.md" ] || fail "$kind.d has no decisions.md"
done
[ -L "$tmp/.sfy/prompts/worker.d/pull-request.md" ] || fail "worker.d has no pull-request.md"
[ -L "$tmp/.sfy/prompts/main.d/pull-request.md" ] || fail "main.d has no pull-request.md"
[ ! -e "$tmp/.sfy/prompts/main.d/writing.md" ] || fail "main.d got writing.md"
[ ! -e "$tmp/.sfy/prompts/reviewer.d/pull-request.md" ] || fail "reviewer.d got pull-request.md"
if grep -q 'gh pr create\|Creating a PR' "$repo/prompts/reviewer.d/github.md"; then
	fail "reviewer rules mention PR creation"
fi

second=$("$repo/install.sh" "$tmp")
case "$second" in
*linked:* | *moved:*) fail "second run changed something: $second" ;;
esac

echo "ok"
