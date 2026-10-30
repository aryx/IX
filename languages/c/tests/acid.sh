#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-cc -a's acid declarations against 5c -a's, file by file, -a and
# -aa, over goken's libraries and utilities (listing.sh's files, with
# their flags from mk -n): the same text (needs ~/goken).
# usage: acid.sh 5 workdir
set -u
export PATH=$HOME/goken/bin:$HOME/goken/ROOT/arch/boot-gcc/bin:$PATH
unset MKSHELL
IX=$(cd $(dirname $0)/../../.. && pwd)/_build/default
O=$1; W=$2
case $O in 5) OBJ=arm;; 7) OBJ=arm64;; esac
rm -rf $W; mkdir -p $W
same=0; diff=0; fail=0
one() {  # dir flags src
  local b=$(echo $1/${3%.c} | sed "s|$HOME/goken/||" | tr / _)
  for a in a aa; do
    # (5c's -a alone writes nothing, goken's lex.c clearing first before
    # it tests it: -n, its file)
    (cd $1 && ${O}c -${a}n $2 -o $W/$b.$a.g $3 > /dev/null 2>&1) || { echo "${O}c-FAIL $b"; return; }
    (cd $1 && $IX/languages/c/Main.exe -m $O -$a $2 $3 > $W/$b.$a.t 2> $W/$b.err) || { echo "FAIL $b: $(tail -1 $W/$b.err)"; fail=$((fail+1)); return; }
    if cmp -s $W/$b.$a.g $W/$b.$a.t; then same=$((same+1)); else echo "DIFF -$a $b $(diff $W/$b.$a.g $W/$b.$a.t | grep -c '^[<>]')"; diff=$((diff+1)); fi
  done
}
for d in lib_core/libc lib_core/libbio lib_strings/libregexp lib_strings/libstring \
         $(cd $HOME/goken && find utilities -name mkfile -printf '%h\n' | sort); do
  cd $HOME/goken/$d
  while read -r line; do
    w=($line)
    [ "${w[0]}" = ${O}c ] && [[ ${w[-1]} = *.c ]] || continue
    flags=$(echo "${w[@]:1:${#w[@]}-2}" | sed -e 's/ *-o [^ ]*//')
    flags=${flags//\$CFLAGS_EXTRA/$(grep '^CFLAGS_EXTRA=' mkfile | cut -d= -f2-)}
    one $HOME/goken/$d "$flags" ${w[-1]}
  done < <(mk -a -n objtype=$OBJ cputype=$OBJ GOOS=linux 2>/dev/null)
done
echo "same $same, diff $diff, fail $fail"
