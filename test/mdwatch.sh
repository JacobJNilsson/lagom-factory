#!/bin/sh
# Tests bin/mdwatch with a fake glow, less, stat and stty on PATH.
# The fake stat prints the next line of $STAT_SCRIPT on each call and repeats
# the last line, so a test controls the change key per check.
# The fake less logs its arguments, copies the file it was given, stays open
# for $LESS_SECS seconds and logs "end" when nobody ended it first. An ended
# less logs no "end".
set -eu
here=$(cd "$(dirname "$0")" && pwd)
mdwatch="$here/../bin/mdwatch"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/fake" "$tmp/nogl"
printf '# hello\n' > "$tmp/doc.md"

cat > "$tmp/fake/glow" <<'STUB'
#!/bin/sh
echo "glow $*" >> "$GLOW_CALLS"
echo "GLOW-RENDER"
# Like glow, print the rendered file after the marker. glow gets the file last.
for last; do :; done
cat "$last"
STUB
cat > "$tmp/fake/less" <<'STUB'
#!/bin/sh
echo "start $*" >> "$LESS_LOG"
for last; do :; done
cat "$last" >> "$LESS_SHOWN"
trap 'exit 0' TERM
sleep "$LESS_SECS" &
wait $!
echo end >> "$LESS_LOG"
STUB
# GNU mode answers -c. BSD mode refuses -c and answers -f.
cat > "$tmp/fake/stat" <<'STUB'
#!/bin/sh
case $1 in
  -c) [ "${STAT_MODE:-gnu}" = gnu ] || exit 1; prefix=gnu ;;
  -f) prefix=bsd ;;
esac
n=$(cat "$STAT_COUNT" 2>/dev/null || echo 0)
n=$((n + 1))
echo "$n" > "$STAT_COUNT"
line=$(sed -n "${n}p" "$STAT_SCRIPT")
[ -n "$line" ] || line=$(tail -n 1 "$STAT_SCRIPT")
echo "$prefix $line"
STUB
# The fake stty answers "size" with 24 rows and the next line of $COL_SCRIPT.
cat > "$tmp/fake/stty" <<'STUB'
#!/bin/sh
n=$(cat "$COL_COUNT" 2>/dev/null || echo 0)
n=$((n + 1))
echo "$n" > "$COL_COUNT"
line=$(sed -n "${n}p" "$COL_SCRIPT")
[ -n "$line" ] || line=$(tail -n 1 "$COL_SCRIPT")
echo "24 $line"
STUB
chmod +x "$tmp/fake/glow" "$tmp/fake/less" "$tmp/fake/stat" "$tmp/fake/stty"
# A PATH with the basics but no glow.
for t in cat sleep sed tail wc pkill rm cut; do ln -s "$(command -v $t)" "$tmp/nogl/$t"; done
cp "$tmp/fake/less" "$tmp/fake/stat" "$tmp/fake/stty" "$tmp/nogl/"

fail=0
ok() { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }
# count WORD: how many less runs logged WORD at the start of a line.
count() { grep -c "^$1" "$tmp/less.log" || true; }
draws() { wc -l < "$tmp/calls" | tr -d ' '; }

# run PATH PASSES MODE STAT-LINES COLS-LINES
run() {
	: > "$tmp/calls"; : > "$tmp/less.log"; : > "$tmp/shown"
	rm -f "$tmp/scount" "$tmp/ccount"
	printf '%s\n' "$4" > "$tmp/sscript"
	printf '%s\n' "$5" > "$tmp/cscript"
	env PATH="$1" GLOW_CALLS="$tmp/calls" STAT_MODE="$3" STAT_COUNT="$tmp/scount" \
		STAT_SCRIPT="$tmp/sscript" COL_COUNT="$tmp/ccount" COL_SCRIPT="$tmp/cscript" \
		LESS_LOG="$tmp/less.log" LESS_SHOWN="$tmp/shown" LESS_SECS=2 TMPDIR="$tmp" \
		MDWATCH_TTY=/dev/null MDWATCH_INTERVAL=0.1 MDWATCH_PASSES="$2" /bin/sh "$mdwatch" "$tmp/doc.md" > "$tmp/out" 2>&1
}

