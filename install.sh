#!/bin/sh
# Install lagom-factory's commands and machine settings. Safe to run twice.
# Usage: ./install.sh [home]   (home defaults to $HOME)
#
# It links bin/lfy, bin/mdwatch, bin/sfy-rex and bin/lagom-trust into
# <home>/.local/bin and machine/rex.toml into <home>/.sfy/config.d. It links no
# config.toml and no prompt into <home>/.sfy. lfy links defaults/ into the
# factory folder of each lagom factory.
set -eu

repo=$(cd "$(dirname "$0")" && pwd)
. "$repo/lib/link.sh"
usage="usage: install.sh [home]"
case "${1:-}" in
-*)
	echo "$usage" >&2
	exit 2
	;;
esac
[ $# -le 1 ] || {
	echo "$usage" >&2
	exit 2
}
home=${1:-$HOME}

link "$repo/bin/lfy" "$home/.local/bin/lfy"
link "$repo/bin/mdwatch" "$home/.local/bin/mdwatch"
link "$repo/bin/sfy-rex" "$home/.local/bin/sfy-rex"
link "$repo/bin/lagom-trust" "$home/.local/bin/lagom-trust"
# The Rex templates are machine settings. They stay in ~/.sfy, which sfy reads
# as the farthest override of every factory.
link "$repo/machine/rex.toml" "$home/.sfy/config.d/50-lagom-rex.toml"
