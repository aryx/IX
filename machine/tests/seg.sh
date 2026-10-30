#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-5i's segments (segattach, segdetach, segfree, segflush): plan9/
# seg.c, built against _mk/5-plan9's libc (mini-mk O=5 OS=plan9 in
# lib_core), writes a function's instructions in a segment it attached,
# flushes, calls it, writes others there and flushes again: the call
# runs the new ones, mini-5i's decoded instructions dropped at segflush.
# usage: machine/tests/seg.sh

ROOT=$(cd $(dirname $0)/../.. && pwd)
IX=$ROOT/_build/default
M=$ROOT/_mk/5-plan9
L=$ROOT/lib_core/libc
W=$(mktemp -d)
trap 'rm -rf $W' EXIT
[ -f $M/lib_core/libc.a ] || { echo "skipped: no _mk/5-plan9/lib_core/libc.a"; exit 0; }
(cd $W && $IX/languages/c/Main.exe -m 5 -I$L/include -I$L/include/utf -I$L -I$L/include/arch/arm -Darm -Dplan9 \
   -o seg.5 $ROOT/machine/tests/plan9/seg.c && $IX/linker/Main.exe -m 5 -H2 -o seg seg.5 $M/lib_core/libc.a) \
  > $W/err 2>&1 || { echo "FAIL seg.c's build: $(head -2 $W/err)"; exit 1; }
got=$(cd $W && timeout 60 $IX/machine/Main.exe seg 2>&1)
want="attached, zeros: 1
f(1) = 43
written again, f(1) = 8
freed, zeros: 1
a bad class refused: 1
detached: 1"
[ "$got" = "$want" ] || { echo "FAIL seg"; diff <(echo "$want") <(echo "$got"); exit 1; }
echo "seg: code written in a segment attached, flushed, called; written again, flushed, the new code run"
