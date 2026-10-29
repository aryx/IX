#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# Another process's /proc under mini-5i (plan_debugger.md, decision 12,
# stage 8's first step: Proc9): a Plan 9 program (proc/stop.c, by
# mini-cc) stops its child, reads its status, its memory and its
# registers, writes its memory, starts it again and kills it, through
# the child's /proc files, as a debugger does; what it says as
# recorded. Needs _mk/5-plan9's libc (mini-mk O=5 OS=plan9 in lib_core).
# usage: debuggers/tests/proc.sh

ROOT=$(cd $(dirname $0)/../.. && pwd)
IX=$ROOT/_build/default
M=$ROOT/_mk/5-plan9
L=$ROOT/lib_core/libc
W=$(mktemp -d)
trap 'rm -rf $W' EXIT
[ -f $M/lib_core/libc.a ] || { echo "skipped: no _mk/5-plan9/lib_core/libc.a"; exit 0; }
(cd $W && $IX/languages/c/Main.exe -m 5 -I$L/include -I$L/include/utf -I$L -I$L/include/arch/arm -Darm -Dplan9 \
   -o stop.5 $ROOT/debuggers/tests/proc/stop.c && $IX/linker/Main.exe -m 5 -H2 -o stop stop.5 $M/lib_core/libc.a) \
  > $W/err 2>&1 || { echo "FAIL the build: $(head -2 $W/err)"; exit 1; }
got=$(cd $W && timeout 60 $IX/machine/Main.exe stop 2>&1)
expected="stopped: Stopped; its count read, the same twice: 1
its pc in main: 1
started again, it saw the word written: 1
killed: yes"
if [ "$got" = "$expected" ]; then echo "proc: a child stopped, read, written, started, killed through its /proc"
else echo "FAIL proc"; diff <(echo "$expected") <(echo "$got") | head -8; exit 1; fi
