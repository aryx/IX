#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The recorded bytes: each golden/*.s assembled and linked by ix, for
# the machine, format and entry that golden.txt gives it, must have the
# SHA-256 that goken's 5a/5l -f or 7a/7l gave (golden.sh record, which
# needs goken, rewrites golden.txt). Run by make test, without goken.
# The inputs are goken's tests/s and xix's tests/linker fixtures.

DIR=$(cd $(dirname $0) && pwd)
IX=$(cd $DIR/../.. && pwd)/_build/default
W=$(mktemp -d)
trap 'rm -rf $W' EXIT
cd $DIR/golden

if [ "$1" = record ]; then
  export PATH=$HOME/goken/bin:$HOME/goken/ROOT/arch/boot-gcc/bin:$PATH
  while read -r m h e f _; do
    # (5l -f: the floating point VFP's, the only one mini-ld has)
    fp=; [ $m = 5 ] && fp=-f
    cp $f $W/ && (cd $W && ${m}a -r $f >/dev/null && ${m}l $fp $h -s -E $e -o g.exe ${f%.s}.$m) || { echo "goken failed: $m $h $f" >&2; exit 1; }
    echo "$m $h $e $f $(sha256sum < $W/g.exe | cut -d' ' -f1)"
  done < <(cut -d' ' -f1-4 $DIR/golden.txt) > $W/golden.txt
  mv $W/golden.txt $DIR/golden.txt
  exit 0
fi

failures=0
while read -r m h e f sum; do
  if $IX/assembler/Main.exe -m $m -o $W/t.$m $f && $IX/linker/Main.exe -m $m $h -E $e -o $W/t.exe $W/t.$m &&
     [ "$(sha256sum < $W/t.exe | cut -d' ' -f1)" = "$sum" ]; then :
  else echo "FAIL $m $h $f"; failures=$((failures + 1)); fi
done < $DIR/golden.txt
echo "golden: $(wc -l < $DIR/golden.txt) executables, $failures failure(s)"
[ $failures = 0 ]
