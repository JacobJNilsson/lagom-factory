#!/bin/sh
# Checks the lagom defaults: every link resolves, both writing.md links reach
# the shared file, and no file uses a name that sfy dropped.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
repo=$(dirname "$here")

fail() {
	echo "FAIL: $*" >&2
	exit 1
}

for link in $(find "$repo/defaults" -type l); do
	[ -e "$link" ] || fail "dangling link $link"
done

for kind in worker reviewer; do
	f="$repo/defaults/prompts/$kind.d/writing.md"
	[ -L "$f" ] || fail "$kind.d/writing.md is not a link"
	[ "$(readlink "$f")" = "../shared/writing.md" ] || fail "$kind.d/writing.md does not link to ../shared/writing.md"
	cmp -s "$f" "$repo/defaults/prompts/shared/writing.md" || fail "$kind.d/writing.md does not reach shared/writing.md"
done
[ -d "$repo/defaults/prompts/lead.d" ] || fail "no defaults/prompts/lead.d"
[ ! -e "$repo/defaults/prompts/main.d" ] || fail "defaults/prompts/main.d still exists"

for f in defaults/config.toml machine/rex.toml; do
	if grep -Eq '^\[?session_settings\.main\]|^main[ =]|show_main' "$repo/$f"; then
		fail "$f uses an old name (main key or show_main)"
	fi
done

if grep -Eq '^multiplexer[ =]|^\[multiplexers' "$repo/defaults/config.toml"; then
	fail "defaults/config.toml holds a machine setting"
fi
grep -q '^multiplexer = "rex"' "$repo/machine/rex.toml" || fail "machine/rex.toml has no multiplexer"
grep -q '^show_lead = ' "$repo/machine/rex.toml" || fail "machine/rex.toml has no show_lead"

lead_table=$(awk '/^\[/ { in_lead = ($0 == "[session_settings.lead]") } in_lead' "$repo/defaults/config.toml")
printf '%s\n' "$lead_table" | grep -Eq '^env = \{ CLAUDE_CODE_EXPERIMENTAL_CODE_MODE = "1" \}$' || fail "the lead table in defaults/config.toml does not set CLAUDE_CODE_EXPERIMENTAL_CODE_MODE = \"1\""
for kind in worker reviewer; do
	if awk -v t="[session_settings.$kind]" '/^\[/ { in_t = ($0 == t) } in_t' "$repo/defaults/config.toml" | grep -q CODE_MODE; then
		fail "the $kind table in defaults/config.toml sets Code Mode"
	fi
done

echo "ok"
