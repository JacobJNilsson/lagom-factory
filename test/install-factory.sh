#!/bin/sh
# Installs the fixture factories from test/fixtures/factories into a temporary
# home. Checks the lookup of the factory folder (flag, variable, repo fallback),
# the config link, the override of shared files, the shared files that stay,
# that the default install is untouched, the failures, and that a second run
# changes nothing.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
repo=$(dirname "$here")
fx=$here/fixtures/factories
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fail() {
	echo "FAIL: $*" >&2
	exit 1
}

# install ARGS...: run install.sh without a LFY_FACTORIES from the shell.
install() {
	env -u LFY_FACTORIES "$repo/install.sh" "$@"
}

# Case 1: the fixture factory installs from an outside folder.
install --factory example --factories "$fx" "$tmp" > /dev/null
state="$tmp/.sfy/factories/example"
p="$state/prompts"

[ "$(readlink "$state/config.toml")" = "$fx/example/config.toml" ] || fail "config.toml not linked"
[ ! -e "$tmp/.sfy/config.toml" ] || fail "factory install touched ~/.sfy/config.toml"
[ ! -e "$tmp/.sfy/prompts" ] || fail "factory install wrote ~/.sfy/prompts"
[ "$(readlink "$p/worker.d/pull-request.md")" = "$fx/example/prompts/worker.d/pull-request.md" ] || fail "worker pull-request not replaced"
[ ! -e "$p/worker.d/pull-request.md.bak" ] || fail "override left a .bak"
[ "$(readlink "$p/main.d/pull-request.md")" = "$repo/prompts/main.d/pull-request.md" ] || fail "main pull-request not shared"
[ "$(readlink "$p/reviewer.d/writing.md")" = "$fx/example/prompts/reviewer.d/writing.md" ] || fail "reviewer writing.md not replaced"
[ "$(readlink "$p/worker.d/writing.md")" = "$repo/prompts/shared/writing.md" ] || fail "worker writing.md not shared"
for f in main.d/example.md worker.d/example.md worker-repo.d/example.md; do
	[ -L "$p/$f" ] || fail "no link $f"
done
for kind in worker reviewer; do
	[ "$(readlink "$p/$kind.d/github.md")" = "$repo/prompts/$kind.d/github.md" ] || fail "$kind github.md not shared"
done
[ -L "$p/main.d/decisions.md" ] || fail "main has no decisions.md"
[ ! -e "$p/main.d/writing.md" ] || fail "main got writing.md"

# Case 2: a second run changes nothing.
second=$(install --factory example --factories "$fx" "$tmp")
case "$second" in
*linked:* | *moved:*) fail "second run changed something: $second" ;;
esac

# Case 3: the order of the flags does not matter.
h3=$tmp/h3
install --factories "$fx" --factory example "$h3" > /dev/null
[ "$(readlink "$h3/.sfy/factories/example/config.toml")" = "$fx/example/config.toml" ] || fail "flag order changed the result"

# Case 4: LFY_FACTORIES names the folder.
h4=$tmp/h4
LFY_FACTORIES=$fx "$repo/install.sh" --factory example "$h4" > /dev/null
[ "$(readlink "$h4/.sfy/factories/example/config.toml")" = "$fx/example/config.toml" ] || fail "LFY_FACTORIES not used"

# Case 5: the flag wins over the variable.
mkdir "$tmp/other"
cp -R "$fx/example" "$tmp/other/example"
h5=$tmp/h5
LFY_FACTORIES=$tmp/other "$repo/install.sh" --factory example --factories "$fx" "$h5" > /dev/null
[ "$(readlink "$h5/.sfy/factories/example/config.toml")" = "$fx/example/config.toml" ] || fail "variable won over the flag"

# Case 6: a relative folder gives absolute links.
h6=$tmp/h6
(cd "$here" && install --factory example --factories fixtures/factories "$h6" > /dev/null)
case "$(readlink "$h6/.sfy/factories/example/config.toml")" in
/*) ;;
*) fail "relative --factories gave a relative link" ;;
esac

# Case 7: the outside folder wins over the repo's factories folder.
# Case 8: without an outside folder the repo's factories folder is used.
mkdir -p "$tmp/repo/factories"
cp -R "$repo/install.sh" "$repo/config.toml" "$repo/bin" "$repo/lib" "$repo/prompts" "$tmp/repo/"
cp -R "$fx/example" "$tmp/repo/factories/example"
h7=$tmp/h7
env -u LFY_FACTORIES "$tmp/repo/install.sh" --factory example --factories "$fx" "$h7" > /dev/null
[ "$(readlink "$h7/.sfy/factories/example/config.toml")" = "$fx/example/config.toml" ] || fail "repo factories won over the outside folder"
h8=$tmp/h8
env -u LFY_FACTORIES "$tmp/repo/install.sh" --factory example "$h8" > /dev/null
[ "$(readlink "$h8/.sfy/factories/example/config.toml")" = "$tmp/repo/factories/example/config.toml" ] || fail "repo fallback broken"

# Case 9: a factory with no config and no prompts installs.
h9=$tmp/h9
install --factory bare --factories "$fx" "$h9" > /dev/null
[ ! -e "$h9/.sfy/factories/bare/config.toml" ] || fail "bare factory got a config.toml"
[ "$(readlink "$h9/.sfy/factories/bare/prompts/worker.d/github.md")" = "$repo/prompts/worker.d/github.md" ] || fail "bare factory lacks shared github.md"

# Case 10: failures exit 2 and print to stderr.
# expect_fail ARGS...: install.sh must exit 2 and print something to stderr.
expect_fail() {
	set +e
	err=$(install "$@" 2>&1 > /dev/null)
	code=$?
	set -e
	[ "$code" = 2 ] || fail "install.sh $*: exit $code, want 2"
	[ -n "$err" ] || fail "install.sh $*: no message on stderr"
}
h10=$tmp/h10
expect_fail --factory nope --factories "$fx" "$h10"
case "$err" in
*"$fx"*"$repo/factories"*) ;;
*) fail "unknown factory message does not name both folders: $err" ;;
esac
expect_fail --factories "$tmp/none" --factory example "$h10"
expect_fail --factory example --factories
expect_fail --factories "$fx" "$h10"
expect_fail --factory
[ ! -e "$h10" ] || fail "a failed install wrote to the home"

# Case 11: the default install is untouched.
h11=$tmp/h11
LFY_FACTORIES=$fx "$repo/install.sh" "$h11" > /dev/null
[ "$(readlink "$h11/.sfy/prompts/worker.d/pull-request.md")" = "$repo/prompts/worker.d/pull-request.md" ] || fail "default pull-request changed"
[ ! -e "$h11/.sfy/prompts/worker.d/example.md" ] || fail "default got example.md"

echo "ok"
