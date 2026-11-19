# Shared by install.sh and machine/install.sh. Source it with a dot.

# link SOURCE TARGET [STALE_DIR]: make TARGET a symlink to SOURCE.
# - TARGET already links to SOURCE: print "ok:" and change nothing.
# - STALE_DIR is given and TARGET is a link whose target matches */STALE_DIR/*:
#   remove it and print "removed:".
# - Anything else at TARGET moves to TARGET.bak and prints "moved:".
# Then it creates the parent folder, links, and prints "linked:".
# The body is a subshell, so no variable leaks to the caller. A failed mv or
# ln gives a non-zero status, which stops a caller that runs with set -e.
link() (
	src=$1
	dst=$2
	stale=${3:-}
	if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
		echo "ok: $dst already links to $src"
		exit 0
	fi
	if [ -n "$stale" ] && [ -L "$dst" ]; then
		case $(readlink "$dst") in
		*/"$stale"/*)
			rm "$dst"
			echo "removed: $dst pointed into $stale"
			;;
		esac
	fi
	if [ -e "$dst" ] || [ -L "$dst" ]; then
		mv "$dst" "$dst.bak"
		echo "moved: $dst to $dst.bak"
	fi
	mkdir -p "$(dirname "$dst")"
	ln -s "$src" "$dst"
	echo "linked: $dst -> $src"
)
