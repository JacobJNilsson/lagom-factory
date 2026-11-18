#!/bin/sh
# Starts two workers at once against a fake rex that is slow to create the
# session. The start subcommand must create sfy-agents exactly once.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
script=$here/../bin/sfy-rex
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/bin"
export TMPDIR=$tmp

cat > "$tmp/bin/rex" <<'STUB'
#!/bin/sh
echo "$*" >> "$CALLS"
case "$*" in
  "window ls "*) [ -e "$SESSION" ] ;;
  "new "*) sleep 1; : > "$SESSION" ;;
esac
STUB
chmod +x "$tmp/bin/rex"

export CALLS="$tmp/calls" SESSION="$tmp/session" PATH="$tmp/bin:$PATH"
: > "$CALLS"
sh "$script" start worker-a /work/d echo hi &
sh "$script" start worker-b /work/d echo hi &
wait
creates=$(grep -c '^new sfy-agents' "$CALLS" || true)
windows=$(grep -c '^window new' "$CALLS" || true)
if [ "$creates" = 1 ] && [ "$windows" = 2 ]; then
  echo "ok   two concurrent starts create the session once"
else
  echo "FAIL session created $creates times, $windows windows"
  echo "rex calls:"; cat "$CALLS"
  exit 1
fi

# Each agents session has its own lock. A held sfy-agents lock must not delay
# a start in work-agents.
: > "$CALLS"
rm -f "$SESSION"
: > "$tmp/sfy-agents-start.lock"
begin=$(date +%s)
sh "$script" start work-worker-a /work/d echo hi
took=$(($(date +%s) - begin))
if [ "$took" -lt 5 ] && grep -q '^new work-agents' "$CALLS" && [ -f "$tmp/sfy-agents-start.lock" ]; then
  echo "ok   a held sfy-agents lock does not block work-agents"
else
  echo "FAIL prefixed start waited $took s or missed work-agents"; exit 1
fi
