#!/bin/sh
# Install lagom-factory's commands and machine settings. Safe to run twice.
# Usage: ./install.sh [--factory NAME] [--factories DIR] [home]   (home defaults to $HOME)
#
# It links bin/lfy, bin/mdwatch, bin/sfy-rex and bin/lagom-trust into
# <home>/.local/bin and machine/rex.toml into <home>/.sfy/config.d. It links no
# config.toml and no prompt into <home>/.sfy. lfy links defaults/ into the
# factory folder of each lagom factory.
#
# The mode --factory NAME stays until the migration to lfy ends. It installs
# into <home>/.sfy/factories/NAME the shared prompts, then NAME/prompts on top
# (a file with the same name replaces the shared one), and NAME/config.toml
# when that exists.
#
# The factory folder NAME is looked up in this order:
#   1. DIR/NAME, where DIR is the --factories value, else $LFY_FACTORIES
#   2. <repo>/factories/NAME
# The flag wins over the variable. The variable is ignored without --factory.
set -eu

repo=$(cd "$(dirname "$0")" && pwd)
. "$repo/lib/link.sh"
usage="usage: install.sh [--factory NAME] [--factories DIR] [home]"
factory=
dir=
home=
home_set=
while [ $# -gt 0 ]; do
	case "$1" in
	--factory | --factories)
		[ -n "${2:-}" ] || {
			echo "$usage" >&2
			exit 2
		}
		if [ "$1" = "--factory" ]; then factory=$2; else dir=$2; fi
		shift 2
		;;
	-*)
		echo "$usage" >&2
		exit 2
		;;
	*)
		[ -z "$home_set" ] || {
			echo "$usage" >&2
			exit 2
		}
		home=$1
		home_set=1
		shift
		;;
	esac
done
home=${home:-$HOME}

if [ -n "$dir" ] && [ -z "$factory" ]; then
	echo "install.sh: --factories needs --factory" >&2
	exit 2
fi
if [ -n "$factory" ]; then
	dir=${dir:-${LFY_FACTORIES:-}}
	if [ -n "$dir" ]; then
		[ -d "$dir" ] || {
			echo "install.sh: no folder $dir" >&2
			exit 2
		}
		dir=$(cd "$dir" && pwd)
	fi
	if [ -n "$dir" ] && [ -d "$dir/$factory" ]; then
		src="$dir/$factory"
	elif [ -d "$repo/factories/$factory" ]; then
		src="$repo/factories/$factory"
	else
		where="$repo/factories"
		[ -z "$dir" ] || where="$dir or $where"
		echo "install.sh: no factory $factory in $where" >&2
		exit 2
	fi
	state="$home/.sfy/factories/$factory"
	overlay="$src/prompts"
else
	state="$home/.sfy"
	overlay=
fi

if [ -n "$factory" ] && [ -e "$src/config.toml" ]; then
	link "$src/config.toml" "$state/config.toml"
fi

link "$repo/bin/lfy" "$home/.local/bin/lfy"
link "$repo/bin/mdwatch" "$home/.local/bin/mdwatch"
link "$repo/bin/sfy-rex" "$home/.local/bin/sfy-rex"
link "$repo/bin/lagom-trust" "$home/.local/bin/lagom-trust"
# The Rex templates are machine settings. They stay in ~/.sfy, which sfy reads
# as the farthest override of every factory.
link "$repo/machine/rex.toml" "$home/.sfy/config.d/50-lagom-rex.toml"

# The lagom defaults reach a factory through lfy, which links defaults/ into the
# factory folder. Only --factory installs prompts here.
[ -n "$factory" ] || exit 0

# Each prompts/<kind>.d folder becomes a real folder of file links, so that
# prompts/shared/*.md can reach several kinds. Kinds that get the shared files:
shared_kinds="worker reviewer"

# Kinds from the base set, then kinds only the factory set has.
kinds=
for dir in "$repo"/prompts/*.d "$overlay"/*.d; do
	[ -d "$dir" ] || continue
	k=$(basename "$dir" .d)
	case " $kinds " in
	*" $k "*) ;;
	*) kinds="$kinds $k" ;;
	esac
done

for kind in $kinds; do
	target="$state/prompts/$kind.d"
	# An old install linked the whole folder. Replace that link with a folder.
	if [ -L "$target" ]; then
		mv "$target" "$target.bak"
		echo "moved: $target to $target.bak"
	fi
	mkdir -p "$target"
	# The factory's file replaces a base or shared file of the same name.
	for file in "$repo/prompts/$kind.d"/*.md; do
		[ -e "$file" ] || continue
		[ -n "$overlay" ] && [ -e "$overlay/$kind.d/$(basename "$file")" ] && continue
		# A link in defaults to a shared file gets its link from the loop below.
		[ -L "$file" ] && continue
		link "$file" "$target/$(basename "$file")"
	done
	case " $shared_kinds " in
	*" $kind "*)
		for file in "$repo"/prompts/shared/*.md; do
			[ -e "$file" ] || continue
			[ -n "$overlay" ] && [ -e "$overlay/$kind.d/$(basename "$file")" ] && continue
			link "$file" "$target/$(basename "$file")"
		done
		;;
	esac
	if [ -n "$overlay" ]; then
		for file in "$overlay/$kind.d"/*.md; do
			[ -e "$file" ] || continue
			link "$file" "$target/$(basename "$file")"
		done
	fi
done
