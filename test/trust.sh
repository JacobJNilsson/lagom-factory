#!/bin/sh
# Tests bin/lagom-trust. The detector runs on the screens in
# test/fixtures/trust. pending and accept run against a fake rex and a fake
# tmux that print a screen per agent and record their calls. sync and add run
# against a scratch config file in a temporary folder, never the real one.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
script=$here/../bin/lagom-trust
screens=$here/fixtures/trust
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/bin" "$tmp/screen" "$tmp/home"

fail=0
ok() { echo "ok   $1"; }
bad() {
  echo "FAIL $1"
  fail=1
}

# The fakes print $SCREENS/<agent> for a capture and record every call. rex
# names the agent with -w, tmux with -t =<agent>:.
cat >"$tmp/bin/rex" <<'STUB'
#!/bin/sh
echo "rex $*" >>"$CALLS"
w=
while [ $# -gt 0 ]; do [ "$1" = -w ] && w=$2; shift; done
cat "$SCREENS/$w" 2>/dev/null || { echo "not found" >&2; exit 1; }
STUB
cat >"$tmp/bin/tmux" <<'STUB'
#!/bin/sh
echo "tmux $*" >>"$CALLS"
t=
while [ $# -gt 0 ]; do [ "$1" = -t ] && t=$2; shift; done
t=${t#=}
t=${t%:}
cat "$SCREENS/$t" 2>/dev/null || { echo "can't find session: $t" >&2; exit 1; }
STUB
chmod +x "$tmp/bin/rex" "$tmp/bin/tmux"

# run DESCRIPTION EXPECTED-RC EXPECTED-CALLS ARGS...: run the script with the
# fakes and check the exit code and the recorded calls. Stdout goes to
# $tmp/out.
run() {
  desc=$1 wantrc=$2 want=$3
  shift 3
  : >"$tmp/calls"
  rc=0
  CALLS="$tmp/calls" SCREENS="$tmp/screen" SFY_HOME="$sfy_home" HOME="$tmp/home" \
    PATH="$tmp/bin:$PATH" sh "$script" "$@" >"$tmp/out" 2>"$tmp/err" || rc=$?
  got=$(cat "$tmp/calls")
  if [ "$rc" = "$wantrc" ] && [ "$got" = "$want" ]; then
    ok "$desc"
  else
    bad "$desc: rc=$rc calls '$got' err '$(cat "$tmp/err")'"
  fi
}

# expect_out DESCRIPTION WANT: compare the stdout of the last run.
expect_out() {
  got=$(cat "$tmp/out")
  if [ "$got" = "$2" ]; then ok "$1"; else bad "$1: got '$got'"; fi
}

# --- detect

detect_case() {
  desc=$1 file=$2 wantrc=$3 want=$4
  rc=0
  got=$(sh "$script" detect <"$file") || rc=$?
  if [ "$rc" = "$wantrc" ] && [ "$got" = "$want" ]; then ok "$desc"; else bad "$desc: rc=$rc got '$got'"; fi
}
detect_case "detect the newer dialog" "$screens/dialog.txt" 0 /home/user/src/example-repo
detect_case "detect the older dialog, folder with a space" "$screens/dialog-old.txt" 0 "/home/user/src/other repo"
detect_case "no dialog at the prompt" "$screens/prompt.txt" 1 ""
detect_case "no dialog with the cursor on No" "$screens/dialog-cursor-no.txt" 1 ""
{
  cat "$screens/dialog.txt"
  i=0
  while [ $i -lt 45 ]; do
    echo "output line $i"
    i=$((i + 1))
  done
} >"$tmp/scrolled.txt"
detect_case "no dialog once it scrolled away" "$tmp/scrolled.txt" 1 ""
{
  cat "$screens/dialog.txt"
  printf '\n\n\n'
} >"$tmp/blank-tail.txt"
detect_case "trailing blank lines do not hide the dialog" "$tmp/blank-tail.txt" 0 /home/user/src/example-repo

# --- pending and accept

sfy_home=$tmp/factory
mkdir -p "$sfy_home/sessions/worker-t1" "$sfy_home/sessions/review-t2-1" \
  "$sfy_home/sessions/worker-t3" "$sfy_home/sessions/main"
cp "$screens/dialog.txt" "$tmp/screen/worker-t1"
cp "$screens/dialog-old.txt" "$tmp/screen/review-t2-1"
cp "$screens/prompt.txt" "$tmp/screen/worker-t3"
# The main agent's pane shows a dialog too. pending and accept leave it alone.
cp "$screens/dialog.txt" "$tmp/screen/main"

cap() { echo "rex --autostart=false capture -s sfy-agents -w $1 --unwrap --trim"; }
all_caps="$(cap review-t2-1)
$(cap worker-t1)
$(cap worker-t3)"

run "pending lists the agents with a dialog" 0 "$all_caps" pending
expect_out "pending text output" "review-t2-1	/home/user/src/other repo
worker-t1	/home/user/src/example-repo"
run "pending --json" 0 "$all_caps" pending --json
expect_out "pending JSON output" '[{"agent":"review-t2-1","folder":"/home/user/src/other repo"},{"agent":"worker-t1","folder":"/home/user/src/example-repo"}]'

rm "$tmp/screen/worker-t1" "$tmp/screen/review-t2-1"
run "pending with no dialog" 0 "$all_caps" pending --json
expect_out "pending JSON with no dialog" '[]'
run "pending text with no dialog" 0 "$all_caps" pending
expect_out "pending text with no dialog prints nothing" ""
cp "$screens/dialog.txt" "$tmp/screen/worker-t1"

run "accept sends one enter" 0 "$(cap worker-t1)
rex --autostart=false send-key -s sfy-agents -w worker-t1 enter" accept worker-t1 /home/user/src/example-repo
run "accept refused when the folder differs" 1 "$(cap worker-t1)" accept worker-t1 /home/user/src/other-repo
cp "$screens/prompt.txt" "$tmp/screen/worker-t1"
run "accept refused when the dialog is gone" 1 "$(cap worker-t1)" accept worker-t1 /home/user/src/example-repo
cp "$screens/dialog-cursor-no.txt" "$tmp/screen/worker-t1"
run "accept refused with the cursor on No" 1 "$(cap worker-t1)" accept worker-t1 /home/user/src/example-repo
run "accept refused for an unknown agent" 2 "" accept worker-t99 /home/user/src/example-repo
run "accept refused for the main agent" 2 "" accept main /home/user/src/example-repo
rm "$tmp/screen/worker-t1"
run "accept fails when the pane is missing" 3 "$(cap worker-t1)" accept worker-t1 /home/user/src/example-repo
run "accept needs two arguments" 64 "" accept worker-t1

# A state folder prefix picks the Rex session the way bin/sfy-rex does.
mkdir "$sfy_home/sessions/work-worker-t5"
cp "$screens/dialog.txt" "$tmp/screen/work-worker-t5"
run "accept finds a prefixed window in <prefix>agents" 0 "rex --autostart=false capture -s work-agents -w work-worker-t5 --unwrap --trim
rex --autostart=false send-key -s work-agents -w work-worker-t5 enter" accept work-worker-t5 /home/user/src/example-repo
rm -r "$sfy_home/sessions/work-worker-t5"

# tmux, picked by flag and by the factory config.toml.
cp "$screens/dialog.txt" "$tmp/screen/worker-t1"
run "tmux accept by flag" 0 "tmux capture-pane -p -J -t =worker-t1:
tmux send-keys -t =worker-t1: Enter" accept worker-t1 /home/user/src/example-repo --multiplexer tmux
printf 'multiplexer = "tmux"\n' >"$sfy_home/config.toml"
run "tmux pending from config.toml" 0 "tmux capture-pane -p -J -t =review-t2-1:
tmux capture-pane -p -J -t =worker-t1:
tmux capture-pane -p -J -t =worker-t3:" pending --json
expect_out "tmux pending JSON" '[{"agent":"worker-t1","folder":"/home/user/src/example-repo"}]'
cp "$screens/prompt.txt" "$tmp/screen/worker-t1"
run "tmux accept refused when the dialog is gone" 1 "tmux capture-pane -p -J -t =worker-t1:" accept worker-t1 /home/user/src/example-repo
rm "$sfy_home/config.toml"

# The Rex session rule must match bin/sfy-rex. Its start subcommand names the
# session in its first call.
for n in worker-t1 review-t2-1 work-worker-t3 a-b-review-t4-2; do
  : >"$tmp/calls"
  CALLS="$tmp/calls" PATH="$tmp/bin:$PATH" TMPDIR="$tmp" sh "$here/../bin/sfy-rex" start "$n" /d true >/dev/null 2>&1 || true
  rex_session=$(sed -n '1s/^rex window ls -s //p' "$tmp/calls")
  mkdir -p "$sfy_home/sessions/$n"
  cp "$screens/prompt.txt" "$tmp/screen/$n"
  : >"$tmp/calls"
  CALLS="$tmp/calls" SCREENS="$tmp/screen" SFY_HOME="$sfy_home" HOME="$tmp/home" PATH="$tmp/bin:$PATH" \
    sh "$script" accept "$n" /x >/dev/null 2>&1 || true
  ours=$(sed -n 's/^rex --autostart=false capture -s \([^ ]*\) .*/\1/p' "$tmp/calls")
  if [ -n "$rex_session" ] && [ "$rex_session" = "$ours" ]; then
    ok "session of $n matches sfy-rex ($ours)"
  else
    bad "session of $n: sfy-rex '$rex_session', lagom-trust '$ours'"
  fi
done

# --- sync and add

# The scratch file is not named .claude.json, so no test can touch the real one.
cfg=$tmp/scratch-config.json
git_q() { git -c user.name=t -c user.email=t@example.com -c init.defaultBranch=main "$@" >/dev/null 2>&1; }
src=$tmp/src/app
mkdir -p "$src"
git_q -C "$src" init
git_q -C "$src" commit --allow-empty -m init
src=$(cd "$src" && pwd -P)
sfy_home=$tmp/factory2
mkdir -p "$sfy_home/work" "$sfy_home/repos" "$sfy_home/tasks/t1" "$sfy_home/tasks/t2" "$sfy_home/tasks/t3"
git_q -C "$src" worktree add "$sfy_home/work/t1" -b task-t1
mkdir "$sfy_home/work/t2"
clone=$sfy_home/repos/lib-0a1b2c
git_q clone "$src" "$clone"
other=$tmp/src/other
mkdir -p "$other/sub"
git_q -C "$other" init
other=$(cd "$other" && pwd -P)
printf '# A task\n\n## Repo\n\n%s\n\n## Type\n\nfeat\n' "$other/sub" >"$sfy_home/tasks/t1/task.md"
printf '# Gone\n\n## Repo\n\n%s\n' "$tmp/src/gone" >"$sfy_home/tasks/t2/task.md"
printf '# Research\n\nNo repo.\n' >"$sfy_home/tasks/t3/task.md"
work=$(cd "$sfy_home/work" && pwd -P)
clone=$(cd "$clone" && pwd -P)

cat >"$cfg" <<'JSON'
{
  "numStartups": 12,
  "projects": {
    "/kept/project": {
      "allowedTools": [],
      "hasTrustDialogAccepted": false
    }
  },
  "theme": "dark"
}
JSON
chmod 600 "$cfg"

# sync_run DESCRIPTION EXPECTED-RC ARGS...: run with the factory and the scratch config.
sync_run() {
  desc=$1 wantrc=$2
  shift 2
  rc=0
  SFY_HOME="$sfy_home" HOME="$tmp/home" sh "$script" "$@" >"$tmp/out" 2>"$tmp/err" || rc=$?
  if [ "$rc" = "$wantrc" ]; then ok "$desc"; else bad "$desc: rc=$rc err '$(cat "$tmp/err")'"; fi
}

sync_run "sync" 0 sync --config "$cfg"
trusted=$(jq -r '.projects | to_entries[] | select(.value.hasTrustDialogAccepted == true) | .key' "$cfg" | sort)
want=$(printf '%s\n' "$clone" "$other" "$src" "$work" | sort)
if [ "$trusted" = "$want" ]; then ok "sync trusts the task repo, the clone, the worktree's checkout and work"; else bad "sync trusted '$trusted', want '$want'"; fi
if jq -e '.numStartups == 12 and .theme == "dark" and .projects["/kept/project"] == {"allowedTools": [], "hasTrustDialogAccepted": false}' "$cfg" >/dev/null; then
  ok "sync keeps every other key"
else
  bad "sync lost a key: $(cat "$cfg")"
fi
if grep -q "skipped $tmp/src/gone" "$tmp/err"; then ok "sync notes a Repo that is gone"; else bad "sync did not note the missing Repo: $(cat "$tmp/err")"; fi
mode=$(ls -l "$cfg" | cut -c1-10)
if [ "$mode" = "-rw-------" ]; then ok "sync keeps the file mode"; else bad "sync changed the mode to $mode"; fi
if ls "$tmp" | grep -q lagom-trust; then bad "sync left a temporary file"; else ok "sync leaves no temporary file"; fi

before=$(cksum <"$cfg")
sync_run "sync again" 0 sync --config "$cfg"
if [ "$(cksum <"$cfg")" = "$before" ] && ! grep -q '^trusted:' "$tmp/out"; then ok "sync is idempotent"; else bad "second sync changed the file"; fi

new=$tmp/src/new
mkdir -p "$new"
git_q -C "$new" init
new=$(cd "$new" && pwd -P)
LAGOM_TRUST_CONFIG=$cfg sync_run "add by env" 0 add "$new"
if jq -e --arg p "$new" '.projects[$p].hasTrustDialogAccepted == true and .numStartups == 12' "$cfg" >/dev/null; then ok "add trusts one repo"; else bad "add did not trust $new"; fi
sync_run "add a worktree" 0 add "$sfy_home/work/t1" --config "$cfg"
expect_out "add a worktree marks its main checkout" "ok: $src is trusted"

missing=$tmp/new-dir/scratch.json
sync_run "add creates a missing config" 0 add "$new" --config "$missing"
if jq -e --arg p "$new" '.projects[$p].hasTrustDialogAccepted == true' "$missing" >/dev/null; then ok "add writes a new config"; else bad "new config: $(cat "$missing")"; fi

printf '{ not json' >"$tmp/broken.json"
sync_run "add refuses a broken config" 1 add "$new" --config "$tmp/broken.json"
if [ "$(cat "$tmp/broken.json")" = "{ not json" ]; then ok "add leaves a broken config as it was"; else bad "add changed the broken config"; fi
sync_run "add refuses a missing folder" 1 add "$tmp/nothing" --config "$cfg"
sfy_home=$tmp/no-factory
sync_run "sync needs SFY_HOME to exist" 64 sync --config "$cfg"

exit $fail
