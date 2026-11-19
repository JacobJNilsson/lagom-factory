#!/bin/sh
# Tests for lib/link.sh.
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../lib/link.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0
check() {
	if [ "$2" = "$3" ]; then
		echo "ok: $1"
	else
		echo "FAIL: $1 (got '$2', want '$3')"
		fail=1
	fi
}
absent() {
	if [ ! -e "$2" ] && [ ! -L "$2" ]; then
		echo "ok: $1"
	else
		echo "FAIL: $1 ($2 exists)"
		fail=1
	fi
}

mkdir -p "$tmp/a" "$tmp/b"

# Same source: ok, nothing changes.
ln -s "$tmp/a" "$tmp/l1"
out=$(link "$tmp/a" "$tmp/l1")
check "same source prints ok" "$out" "ok: $tmp/l1 already links to $tmp/a"
absent "same source makes no .bak" "$tmp/l1.bak"

# Other source: moved to .bak, new link.
out=$(link "$tmp/b" "$tmp/l1")
check "other source output" "$out" "moved: $tmp/l1 to $tmp/l1.bak
linked: $tmp/l1 -> $tmp/b"
check "new link target" "$(readlink "$tmp/l1")" "$tmp/b"
check "old link kept as .bak" "$(readlink "$tmp/l1.bak")" "$tmp/a"

# Plain file: moved to .bak.
echo data >"$tmp/f"
link "$tmp/a" "$tmp/f" >/dev/null
check "file kept as .bak" "$(cat "$tmp/f.bak")" data
check "file replaced by link" "$(readlink "$tmp/f")" "$tmp/a"

# Stale dir: removed, no .bak.
mkdir -p "$tmp/machine/skills/x"
ln -s "$tmp/machine/skills/x" "$tmp/s1"
out=$(link "$tmp/a" "$tmp/s1" machine/skills)
check "stale output" "$out" "removed: $tmp/s1 pointed into machine/skills
linked: $tmp/s1 -> $tmp/a"
absent "stale link leaves no .bak" "$tmp/s1.bak"

# The same link without STALE_DIR moves to .bak.
ln -s "$tmp/machine/skills/x" "$tmp/s2"
link "$tmp/a" "$tmp/s2" >/dev/null
check "no stale dir moves to .bak" "$(readlink "$tmp/s2.bak")" "$tmp/machine/skills/x"

# A missing parent folder is created.
link "$tmp/a" "$tmp/deep/er/l" >/dev/null
check "parent created" "$(readlink "$tmp/deep/er/l")" "$tmp/a"

# No variable leaks to the caller.
src=keep
dst=keep
stale=keep
link "$tmp/a" "$tmp/l9" >/dev/null
check "caller src kept" "$src" keep
check "caller dst kept" "$dst" keep
check "caller stale kept" "$stale" keep

exit $fail