fakepath="$tmp/fake:$PATH"

# An unchanged key leaves the first less open until it ends on its own.
run "$fakepath" 1 gnu "10 t" 120
[ "$(count start)" = 1 ] && [ "$(count end)" = 1 ] && ok "unchanged key keeps less open" || bad "unchanged key: $(cat "$tmp/less.log")"
[ "$(draws)" = 1 ] && ok "unchanged key renders once" || bad "unchanged key: $(draws) renders"
grep -q GLOW-RENDER "$tmp/shown" && ok "less shows the glow output" || bad "glow output missing: $(cat "$tmp/shown")"
grep -q -- '-w 120' "$tmp/calls" && ok "glow gets the pane width" || bad "glow width: $(cat "$tmp/calls")"
grep -q -- '^start -R -S -c ' "$tmp/less.log" && ok "less starts from the top with -R -S -c" || bad "less args: $(cat "$tmp/less.log")"

# A change ends the first less, and the second render shows it again.
run "$fakepath" 2 gnu "10 t
11 t" 120
[ "$(draws)" = 2 ] && [ "$(count start)" = 2 ] && [ "$(count end)" = 1 ] && ok "file change ends less and renders again" || bad "file change: $(draws) renders, $(cat "$tmp/less.log")"

# BSD stat: -c fails, -f answers.
run "$fakepath" 1 bsd "11 1767225600.5" 120
[ "$(draws)" = 1 ] && [ "$(count end)" = 1 ] && ok "BSD stat fallback gives a stable key" || bad "BSD fallback: $(cat "$tmp/less.log")"
run "$fakepath" 2 bsd "11 1767225600.5
11 1767225600.9" 120
[ "$(draws)" = 2 ] && [ "$(count end)" = 1 ] && ok "BSD stat change renders again" || bad "BSD change: $(cat "$tmp/less.log")"

# A width change ends less. The first key sees 80 columns, then 100 follow.
run "$fakepath" 2 gnu "10 t" "80
100"
[ "$(draws)" = 2 ] && [ "$(count end)" = 1 ] && ok "width change renders again" || bad "width change: $(draws) renders, $(cat "$tmp/less.log")"

# Without glow, less shows the file as it is.
run "$tmp/nogl" 1 gnu "10 t" 80
grep -q '# hello' "$tmp/shown" && ok "no glow, less shows the file" || bad "no glow: $(cat "$tmp/shown") $(cat "$tmp/out")"

# Links: a reference link and an inline link become OSC 8 hyperlinks. The URL
# text disappears and the definition line does not render. A code span, a
# fenced block and an image keep their text.
cat > "$tmp/doc.md" <<'DOC'
See [\[2\]][2] and [inline text](https://example.com/inline "title") here.
Code `[x](https://example.com/code)` stays.

```
[fenced](https://example.com/fenced)
```

[2]: https://example.com/ref
DOC
run "$fakepath" 1 gnu "10 t" 80
esc=$(printf '\033')
shown=$(sed "s/$esc\\\\/<ST>/g; s/$esc]8;;/<OSC>/g" "$tmp/shown")
case $shown in *'<OSC>https://example.com/ref<ST>\[2\]<OSC><ST>'*) ok "reference link becomes OSC 8" ;; *) bad "reference link: $shown" ;; esac
case $shown in *'<OSC>https://example.com/inline<ST>inline text<OSC><ST>'*) ok "inline link becomes OSC 8" ;; *) bad "inline link: $shown" ;; esac
visible=$(printf '%s\n' "$shown" | sed 's/<OSC>[^<]*<ST>//g')
case $visible in *example.com/ref* | *example.com/inline*) bad "URL text still visible: $visible" ;; *) ok "no visible URL text" ;; esac
case $visible in *'[2]: '*) bad "definition line rendered: $visible" ;; *) ok "definition line dropped" ;; esac
case $visible in *'`[x](https://example.com/code)`'*) ok "code span untouched" ;; *) bad "code span: $visible" ;; esac
case $visible in *'[fenced](https://example.com/fenced)'*) ok "fenced block untouched" ;; *) bad "fenced block: $visible" ;; esac

