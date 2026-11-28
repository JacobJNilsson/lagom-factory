#!/bin/sh
# Runs bin/sfy-rex against a fake rex that records its calls. Checks that lead,
# main and sfy (also with a state folder prefix) keep their own session, that
# every other name goes to a window in <prefix>agents (sfy-agents without a
# prefix), that a lead pane address reaches only that pane, how alive maps
# replies to exit codes, that escape refuses sfy and a session address, and how the script
# finds rex, including which.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
script=$here/../bin/sfy-rex
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/bin" "$tmp/empty" "$tmp/home"

cat > "$tmp/bin/rex" <<'STUB'
#!/bin/sh
echo "$*" >> "$CALLS"
case "$*" in
  "window ls "*) exit "${WINDOW_LS_RC:-0}" ;;
  *"block call "*) printf '%s\n' "${BLOCK_OUT:-}"; exit "${BLOCK_RC:-0}" ;;
  *"block ls "*) printf '%s\n' "${BLOCK_LS_OUT:-}"; exit "${BLOCK_LS_RC:-0}" ;;
esac
STUB
chmod +x "$tmp/bin/rex"

fail=0
# run DESCRIPTION EXPECTED-CALLS EXPECTED-RC SUBCOMMAND ARGS...
run() {
  desc=$1 want=$2 wantrc=$3
  shift 3
  : > "$tmp/calls"
  rc=0
  CALLS="$tmp/calls" HOME="$tmp/home" PATH="$tmp/bin:$PATH" sh "$script" "$@" >/dev/null 2>&1 || rc=$?
  got=$(cat "$tmp/calls")
  if [ "$got" = "$want" ] && [ "$rc" = "$wantrc" ]; then
    echo "ok   $desc"
  else
    echo "FAIL $desc: rc=$rc got '$got'"; fail=1
  fi
}

live=$(cat "$here/process-live.json")
dead=$(cat "$here/process-dead.json")
missing=$(cat "$here/process-missing.txt")

for n in lead main sfy carboncloud-lead work-main work-sfy; do
  run "start $n" "new $n -c /work/d --keep-open -- echo hi" 0 start $n /work/d echo hi
  run "send $n" "send -s $n -- hello
send-key -s $n enter" 0 send $n hello
  BLOCK_OUT=$live run "alive $n" "--autostart=false block call -s $n process" 0 alive $n
  run "stop $n" "--autostart=false kill $n" 0 stop $n
done

for n in worker-t48 review-t48-2 mainframe sfyx; do
  run "start $n" "window ls -s sfy-agents
window new -s sfy-agents $n -c /work/d --keep-open --focus=false -- echo hi" 0 start $n /work/d echo hi
  run "send $n" "send -s sfy-agents -w $n -- hello
send-key -s sfy-agents -w $n enter" 0 send $n hello
  BLOCK_OUT=$live run "alive $n" "--autostart=false block call -s sfy-agents -w $n process" 0 alive $n
  run "stop $n" "--autostart=false window close -s sfy-agents $n" 0 stop $n
done

# A state folder prefix selects the agents session <prefix>agents. Start, send,
# alive and stop all use it.
for n in work-worker-t3 work-review-t3-1; do
  run "start $n" "window ls -s work-agents
window new -s work-agents $n -c /work/d --keep-open --focus=false -- echo hi" 0 start $n /work/d echo hi
  run "send $n" "send -s work-agents -w $n -- hello
send-key -s work-agents -w $n enter" 0 send $n hello
  BLOCK_OUT=$live run "alive $n" "--autostart=false block call -s work-agents -w $n process" 0 alive $n
  run "stop $n" "--autostart=false window close -s work-agents $n" 0 stop $n
done
WINDOW_LS_RC=1 run "start creates the prefixed session" "window ls -s demo-agents
new demo-agents -c /work/d -- tail -f /dev/null
window new -s demo-agents demo-worker-t1 -c /work/d --keep-open --focus=false -- echo hi" 0 start demo-worker-t1 /work/d echo hi

