#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# Another process's /proc under mini-5i (plan_debugger.md, decision 12,
# stage 8's steps 1 and 2: Proc9): Plan 9 programs (by mini-cc) that
# debug their children through the children's /proc files, as a
# debugger does, what they say as recorded. proc/stop.c stops its
# child, reads its status, its memory and its registers, writes its
# memory, starts it again and kills it; proc/bp.c sets a breakpoint
# (startstop, the note read, the instruction put back) and hangs a
# child at its exec (waitstop). Needs _mk/5-plan9's libc (mini-mk O=5
# OS=plan9 in lib_core).
# usage: debuggers/tests/proc.sh

ROOT=$(cd $(dirname $0)/../.. && pwd)
IX=$ROOT/_build/default
M=$ROOT/_mk/5-plan9
L=$ROOT/lib_core/libc
W=$(mktemp -d)
trap 'rm -rf $W' EXIT
[ -f $M/lib_core/libc.a ] || { echo "skipped: no _mk/5-plan9/lib_core/libc.a"; exit 0; }
failures=0
# check name expected: proc/name.c built, run under mini-5i, its output
check() {
  (cd $W && $IX/languages/c/Main.exe -m 5 -I$L/include -I$L/include/utf -I$L -I$L/include/arch/arm -Darm -Dplan9 \
     -o $1.5 $ROOT/debuggers/tests/proc/$1.c && $IX/linker/Main.exe -m 5 -H2 -o $1 $1.5 $M/lib_core/libc.a) \
    > $W/err 2>&1 || { echo "FAIL $1's build: $(head -2 $W/err)"; failures=$((failures + 1)); return; }
  got=$(cd $W && timeout 60 $IX/machine/Main.exe $1 2>&1)
  [ "$got" = "$2" ] || { echo "FAIL $1"; diff <(echo "$2") <(echo "$got") | head -8; failures=$((failures + 1)); }
}
check stop "stopped: Stopped; its count read, the same twice: 1
its pc in main: 1
started again, it saw the word written: 1
killed: yes"
check bp "stopped at the breakpoint: 1; its note: sys: breakpoint
the instruction put back, it went on: 1
hung at its exec, stopped: 1
started, it ran its program: 1"
[ $failures = 0 ] && echo "proc: children stopped, read, written, started, killed; a breakpoint, a hang at exec"
[ $failures = 0 ]
