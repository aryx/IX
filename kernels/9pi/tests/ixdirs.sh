#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# make ix's order (kernels/9pi/Makefile's IXDIRS, one directory after
# the other): each directory after those whose objects its mkfile takes
# ($B/dir/Unit.$O), unless the top mkfile's libs make them first. A
# tree built before hides a wrong order, its _mk/5-plan9 has them: make
# self-mix in GitHub's fresh tree stopped on languages/dotnet, listed
# before assembler (2026-11-03). Static, a second.
# usage: kernels/9pi/tests/ixdirs.sh
cd "$(dirname "$0")/../../.."
libs=$(sed -n '/^LIBS=/,/[^\\]$/p' mkfile | sed 's/^LIBS=//; s/\\$//; s/\${[^}]*}//g')
# (the rule in a makefile of its own beside the Makefile: not --eval,
# which GNU make 3.81, macOS's, does not have)
W=$(mktemp -d); trap 'rm -rf $W' EXIT
printf 'ixdirs: ; @echo $(IXDIRS)\n' > $W/ixdirs.mk
dirs=$(make -s --no-print-directory -C kernels/9pi -f Makefile -f $W/ixdirs.mk ixdirs)
[ -n "$dirs" ] || { echo "FAIL no IXDIRS read in kernels/9pi/Makefile"; exit 1; }
made=" $libs "; bad=0
for d in $dirs; do
  for u in $(grep -ho '\$B/[A-Za-z0-9_/]*/[A-Za-z0-9_]*\.\$O' $d/mkfile | sed 's|^\$B/||; s|/[^/]*$||' | sort -u); do
    [ "$u" = "$d" ] && continue
    case "$made" in *" $u "*) ;; *) echo "FAIL $d takes $u's objects, made after it (or never)"; bad=1;; esac
  done
  made="$made$d "
done
[ $bad = 0 ] && echo "ok make ix's order: $(echo $dirs | wc -w | tr -d " ") directories, each after those whose objects it takes"
exit $bad