# sfy passes the lead as a session address. Send, alive and stop treat it
# as a session. Start never gets it, so start treats it as a worker name.
a=session:01a1e3e3-ebe3-7271-80b2-45819d15a708
run "send $a" "send -s $a -- hello
send-key -s $a enter" 0 send $a hello
BLOCK_OUT=$live run "alive $a" "--autostart=false block call -s $a process" 0 alive $a

# An old factory may still hold a session address. Stop kills that session
# only when it holds one pane, the lead's. A session with more panes may be the
# operator's own, so stop leaves it running and exits 1 with a message.
ls_call="--autostart=false block ls -s $a -q"
BLOCK_LS_OUT=block:01 run "stop $a: one pane" "$ls_call
--autostart=false kill $a" 0 stop $a
BLOCK_LS_OUT='block:01
block:02
block:03' run "stop $a: three panes" "$ls_call" 1 stop $a
BLOCK_LS_OUT='' run "stop $a: no pane" "$ls_call" 1 stop $a
BLOCK_LS_RC=1 BLOCK_LS_OUT=block:01 run "stop $a: block ls fails" "$ls_call" 1 stop $a
rc=0
err=$(CALLS="$tmp/calls" HOME="$tmp/home" PATH="$tmp/bin:$PATH" BLOCK_LS_OUT='block:01
block:02' sh "$script" stop $a 2>&1) || rc=$?
if [ "$rc" = 1 ] && [ "$err" = "sfy-rex stop: $a holds other panes, so stop leaves it running" ]; then
  echo "ok   stop $a: message for a shared session"; else
  echo "FAIL stop $a message: rc=$rc '$err'"; fail=1; fi

# sfy passes the lead as a pane address when whoami saw $REX_BLOCK. Send and
# alive reach that pane with -b, whatever pane the operator focuses. Stop
# closes only that pane and never kills the session that holds it.
b=block:02b2f4f4-fcf4-8382-91c3-56920e26b819
run "send $b" "send -b $b -- hello
send-key -b $b enter" 0 send $b hello
BLOCK_OUT=$live run "alive $b" "--autostart=false block call -b $b process" 0 alive $b
blockmissing=$(cat "$here/process-block-missing.txt")
BLOCK_OUT=$blockmissing BLOCK_RC=1 run "alive $b: pane closed" "--autostart=false block call -b $b process" 1 alive $b
run "stop $b closes only the pane" "--autostart=false block close $b" 0 stop $b

# escape presses only Escape, in a worker or reviewer window or in the lead's
# pane. It refuses the sfy process and a session address with exit 64 and
# calls no rex, because a session may hold other panes.
run "escape worker-t3" "--autostart=false send-key -s sfy-agents -w worker-t3 escape" 0 escape worker-t3
run "escape work-review-t3-1" "--autostart=false send-key -s work-agents -w work-review-t3-1 escape" 0 escape work-review-t3-1
for n in lead carboncloud-lead main work-main; do
  run "escape $n" "--autostart=false send-key -s $n escape" 0 escape $n
done
run "escape $b" "--autostart=false send-key -b $b escape" 0 escape $b
for n in sfy work-sfy $a; do
  run "escape $n is refused" "" 64 escape "$n"
done

# The first worker creates the shared session before its window.
WINDOW_LS_RC=1 run "start creates the session" "window ls -s sfy-agents
new sfy-agents -c /work/d -- tail -f /dev/null
window new -s sfy-agents worker-t1 -c /work/d --keep-open --focus=false -- echo hi" 0 start worker-t1 /work/d echo hi

# Alive maps the saved rex replies to exit codes. A live window has both a
# null last_exit and a child. A dead window kept open has a last_exit object.
call="--autostart=false block call -s sfy-agents -w worker-t1 process"
BLOCK_OUT=$live run "alive: live child" "$call" 0 alive worker-t1
BLOCK_OUT=$dead run "alive: last_exit, no child" "$call" 1 alive worker-t1
BLOCK_OUT=$missing BLOCK_RC=1 run "alive: window not found" "$call" 1 alive worker-t1
BLOCK_OUT='{"child":null}' run "alive: null child" "$call" 1 alive worker-t1
BLOCK_OUT='{"home":"/home/user"}' run "alive: unknown reply" "$call" 2 alive worker-t1
BLOCK_OUT='' run "alive: empty reply" "$call" 2 alive worker-t1
BLOCK_OUT='boom' BLOCK_RC=1 run "alive: rex error" "$call" 2 alive worker-t1

# whoami prints the pane when Rex sets $REX_BLOCK, else the session, else
# nothing. It needs no rex.
got=$(REX_BLOCK=block:42 REX_SESSION=session:42 PATH="$tmp/empty" HOME="$tmp/home" /bin/sh "$script" whoami)
if [ "$got" = block:42 ]; then echo "ok   whoami prints REX_BLOCK"; else echo "FAIL whoami with REX_BLOCK: '$got'"; fail=1; fi
got=$(unset REX_BLOCK; REX_SESSION=session:42 PATH="$tmp/empty" HOME="$tmp/home" /bin/sh "$script" whoami)
if [ "$got" = session:42 ]; then echo "ok   whoami without REX_BLOCK prints REX_SESSION"; else echo "FAIL whoami with REX_SESSION: '$got'"; fail=1; fi
got=$(unset REX_BLOCK REX_SESSION; PATH="$tmp/empty" HOME="$tmp/home" /bin/sh "$script" whoami)
if [ -z "$got" ]; then echo "ok   whoami without Rex prints nothing"; else echo "FAIL whoami without Rex: '$got'"; fail=1; fi

# Rex lookup: the PATH wins. Without it the script uses the Mac app bundle
# under $HOME. With neither it prints a clear error and exits 127.
mac="$tmp/home/Library/Application Support/com.superlogical.rex/RexServer/Versions/Current/Rex Server.app/Contents/MacOS"
mkdir -p "$mac"
printf '#!/bin/sh\necho mac >> "$CALLS"\n' > "$mac/rex"
chmod +x "$mac/rex"
: > "$tmp/calls"
CALLS="$tmp/calls" PATH="$tmp/empty" HOME="$tmp/home" /bin/sh "$script" stop main
if [ "$(cat "$tmp/calls")" = mac ]; then echo "ok   rex falls back to the Mac app bundle"; else
  echo "FAIL Mac fallback: '$(cat "$tmp/calls")'"; fail=1; fi
# which prints the path that the lookup finds.
got=$(PATH="$tmp/bin" HOME="$tmp/home" /bin/sh "$script" which)
if [ "$got" = "$tmp/bin/rex" ]; then echo "ok   which prints the rex on the PATH"; else
  echo "FAIL which on PATH: '$got'"; fail=1; fi
got=$(PATH="$tmp/empty" HOME="$tmp/home" /bin/sh "$script" which)
if [ "$got" = "$mac/rex" ]; then echo "ok   which prints the Mac app bundle path"; else
  echo "FAIL which bundle: '$got'"; fail=1; fi
rm "$mac/rex"
rc=0
err=$(PATH="$tmp/empty" HOME="$tmp/home" /bin/sh "$script" which 2>&1) || rc=$?
if [ "$rc" = 127 ] && [ "$err" = "sfy-rex: rex not found; install it or add it to PATH" ]; then
  echo "ok   which without rex exits 127 with a clear message"; else
  echo "FAIL which without rex: rc=$rc '$err'"; fail=1; fi
rc=0
err=$(PATH="$tmp/empty" HOME="$tmp/home" /bin/sh "$script" stop main 2>&1) || rc=$?
if [ "$rc" = 127 ] && [ "$err" = "sfy-rex: rex not found; install it or add it to PATH" ]; then
  echo "ok   missing rex exits 127 with a clear message"; else
  echo "FAIL missing rex: rc=$rc '$err'"; fail=1; fi
exit $fail
