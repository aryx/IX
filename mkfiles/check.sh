#!/bin/bash
# Claude Code
#
# Copyright (C) 2026 Yoann Padioleau
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Library General Public License
# (LGPL) as published by the Free Software Foundation; either version
# 2 of the License, or (at your option) any later version.
#
# ix built by ix (plan_mkfiles.md): mini-mk over the mkfiles, with the
# programs dune built (./bin), then each program made so against dune's
# own: the same output, to the byte.
# - mini-asm: goken's arm and arm64 .s files, each one's object.
# usage: mkfiles/check.sh     (after dune build; goken's .s files for the inputs)

ROOT=$(cd "$(dirname "$0")/.." && pwd)
# only ix's programs: nothing of goken's builds (its .s files are the inputs below)
export PATH=$ROOT/bin:$PATH
W=$(mktemp -d); trap 'rm -rf $W' EXIT
failures=0
cd $ROOT
mini-mk > $W/mk.log 2>&1 || { echo "FAIL mini-mk: $(tail -3 $W/mk.log)"; exit 1; }
echo "ok mini-mk: $(ls _mk/7/*/*.7 | wc -l) objects under _mk/7"

# a program's two builds on each input: the same exit status, the same
# messages, the same file written
same() {
  local name=$1 n=0 bad=0; shift
  for f in "$@"; do
    case $f in *arm64*) m=7;; *) m=5;; esac
    _mk/7/assembler/$name -m $m -o $W/mk.o $f 2> $W/mk.err; r1=$?
    bin/$name -m $m -o $W/dune.o $f 2> $W/dune.err; r2=$?
    n=$((n + 1))
    if [ $r1 != $r2 ] || ! cmp -s $W/mk.err $W/dune.err || { [ $r1 = 0 ] && ! cmp -s $W/mk.o $W/dune.o; }; then bad=$((bad + 1)); echo "  differs: $f"; fi
  done
  if [ $bad = 0 ]; then echo "ok $name: $n files, the same objects as dune's $name"; else echo "FAIL $name: $bad of $n files differ"; failures=$((failures + 1)); fi
}
G=$HOME/goken
same mini-asm $G/lib_core/libc/arch/arm/*.s $G/lib_core/libc/arch/arm64/*.s $G/lib_core/libc/syscall/os/linux/*arm*.s $G/tests/s/*/*arm*.s
echo "$failures failures"
[ $failures = 0 ]
