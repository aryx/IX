#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The test of tiny-assembler's parse and TinyLibMachine's print_line,
# their law: a file's lines, parsed then printed (tiny-assembler -S),
# assemble to the same object as the file, and printed again are the
# same text. (old: TinyMachineAsm_test.sh, by Law.ml, each line parsed,
# printed and parsed again the same line, when parse was
# TinyMachineAsm's, a library's; it is tiny-assembler's now, the one
# program that reads assembly.) On the assembly there is: the .tm of
# the repository, written by hand (the kernel's, the runtimes', the
# tests'), and what the compilers write, tiny-c's of TinyC_tests/ and
# tiny-ml's of TinyLibCore's first units.
# usage: TinyAssembler_test.sh

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
TAS=${TAS:-$ROOT/_build/default/tiny/TinyAssembler.exe}
TC=${TC:-$ROOT/_build/default/tiny/TinyC.exe}
TML=${TML:-$ROOT/_build/default/tiny/TinyML.exe}
W=${W:-$(mktemp -d)}
[ -n "${KEEP:-}" ] || trap 'rm -rf $W' EXIT

# what the compilers write
mkdir -p $W/c
for c in $ROOT/tiny/tests/TinyC_tests/*.c; do
  (cd $(dirname $c) && $TC -S -o $W/c/$(basename $c .c).tm $(basename $c)) || { echo "FAIL tiny-c $c"; exit 1; }
done
b=
for m in Stdlib Char Seq List String; do
  $TML -c -nostdlib -S -o $W/c/$m.tm $b $ROOT/tiny/TinyLibCore/$m.ml || { echo "FAIL tiny-ml $m"; exit 1; }
  b="$b $W/c/$m.tmi"
done

files=0 bad=0
for f in $(cd $ROOT && git ls-files '*.tm' | sed "s|^|$ROOT/|") $W/c/*.tm; do
  files=$((files + 1))
  if $TAS -o $W/a.o $f && $TAS -S $f > $W/p.tm && $TAS -o $W/b.o $W/p.tm \
     && cmp -s $W/a.o $W/b.o && $TAS -S $W/p.tm > $W/q.tm && cmp -s $W/p.tm $W/q.tm
  then :
  else bad=$((bad + 1)); echo "not the same, printed and assembled again: $f"
  fi
done

if [ $bad = 0 ]
then echo "ok TinyAssembler: $files files, each printed (-S) the same object and text"
else echo "FAIL TinyAssembler: $bad of $files files"; exit 1
fi
