#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-acid debugging a process (plan_debugger.md, stage 8's step 4):
# mini-acid built for Plan 9 (mini-mk), run by mini-5i beside its
# target, with ix's library (debuggers/acid/lib: port.acid, arm.acid),
# each session's output as recorded: acid/proc/*.acid on a program by
# mini-cc (acid/proc/target.c: new, a breakpoint, cont, step, next, stk;
# steps to the exit), acid/ml/*.acid on one by mini-ml (acid/ml/Down.ml:
# its stack, mini-ml's frames read by their prologues).
#   live: the C sessions given to principia's acid too, with its own
#   library, both outputs the same but for what ix's library does
#   otherwise: the lines its library prints as it is read, a caller's
#   offset in a stack (the call, not libmach's instruction before it),
#   a line said twice (needs ~/principia)
#   record: the outputs written as acid/{proc,ml}/NAME.out
# usage: debuggers/tests/acid_proc.sh [live | record]

ROOT=$(cd $(dirname $0)/../.. && pwd)
IX=$ROOT/_build/default
T=$ROOT/debuggers/tests/acid
LIB=$ROOT/debuggers/acid/lib
P=${PRINCIPIA:-$HOME/principia}
M=$ROOT/_mk/5-plan9
L=$ROOT/lib_core/libc
LC=$ROOT/lib_core
[ -f $M/lib_core/libc.a ] || { echo "skipped: no _mk/5-plan9/lib_core (mini-mk O=5 OS=plan9 in lib_core)"; exit 0; }
# (lib_executable first: mini-mk takes a library's archive as it is)
(cd $ROOT/lib_executable && MKSHELL=mini-rc PATH=$ROOT/bin:$PATH mini-mk O=5 OS=plan9 > /dev/null 2>&1 \
   && cd $ROOT/debuggers/acid && MKSHELL=mini-rc PATH=$ROOT/bin:$PATH mini-mk O=5 OS=plan9 > /dev/null 2>&1) \
  || { echo "FAIL mini-mk O=5 OS=plan9 in lib_executable and debuggers/acid"; exit 1; }
W=$(mktemp -d)
# (the targets a session leaves stopped: the mini-5i processes running
# ./target in $W, by their command's name, not a pattern our shell has)
cleanup() {
  for p in $(ps -eo pid=,comm=,args= | awk '$2 == "Main.exe" && / \.\/target$/ {print $1}'); do
    case "$(readlink /proc/$p/cwd)" in $W/*) kill -9 $p;; esac
  done
}
trap 'cleanup; rm -rf $W' EXIT
mkdir $W/c $W/ml
# (compiled by its name, in its directory: its tables say target.c, as
# 5a's -r, and src() finds it there)
cp $T/proc/target.c $W/c/
(cd $W/c && $IX/languages/c/Main.exe -m 5 -I$L/include -I$L/include/utf -I$L -I$L/include/arch/arm -Darm -Dplan9 -o target.5 target.c \
   && $IX/linker/Main.exe -m 5 -g -H2 -o target target.5 $M/lib_core/libc.a) > $W/err 2>&1 \
  || { echo "FAIL the C target's build: $(head -2 $W/err)"; exit 1; }
I="-I $W/ml -I $LC/system/plan9 -I $LC/core -I $LC/base -I $LC/collections -I $LC/printing -I $LC/parsing -I $LC/system -I $LC/concurrency -I $LC/commons"
U=$($ROOT/bin/mini-ar t $M/lib_core/lib_core.a | sed 's,.*/,,; s,\.ml$,,' | tr '\n' ' ')
cp $T/ml/Down.ml $W/ml/
(cd $W/ml && $IX/languages/ml/Main.exe -m 5 -O3 $I -o Down.5 Down.ml \
   && $IX/languages/ml/Main.exe -m 5 -O3 -start $U Down Std_exit -o Down.start.5 \
   && $IX/linker/Main.exe -m 5 -g -H2 -nofollow -o target Down.start.5 $M/lib_core/lib_core.a Down.5 \
        $M/lib_core/std_exit.5 $M/lib_core/runtime.5 $M/lib_core/libc.a) > $W/err 2>&1 \
  || { echo "FAIL Down.ml's build: $(head -2 $W/err)"; exit 1; }

norm() { grep -a -v 'pushfile: /lib' | sed 's/[0-9]\{4,8\}: /PID: /g;s/[0-9]\{4,8\}\/ctl/PID\/ctl/g;s/pid=[0-9]*/pid=PID/g'; }
# (live: what ix's library does otherwise, taken out of both)
# (and _main's line: its call's, rt0.s:17, where libmach's says the line
# of the instruction before it, 16)
alike() { sed -E '/^\/lib\/acid\//d; /^_main[+ ]/d; s/\+0x[0-9a-f]+ ([^ ]*:[0-9]+)$/ \1/' | uniq; }
n=0; failures=0
for d in proc:c ml:ml; do
  for f in $T/${d%:*}/*.acid; do
    name=${d%:*}/$(basename $f .acid)
    n=$((n + 1))
    (cd $W/${d#*:} && timeout -s KILL 120 $IX/machine/Main.exe $M/debuggers/acid/mini-acid -l $LIB/port.acid -l $LIB/arm.acid \
       ./target < $f > $W/out 2>&1)
    cleanup
    norm < $W/out > $W/got
    [ "$1" = record ] && cp $W/got $T/$name.out
    if [ "$1" = live ]; then
      [ ${d%:*} = proc ] || { n=$((n - 1)); continue; }
      [ -f $P/ROOT/lib/acid/port.acid ] || { echo "skipped live: no $P/ROOT/lib/acid"; exit 0; }
      (cd $W/c && timeout -s KILL 120 $IX/machine/Main.exe $P/ROOT/arch/arm/bin/acid -l $P/ROOT/lib/acid/port.acid \
         -l $P/ROOT/lib/acid/arm.acid ./target < $f > $W/ref 2>&1)
      cleanup
      norm < $W/ref | alike > $W/expected
      alike < $W/got > $W/got2; mv $W/got2 $W/got
    else cp $T/$name.out $W/expected; fi
    cmp -s $W/expected $W/got || { failures=$((failures + 1)); echo "FAIL $name"; diff -a $W/expected $W/got | head -6; }
  done
done
echo "acid_proc: $n sessions${1:+ ($1)}, $failures failure(s)"
[ $failures = 0 ]