# With the real glow, a long URL must not wrap the text. The markers count as
# zero width, so the text lines match a render of the same text without links.
if command -v glow >/dev/null 2>&1; then
	mkdir "$tmp/real"
	cp "$tmp/fake/less" "$tmp/real/"
	printf 'Words fill this line up to the edge of the pane and then the link [wraps around here](https://example.com/a/very/long/url/that/is/long/enough/to/wrap/twice/over/and/over) ok.\n' > "$tmp/doc.md"
	printf 'Words fill this line up to the edge of the pane and then the link wraps around here ok.\n' > "$tmp/plain.md"
	: > "$tmp/less.log"; : > "$tmp/shown"
	env PATH="$tmp/real:$PATH" LESS_LOG="$tmp/less.log" LESS_SHOWN="$tmp/shown" LESS_SECS=0 TMPDIR="$tmp" \
		MDWATCH_TTY=/dev/null MDWATCH_PASSES=1 sh "$mdwatch" "$tmp/doc.md" > "$tmp/out" 2>&1 || true
	glow -s dark -w 80 "$tmp/plain.md" 2>/dev/null | sed "s/$esc\\[[0-9;]*m//g" | tr -s ' ' | sed 's/ $//' > "$tmp/want"
	sed "s/$esc\\[[0-9;]*m//g; s/$esc]8;;[^$esc]*$esc\\\\//g" "$tmp/shown" | tr -s ' ' | sed 's/ $//' > "$tmp/got"
	grep -q "$esc]8;;https://example.com/a/very" "$tmp/shown" && ok "real glow: hyperlink emitted" || bad "real glow: $(cat -v "$tmp/shown")"
	[ "$(wc -l < "$tmp/got")" = "$(wc -l < "$tmp/want")" ] && ok "real glow: hidden URL does not change wrapping" || bad "real glow wrap: $(cat -v "$tmp/got") / $(cat -v "$tmp/want")"
else
	echo "skip real glow test: glow unavailable"
fi

# The temp file goes away when the script ends.
ls "$tmp"/mdwatch.* >/dev/null 2>&1 && bad "temp file left behind" || ok "temp file removed"

# Background width: run in a real pty that is 113 columns wide. The watcher
# subshell must read the same width as the foreground, so a quiet file leaves
# less open. With the old tput cols the watcher saw 80 and ended less at once.
if command -v script >/dev/null 2>&1 && script -qc true /dev/null >/dev/null 2>&1; then
	mkdir "$tmp/pty"
	cp "$tmp/fake/less" "$tmp/fake/glow" "$tmp/pty/"
	: > "$tmp/less.log"; : > "$tmp/shown"; : > "$tmp/calls"
	script -qc "sh -c 'stty cols 113; env TERM=xterm PATH=\"$tmp/pty:\$PATH\" GLOW_CALLS=\"$tmp/calls\" LESS_LOG=\"$tmp/less.log\" LESS_SHOWN=\"$tmp/shown\" LESS_SECS=2 TMPDIR=\"$tmp\" MDWATCH_INTERVAL=0.1 MDWATCH_PASSES=1 sh \"$mdwatch\" \"$tmp/doc.md\"'" /dev/null > "$tmp/out" 2>&1 || true
	[ "$(count start)" = 1 ] && [ "$(count end)" = 1 ] && ok "pty: width 113 does not restart less" || bad "pty: $(cat "$tmp/less.log")"
	grep -q -- '-w 113' "$tmp/calls" && ok "pty: glow gets the real width" || bad "pty glow: $(cat "$tmp/calls")"
else
	echo "skip pty test: script -c unavailable"
fi

exit $fail
