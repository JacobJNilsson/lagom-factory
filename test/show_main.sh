#!/bin/sh
# Runs bin/sfy-rex show-main against a fake rex. The fake answers block ls with
# a saved reply. test/block-ls.json is a reply from
# rex block ls -s sfy-main --json (rex 0.1.0 beta) with the ids replaced. It
# holds the labels shell, sfy-notes and sfy-status. The script only looks for
# the label strings.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
script=$here/../bin/sfy-rex
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/bin"

cat > "$tmp/bin/rex" <<'STUB'
#!/bin/sh
case "$*" in
  *"block ls "*)
    echo "$*" >> "$LS_CALLS"
    [ -z "${LS_FAIL:-}" ] || { echo "rex block ls --json requires one session. Pass -s SESSION" >&2; exit 2; }
    cat "$LS_JSON" ;;
  *) echo "$*" >> "$CALLS" ;;
esac
STUB
chmod +x "$tmp/bin/rex"

# The same reply without the two panes: only its first block.
cat > "$tmp/no-panes.json" <<'JSON'
{
  "blocks": [
    {
      "block_id": "block:00000000-0000-7000-8000-000000000001",
      "label": "shell",
      "creator_name": "com.superlogical.terminal",
      "flavor": "com.superlogical.terminal.shell",
      "placement": "placed"
    }
  ]
}
JSON
panes=$here/block-ls.json
nopanes=$tmp/no-panes.json

fail=0
# check DESCRIPTION EXPECTED-CALLS EXPECTED-LS-CALLS JSON [ENV=VALUE...]
check() {
  desc=$1 want=$2 wantls=$3 json=$4
  shift 4
  rc=0 arg=${ARG-}
  : > "$tmp/calls"
  : > "$tmp/ls"
  env -u REX_BLOCK -u REX_SESSION -u SFY_HOME HOME="$tmp/home" PATH="$tmp/bin:$PATH" \
    CALLS="$tmp/calls" LS_JSON="$json" LS_CALLS="$tmp/ls" "$@" sh "$script" show-main ${arg:+"$arg"} || rc=$?
  got=$(cat "$tmp/calls")
  gotls=$(cat "$tmp/ls")
  if [ "$got" = "$want" ] && [ "$gotls" = "$wantls" ]; then echo "ok   $desc"; else
    echo "FAIL $desc: got '$got' ls '$gotls'"; fail=1
  fi
}

v=$tmp/home/.local/bin/mdwatch
mkdir -p "$tmp/home/.local/bin" "$tmp/bare"
printf '#!/bin/sh\n' > "$v"
chmod +x "$v"
# block ls has no -b flag, so the listing scopes to the session. Without a
# session it uses the default scope. The status pane opens before the notes pane.
ls_b="--autostart=false block ls -s session:1 --json"
ls_s="--autostart=false block ls -s session:1 --json"
ls_none="--autostart=false block ls --json"
check "block anchor, state folder from SFY_HOME" "split -b b1 --split=above --focus=false --label sfy-status -- $v /s/status.md
split -b b1 --split=right --focus=false --label sfy-notes -- $v /s/notes.md" "$ls_b" \
  "$nopanes" REX_BLOCK=b1 REX_SESSION=session:1 SFY_HOME=/s
ARG=/f/app
check "session anchor, state folder from the argument" "split -s session:1 --split=above --focus=false --label sfy-status -- $v /f/app/status.md
split -s session:1 --split=right --focus=false --label sfy-notes -- $v /f/app/notes.md" "$ls_s" \
  "$nopanes" REX_SESSION=session:1
ARG=/f/web
check "argument wins over SFY_HOME" "split -s session:1 --split=above --focus=false --label sfy-status -- $v /f/web/status.md
split -s session:1 --split=right --focus=false --label sfy-notes -- $v /f/web/notes.md" "$ls_s" \
  "$nopanes" REX_SESSION=session:1 SFY_HOME=/f/app
ARG=
check "no state folder, no call, no ~/.sfy fallback" "" "" "$nopanes" REX_SESSION=session:1
ARG=
# F5: with only REX_BLOCK set, block ls takes the default scope, not an empty session.
check "only REX_BLOCK set" "split -b b1 --split=above --focus=false --label sfy-status -- $v /s/status.md
split -b b1 --split=right --focus=false --label sfy-notes -- $v /s/notes.md" "$ls_none" \
  "$nopanes" REX_BLOCK=b1 SFY_HOME=/s
check "panes exist, no second pair" "" "$ls_b" "$panes" REX_BLOCK=b1 REX_SESSION=session:1 SFY_HOME=/s
check "no Rex variables, no call" "" "" "$panes" SFY_HOME=/s

# Without mdwatch, each pane runs a redraw loop and keeps its label.
loop='sh -c while :; do clear; cat "$1"; sleep 2; done sh'
check "no viewer, redraw loop" "split -b b1 --split=above --focus=false --label sfy-status -- $loop /s/status.md
split -b b1 --split=right --focus=false --label sfy-notes -- $loop /s/notes.md" "$ls_b" \
  "$nopanes" HOME="$tmp/bare" REX_BLOCK=b1 REX_SESSION=session:1 SFY_HOME=/s
check "no viewer, panes exist, no second pair" "" "$ls_b" "$panes" HOME="$tmp/bare" REX_BLOCK=b1 REX_SESSION=session:1 SFY_HOME=/s

# block ls must never list all sessions (-A), and a failure opens no panes.
grep -q -- ' -A' "$tmp/ls" && { echo "FAIL block ls uses -A"; fail=1; }
: > "$tmp/calls"
rc=0
env -u REX_BLOCK HOME=/h PATH="$tmp/bin:$PATH" SFY_HOME=/s REX_SESSION=session:1 CALLS="$tmp/calls" \
  LS_CALLS="$tmp/ls" LS_FAIL=1 LS_JSON="$nopanes" sh "$script" show-main 2>/dev/null || rc=$?
if [ "$rc" -ne 0 ] && [ ! -s "$tmp/calls" ]; then echo "ok   block ls fails, exit $rc, no panes"; else
  echo "FAIL block ls failure: rc=$rc calls='$(cat "$tmp/calls")'"; fail=1
fi
exit $fail
