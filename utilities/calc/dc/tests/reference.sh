#!/bin/sh
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The dc mini-dc is compared with: principia's dc.c built for this
# machine by goken's 7c and 7l, whose long has 32 bits as Plan 9's. Not
# goken's own dc (ROOT/arch/boot-gcc/bin/dc, by gcc) nor 9base's: with
# a long of 64 bits dc.c's log2_ is another number, and a fraction in
# base 16 has 11 digits for a scale of 10 where Plan 9's has 8.
#
#   reference.sh [directory]    builds directory/dc (default /tmp/ix-dc-reference)
#
# This machine must be an arm64 Linux.

T=${GOKEN:-$HOME/goken}
P=${PRINCIPIA:-$HOME/principia}
D=${1:-/tmp/ix-dc-reference}
B=$T/ROOT/arch/boot-gcc/bin
[ -x $B/7c ] && [ -f $P/utilities/calc/misc/dc.c ] && [ "$(uname -m)" = aarch64 ] || { echo "skipped: no goken, no principia or not arm64" >&2; exit 1; }
rm -rf $D && mkdir -p $D && cd $D || exit 1
cp $P/utilities/calc/misc/dc.c .
$B/7c -I$T/include -I$T/include/ALL -I$T/include/arch/arm64 -Darm64 -c dc.c > dc.log 2>&1 || { cat dc.log >&2; exit 1; }
$B/7l -H7 -L$T/ROOT/arch/arm64/lib -o dc dc.7 -lbio -lc || exit 1
echo $D/dc
