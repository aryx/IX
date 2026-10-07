#!/bin/sh
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The awk mini-awk is compared with: principia's own (utilities/text/awk,
# 9front's, which counts characters, not bytes), built for this machine
# by goken's 7c and 7l with goken's libc. No awk at hand is it: goken's
# awk_buggy is the 1999 one over stdio, 9base's counts bytes, and
# principia's arm binary computes with the FPA, which mini-5i has not.
# Four things goken's libc lacks are principia's (lrand.c and frand.c,
# runetype.c for toupper, a truerand of the time), and main.c's call to
# the floating point's control register is left out.
#
#   reference.sh [directory]    builds directory/awk (default /tmp/ix-awk-reference)
#
# What is not as on Plan 9, and so not in the corpus: %x %o %u (goken's
# print takes the u for the conversion), rand() (frand compiled without
# lrand's type), an integer past 2^53 printed (its print's digits).
# This machine must be an arm64 Linux.

T=${GOKEN:-$HOME/goken}
P=${PRINCIPIA:-$HOME/principia}
D=${1:-/tmp/ix-awk-reference}
B=$T/ROOT/arch/boot-gcc/bin
[ -x $B/7c ] && [ -d $P/utilities/text/awk ] && [ "$(uname -m)" = aarch64 ] || { echo "skipped: no goken, no principia or not arm64" >&2; exit 1; }
rm -rf $D && mkdir -p $D && cd $D || exit 1
cp $P/utilities/text/awk/*.[chy] .
cp $P/lib_core/libc/port/frand.c $P/lib_core/libc/port/lrand.c $P/lib_core/libc/port/runetype.c $P/lib_core/libc/port/runetypebody-6.2.0.h $P/lib_core/libc/port/runebsearch.c .
# goken's libc.h has ctype's macros
: > ctype.h
python3 - <<'PY'
s = open('main.c').read()
open('main.c', 'w').write(s.replace("setfcr(getfcr() & ~FPINVAL);", "/* setfcr */"))
PY
printf '#include <u.h>\n#include <libc.h>\nulong truerand(void) { return (ulong)time(0); }\n' > truerand.c
objs=
for f in re lex main parse proctab tran lib run y.tab popen frand lrand runetype runebsearch truerand; do
  $B/7c -I. -I$T/include -I$T/include/ALL -I$T/include/arch/arm64 -Darm64 -c $f.c > $f.log 2>&1 || { cat $f.log >&2; exit 1; }
  objs="$objs $f.7"
done
$B/7l -H7 -L$T/ROOT/arch/arm64/lib -o awk $objs -lbio -lregexp -lc || exit 1
echo $D/awk
