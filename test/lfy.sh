#!/bin/sh
# Runs bin/lfy against a fake sfy that records its calls. Checks that lfy up
# links the defaults into the factory folder, that a second run changes
# nothing, that lfy register links them too, that other commands pass through,
# that SFY_HOME skips the folder step, and that the home folder and a missing
# sfy fail.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
repo=$(dirname "$here")
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/bin" "$tmp/empty" "$tmp/home"
# A test run inside an sfy session must not inherit its home.
unset SFY_HOME SFY_NAME_PREFIX

fail() {
	echo "FAIL: $*" >&2
	exit 1
}

# The fake sfy prints $FOLDER for factory-folder. It records each call and the
# name prefix it got.
cat >"$tmp/bin/sfy" <<'STUB'
#!/bin/sh
echo "$* prefix=${SFY_NAME_PREFIX:-}" >>"$CALLS"
if [ "$1" = factory-folder ]; then
	printf '%s\n' "$FOLDER"
fi
STUB
chmod +x "$tmp/bin/sfy"

folder=$tmp/home/.sfy/factories/lfy-web
mkdir -p "$folder"
ln -s "$repo/bin/lfy" "$tmp/bin/lfy"

# run ARGS...: run lfy through a link, as install.sh sets it up.
run() {
	: >"$tmp/calls"
	CALLS="$tmp/calls" FOLDER="$folder" HOME="$tmp/home" PATH="$tmp/bin:$PATH" lfy "$@"
}

# lfy up links each defaults entry, then runs sfy up with the name prefix.
out=$(run up)
for entry in "$repo"/defaults/*; do
	name=$(basename "$entry")
	[ "$(readlink "$folder/$name")" = "$entry" ] || fail "$name is not linked to defaults"
done
case "$out" in
*linked:*) ;;
*) fail "first run printed no linked: line: $out" ;;
esac
[ "$(cat "$tmp/calls")" = "factory-folder --create prefix=lfy-
up prefix=lfy-" ] || fail "calls of lfy up: $(cat "$tmp/calls")"

# A second run changes no link and prints no ok: line.
out=$(run up)
[ -z "$out" ] || fail "second run printed: $out"
[ "$(readlink "$folder/config.toml")" = "$repo/defaults/config.toml" ] || fail "second run changed a link"

# restart and a bare lfy link too.
run restart >/dev/null
[ "$(sed -n 1p "$tmp/calls")" = "factory-folder --create prefix=lfy-" ] || fail "restart did not create the folder"
run >/dev/null
[ "$(sed -n 2p "$tmp/calls")" = " prefix=lfy-" ] || fail "bare lfy did not run sfy"

# lfy register in a new factory folder links each defaults entry, then runs
# sfy register.
folder=$tmp/home/.sfy/factories/lfy-new
mkdir -p "$folder"
run register >/dev/null
for entry in "$repo"/defaults/*; do
	name=$(basename "$entry")
	[ "$(readlink "$folder/$name")" = "$entry" ] || fail "register did not link $name"
done
[ "$(cat "$tmp/calls")" = "factory-folder --create prefix=lfy-
register prefix=lfy-" ] || fail "calls of lfy register: $(cat "$tmp/calls")"

# Other commands pass through unchanged, with no factory-folder call.
run status --all >/dev/null
[ "$(cat "$tmp/calls")" = "status --all prefix=lfy-" ] || fail "calls of lfy status: $(cat "$tmp/calls")"

# With SFY_HOME set, lfy up runs no factory-folder call.
: >"$tmp/calls"
SFY_HOME="$tmp/home/.sfy/factories/x" CALLS="$tmp/calls" FOLDER="$folder" HOME="$tmp/home" PATH="$tmp/bin:$PATH" lfy up >/dev/null
[ "$(cat "$tmp/calls")" = "up prefix=lfy-" ] || fail "calls with SFY_HOME: $(cat "$tmp/calls")"

# The home folder's .sfy fails and links nothing.
bad=$tmp/bad
mkdir -p "$bad/home/.sfy"
rc=0
: >"$tmp/calls"
CALLS="$tmp/calls" FOLDER="$bad/home/.sfy" HOME="$bad/home" PATH="$tmp/bin:$PATH" lfy up >"$tmp/bad.out" 2>&1 || rc=$?
[ "$rc" -ne 0 ] || fail "lfy up in the home folder succeeded"
[ -z "$(ls "$bad/home/.sfy")" ] || fail "lfy linked into ~/.sfy"
grep -q 'machine settings only' "$tmp/bad.out" || fail "no error text: $(cat "$tmp/bad.out")"
grep -q '^up ' "$tmp/calls" && fail "sfy up ran after the failure"

# Without sfy, lfy exits 127 with its error text.
rc=0
PATH="$tmp/empty" /bin/sh "$repo/bin/lfy" up >"$tmp/nosfy.out" 2>&1 || rc=$?
[ "$rc" -eq 127 ] || fail "exit code without sfy is $rc"
grep -q 'lfy: sfy not found on PATH' "$tmp/nosfy.out" || fail "no error text: $(cat "$tmp/nosfy.out")"

echo "ok"
