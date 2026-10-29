#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The symbol table and the pc/line table (Symtab, plan_debugger.md's
# stage 1): each arm program of golden/ as a Plan 9 a.out with its
# tables, by mini-asm and mini-ld -g -H2, must have the SHA-256 that
# goken's 5a -r and 5l -H2 (no -s) gave (5a -r: the file's name as
# given, no current directory before it, as mini-asm; so the bytes are
# the same in any directory). Run by make test, without goken.
# usage: linker/tests/symtab.sh           against golden_symtab.txt
#        linker/tests/symtab.sh live      against goken's, made now
#        linker/tests/symtab.sh record    golden_symtab.txt made again (goken)

DIR=$(cd $(dirname $0) && pwd)
IX=$(cd $DIR/../.. && pwd)/_build/default
G=$HOME/goken
W=$(mktemp -d)
trap 'rm -rf $W' EXIT

# goken's executable of the program [f] (entry [e]) as $W/g.exe
goken() {
  export PATH=$G/bin:$G/ROOT/arch/boot-gcc/bin:$PATH
  (cd $W && 5a -r $1 > /dev/null 2>&1 && 5l -f -H2 -E $2 -o g.exe ${1%.s}.5 > /dev/null 2>&1)
}

if [ "$1" = record ]; then
  while read -r m h e f _; do
    [ $m = 5 ] || continue
    cp $DIR/golden/$f $W/
    goken $f $e || { echo "goken failed: $f" >&2; exit 1; }
    echo "$e $f $(sha256sum < $W/g.exe | cut -d' ' -f1)"
  done < $DIR/golden.txt > $W/golden_symtab.txt
  mv $W/golden_symtab.txt $DIR/golden_symtab.txt
  exit 0
fi

[ "$1" = live ] && { [ -x $G/ROOT/arch/boot-gcc/bin/5l ] || { echo "skipped: no goken in $G"; exit 0; }; }
n=0; failures=0
while read -r e f sum; do
  n=$((n + 1))
  cp $DIR/golden/$f $W/
  if [ "$1" = live ]; then goken $f $e; sum=$(sha256sum < $W/g.exe | cut -d' ' -f1); fi
  if (cd $W && $IX/assembler/Main.exe -m 5 -o t.5 $f && $IX/linker/Main.exe -m 5 -g -H2 -E $e -o t.exe t.5) > $W/err 2>&1 \
     && [ "$(sha256sum < $W/t.exe | cut -d' ' -f1)" = "$sum" ]; then :
  else failures=$((failures + 1)); echo "FAIL $f $(head -1 $W/err)"; fi
done < $DIR/golden_symtab.txt
echo "symtab: $n a.outs with their tables as goken's, $failures failure(s)"
[ $failures = 0 ]
