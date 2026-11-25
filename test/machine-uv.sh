#!/bin/sh
# Tests the uv install in machine/install.sh with a fake curl that serves a
# small archive. The second run must download nothing.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/bin" "$tmp/home" "$tmp/src"
fail=0
ok() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got $3, want $2"; fail=1; fi; }
version=$(sed -n 's/^UV_VERSION=//p' "$here/../machine/install.sh")

# The fake curl builds the archive or its sha256 file on request.
cat > "$tmp/bin/curl" <<FAKE
#!/bin/sh
out= url=
while [ \$# -gt 0 ]; do
  case \$1 in -o) out=\$2; shift ;; -*) ;; *) url=\$1 ;; esac
  shift
done
echo "\$url" >> "$tmp/urls"
base=\${url##*/}
case \$base in
*.sha256)
  archive=\${base%.sha256}
  if [ -n "\${BAD_SUM:-}" ]; then echo "0000000000000000000000000000000000000000000000000000000000000000  \$archive" > "\$out"; exit 0; fi
  hash=\$( (sha256sum "\$archive" 2>/dev/null || shasum -a 256 "\$archive") | cut -d' ' -f1)
  echo "\$hash  \$archive" > "\$out" ;;
*)
  dir=\${base%.tar.gz}
  mkdir -p "$tmp/src/\$dir"
  printf '#!/bin/sh\necho "uv $version"\n' > "$tmp/src/\$dir/uv"
  printf '#!/bin/sh\nexit 0\n' > "$tmp/src/\$dir/uvx"
  tar -czf "\$out" -C "$tmp/src" "\$dir" ;;
esac
FAKE
chmod +x "$tmp/bin/curl"

# The tool step needs go, so fake it with a no-op.
cat > "$tmp/bin/go" <<'FAKE'
#!/bin/sh
[ "$1 $2" = "env GOBIN" ] && echo /nowhere/bin
exit 0
FAKE
chmod +x "$tmp/bin/go"

run() { PATH="$tmp/bin:$PATH" /bin/sh "$here/../machine/install.sh" --no-skills "$@" "$tmp/home" 2>&1; }

out=$(run) && st=0 || st=$?
ok "first run exits 0" 0 $st
[ -x "$tmp/home/.local/bin/uv" ] && [ -x "$tmp/home/.local/bin/uvx" ] && r=yes || r=no
ok "uv and uvx are installed" yes $r
ok "uv mode is 755" 755 "$(stat -c %a "$tmp/home/.local/bin/uv" 2>/dev/null || stat -f %Lp "$tmp/home/.local/bin/uv")"
case $(cat "$tmp/urls") in *"/download/$version/uv-"*) r=yes ;; *) r=no ;; esac
ok "url holds the pinned version" yes $r

: > "$tmp/urls"
out=$(run) && st=0 || st=$?
ok "second run exits 0" 0 $st
ok "second run downloads nothing" 0 "$(wc -l < "$tmp/urls" | tr -d ' ')"

# --no-tools skips uv.
rm "$tmp/home/.local/bin/uv" "$tmp/home/.local/bin/uvx"
out=$(run --no-tools) && st=0 || st=$?
[ ! -e "$tmp/home/.local/bin/uv" ] && r=yes || r=no
ok "--no-tools skips uv" yes $r

# A bad checksum fails with a clear message and installs nothing.
out=$(BAD_SUM=1 run) && st=0 || st=$?
ok "bad checksum exits 1" 1 $st
case $out in *"sha256 of uv-"*"does not match"*) r=yes ;; *) r=no ;; esac
ok "bad checksum says so" yes $r
[ ! -e "$tmp/home/.local/bin/uv" ] && r=yes || r=no
ok "bad checksum installs nothing" yes $r
exit $fail
