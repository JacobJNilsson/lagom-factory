#!/bin/sh
# Tests machine/install.sh --check with fake tools. The script runs on the
# normal PATH, and the probes see only the fakes in $tmp/bin (CHECK_PATH).
set -eu
here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/bin" "$tmp/aa" "$tmp/home"
fake() { printf '#!/bin/sh\n%s\n' "${2:-exit 0}" > "$tmp/bin/$1"; chmod +x "$tmp/bin/$1"; }
run() { CHECK_PATH="$tmp/bin" APPARMOR_DIR="$tmp/aa" CHECK_OS=${CHECK_OS:-Linux} /bin/sh "$here/../machine/install.sh" --check "$@" "$tmp/home" 2>&1; }
fail=0
expect() {
  if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: status $3, want $2"; fail=1; fi
}
has() { case $2 in *"$1"*) echo "ok   output has: $1";; *) echo "FAIL output lacks: $1"; fail=1;; esac; }

# The TOOLS entries come from the script. The binary names are the expected
# derivation, written out by hand.
tools=$(sed -n '/^TOOLS="$/,/^"$/p' "$here/../machine/install.sh" | sed '1d;$d')
tool_bins="antislop godebt gofumpt goimports golines gopls staticcheck mermaid-ascii trim glow golangci-lint"

# Nothing installed: everything is reported.
out=$(run) && st=0 || st=$?
expect "empty machine exits 1" 1 $st
for w in "sudo apt install bubblewrap socat" "claude" "golangci-lint" "antislop" "global git identity"; do has "$w" "$out"; done

# Every TOOLS entry has a probe and appears in the tool fix.
for t in $tools; do has "go install $t into" "$out"; done
got=$(printf '%s\n' "$out" | sed -n 's/^MISSING: \(.*\) is not on PATH$/\1/p' | grep -Fx -e antislop -e godebt -e gofumpt -e goimports -e golines -e gopls -e staticcheck -e mermaid-ascii -e trim -e glow -e golangci-lint | sort | tr '\n' ' ')
want=$(printf '%s\n' $tool_bins | sort | tr '\n' ' ')
if [ "$got" = "$want" ]; then echo "ok   tool binary names"; else echo "FAIL tool binary names: $got, want $want"; fail=1; fi

# The tool fix names the folder that go install writes to.
has "into $tmp/home/go/bin)" "$out"
fake go 'case "$*" in "env GOBIN") echo "$GOBIN_ANSWER";; "env GOPATH") echo "'"$tmp"'/gopath";; esac'
out=$(run) && st=0 || st=$?
has "into $tmp/gopath/bin)" "$out"
out=$(GOBIN_ANSWER=/custom/gobin run) && st=0 || st=$?
has "into /custom/gobin)" "$out"

# Everything present and healthy.
for t in bwrap socat rex claude $tool_bins; do fake $t; done
fake sysctl 'echo 1'
fake git 'if [ "$3" = user.name ]; then echo n; else echo e; fi'
fake gh 'echo "Token scopes: repo, workflow" >&2'
printf 'profile\n' > "$tmp/aa/bwrap"
out=$(run) && st=0 || st=$?
expect "healthy machine exits 0" 0 $st
has "nothing is missing" "$out"

# Missing profile with the sysctl on.
rm "$tmp/aa/bwrap"
out=$(run) && st=0 || st=$?
expect "missing profile exits 1" 1 $st
has "apparmor_parser -r" "$out"
printf 'profile\n' > "$tmp/aa/bwrap"

# Failing bwrap probe.
fake bwrap 'exit 1'
out=$(run) && st=0 || st=$?
expect "failing probe exits 1" 1 $st
has "bwrap probe failed" "$out"
fake bwrap

# Missing workflow scope.
fake gh 'echo "Token scopes: repo" >&2'
out=$(run) && st=0 || st=$?
expect "no workflow scope exits 1" 1 $st
has "gh auth refresh -h github.com -s workflow" "$out"
fake gh 'echo "Token scopes: repo, workflow" >&2'

# Without Rex, the default check reports it and the tmux check does not.
rm "$tmp/bin/rex"
out=$(run) && st=0 || st=$?
expect "no rex exits 1" 1 $st
has "--multiplexer tmux" "$out"
out=$(run --multiplexer tmux) && st=0 || st=$?
expect "no tmux exits 1" 1 $st
has "tmux is not on PATH" "$out"
fake tmux
out=$(run --multiplexer tmux) && st=0 || st=$?
expect "tmux without rex exits 0" 0 $st
has "nothing is missing" "$out"

# macOS needs no bwrap, socat or AppArmor profile.
rm "$tmp/bin/bwrap" "$tmp/bin/socat" "$tmp/aa/bwrap"
out=$(run --multiplexer tmux) && st=0 || st=$?
expect "linux without bwrap exits 1" 1 $st
out=$(CHECK_OS=Darwin run --multiplexer tmux) && st=0 || st=$?
expect "macOS without bwrap exits 0" 0 $st
rm "$tmp/bin/go"
out=$(CHECK_OS=Darwin run --multiplexer tmux) && st=0 || st=$?
has "brew install go" "$out"
exit $fail
