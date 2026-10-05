#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The instructions a program executes, by mini-5i -s, as mini-cc's back
# ends compile it and all of goken's libc: compat (5c's code at -O0),
# -simple, -simple -O (Opti's passes), and -simple with the passes one
# at a time added, in Opti's order (the libc -O's then). For the
# numbers in plan_cc.md's opti amendment.
# usage: count.sh 5|7 workdir prog.c...   (needs goken, and dune build)
set -u
ROOT=$(cd $(dirname $0)/../../.. && pwd)
IX=$ROOT/_build/default
O=$1; W=$2; shift 2
progs=("$@")
case $O in 5) OBJ=arm;; 7) OBJ=arm64;; esac
incs="-I$HOME/goken/include -I$HOME/goken/include/ALL -I$HOME/goken/include/arch/$OBJ"
# the libcs, once per workdir
[ -f $W/compat/t/libc.a ] || MINICC=1 $ROOT/linker/tests/libc.sh $O $W/compat > /dev/null
[ -f $W/simple/t/libc.a ] || MINICC=1 MINICC_FLAGS=-simple $ROOT/linker/tests/libc.sh $O $W/simple > /dev/null
[ -f $W/opti/t/libc.a ] || MINICC=1 MINICC_FLAGS="-simple -O" $ROOT/linker/tests/libc.sh $O $W/opti > /dev/null
passes=$(sed -n 's/^let passes = \[ \(.*\) \]$/\1/p' $ROOT/languages/c/opti/Opti.ml | grep -o '"[a-z]*"' | tr -d '"')
mkdir -p $W/p
count() {  # flags libc name
  (cd $(dirname $c) && $IX/languages/c/Main.exe $1 -m $O $incs -o $W/p/$b.$3.$O $b.c) || { echo -n " FAIL"; return; }
  $IX/linker/Main.exe -m $O -H7 -o $W/p/$b.$3 $W/p/$b.$3.$O $2 || { echo -n " FAIL"; return; }
  n=$(cd $W/p && timeout -k 2 20 $IX/machine/Main.exe -s ./$b.$3 one two 2>&1 >/dev/null | sed -n 's/^mini-5i: \([0-9]*\) instructions.*/\1/p' | tail -1)
  echo -n " ${n:-?}"
}
echo "program compat simple -O $(echo $passes peep | sed 's/\([a-z]*\)/+\1/g')"
for c in "${progs[@]}"; do
  b=$(basename $c .c)
  echo -n "$b"
  count "" $W/compat/t/libc.a compat
  count -simple $W/simple/t/libc.a simple
  count "-simple -O" $W/opti/t/libc.a opti
  flags=""
  for p in $passes peep; do flags="$flags -O$p"; count "-simple $flags" $W/opti/t/libc.a $p; done
  echo
done
