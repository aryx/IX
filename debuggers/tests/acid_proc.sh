#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-acid debugging a process (plan_debugger.md, stage 8's step 4):
# mini-acid built for Plan 9 (mini-mk), run by mini-5i beside its
# target (acid/proc/target.c, by mini-cc, linked with its tables), each
# session of acid/proc/ given to it, its output as recorded
# (acid/proc/NAME.out: principia's acid's under mini-5i, the pids taken
# out): new(), a breakpoint, cont, step, next, stk; steps to the exit.
# The library is principia's (port.acid, arm.acid): skipped without
# ~/principia. With live: principia's acid run again, its output the
# expected one (and record: written as acid/proc/NAME.out).
# Then a program by mini-ml (acid/ml/Down.ml) with ix's library
# (debuggers/acid/lib/ml.acid: mini-ml's frames read from their
# prologues, in acid), each session of acid/ml/ as recorded (mini-acid's
# own: acid has no such library; record writes it).
# usage: debuggers/tests/acid_proc.sh [live | record]

ROOT=$(cd $(dirname $0)/../.. && pwd)
IX=$ROOT/_build/default
T=$ROOT/debuggers/tests/acid/proc
P=${PRINCIPIA:-$HOME/principia}
A=$P/ROOT/lib/acid
M=$ROOT/_mk/5-plan9
L=$ROOT/lib_core/libc
[ -f $A/port.acid ] || { echo "skipped: no $A/port.acid (principia's acid library)"; exit 0; }
[ -f $M/lib_core/libc.a ] || { echo "skipped: no _mk/5-plan9/lib_core (mini-mk O=5 OS=plan9 in lib_core)"; exit 0; }
(cd $ROOT/debuggers/acid && MKSHELL=mini-rc PATH=$ROOT/bin:$PATH mini-mk O=5 OS=plan9 > /dev/null 2>&1) \
  || { echo "FAIL mini-mk O=5 OS=plan9 in debuggers/acid"; exit 1; }
W=$(mktemp -d)
# (the targets a session leaves stopped: the mini-5i processes running
# ./target in $W, by their command's name, not a pattern our shell has)
cleanup() {
  for p in $(ps -eo pid=,comm=,args= | awk '$2 == "Main.exe" && / \.\/target$/ {print $1}'); do
    [ "$(readlink /proc/$p/cwd)" = "$W" ] && kill -9 $p
  done
}
trap 'cleanup; rm -rf $W' EXIT
(cd $W && $IX/languages/c/Main.exe -m 5 -I$L/include -I$L/include/utf -I$L -I$L/include/arch/arm -Darm -Dplan9 -o target.5 $T/target.c \
   && $IX/linker/Main.exe -m 5 -g -H2 -o target target.5 $M/lib_core/libc.a) > $W/err 2>&1 \
  || { echo "FAIL the target's build: $(head -2 $W/err)"; exit 1; }
norm() { grep -a -v 'pushfile: /lib' | sed 's/[0-9]\{4,8\}: /PID: /g;s/[0-9]\{4,8\}\/ctl/PID\/ctl/g;s/pid=[0-9]*/pid=PID/g'; }
n=0; failures=0
for f in $T/*.acid; do
  name=$(basename $f .acid)
  n=$((n + 1))
  if [ "$1" = live ] || [ "$1" = record ]; then
    (cd $W && timeout -s KILL 120 $IX/machine/Main.exe $P/ROOT/arch/arm/bin/acid -l $A/port.acid -l $A/arm.acid ./target < $f > $W/ref 2>&1)
    cleanup
    norm < $W/ref > $W/expected
    [ "$1" = record ] && cp $W/expected $T/$name.out
  else cp $T/$name.out $W/expected; fi
  (cd $W && timeout -s KILL 120 $IX/machine/Main.exe $M/debuggers/acid/mini-acid -l $A/port.acid -l $A/arm.acid ./target < $f > $W/out 2>&1)
  cleanup
  norm < $W/out > $W/got
  cmp -s $W/expected $W/got || { failures=$((failures + 1)); echo "FAIL $name"; diff -a $W/expected $W/got | head -6; }
done
# the program by mini-ml, built as walk.sh's
LC=$ROOT/lib_core
I="-I $W -I $LC/system/plan9 -I $LC/core -I $LC/base -I $LC/collections -I $LC/printing -I $LC/parsing -I $LC/system -I $LC/concurrency -I $LC/commons"
U=$($ROOT/bin/mini-ar t $M/lib_core/lib_core.a | sed 's,.*/,,; s,\.ml$,,' | tr '\n' ' ')
cp $ROOT/debuggers/tests/acid/ml/Down.ml $W/
(cd $W && $IX/languages/ml/Main.exe -m 5 -O3 $I -o Down.5 Down.ml \
   && $IX/languages/ml/Main.exe -m 5 -O3 -start $U Down Std_exit -o Down.start.5 \
   && $IX/linker/Main.exe -m 5 -g -H2 -nofollow -o target Down.start.5 $M/lib_core/lib_core.a Down.5 \
        $M/lib_core/std_exit.5 $M/lib_core/runtime.5 $M/lib_core/libc.a) > $W/err 2>&1 \
  || { echo "FAIL Down.ml's build: $(head -2 $W/err)"; exit 1; }
for f in $ROOT/debuggers/tests/acid/ml/*.acid; do
  name=$(basename $f .acid)
  n=$((n + 1))
  (cd $W && timeout -s KILL 120 $IX/machine/Main.exe $M/debuggers/acid/mini-acid -l $A/port.acid -l $A/arm.acid \
     -l $ROOT/debuggers/acid/lib/ml.acid ./target < $f > $W/out 2>&1)
  cleanup
  norm < $W/out > $W/got
  [ "$1" = record ] && cp $W/got $ROOT/debuggers/tests/acid/ml/$name.out
  cmp -s $ROOT/debuggers/tests/acid/ml/$name.out $W/got || { failures=$((failures + 1)); echo "FAIL ml/$name"; diff -a $ROOT/debuggers/tests/acid/ml/$name.out $W/got | head -6; }
done
echo "acid_proc: $n sessions as recorded (acid's, and ml.acid's), $failures failure(s)"
[ $failures = 0 ]
