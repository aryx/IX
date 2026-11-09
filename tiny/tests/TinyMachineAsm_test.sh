#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The test of TinyMachineAsm.ml, its law: print and parse are each
# other's inverse, each line of assembly printed then parsed again the
# same line (TinyMachineAsm_tests/Law.ml). On the assembly there is:
# the .tm of the repository, written by hand (the kernel's, the
# runtimes', the tests'), and what the compilers write, tiny-c's of
# TinyC_tests/ and tiny-ml's of TinyLibCore's first units.
# usage: TinyMachineAsm_test.sh

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
LAW=${LAW:-$ROOT/_build/default/tiny/tests/TinyMachineAsm_tests/Law.exe}
TC=${TC:-$ROOT/_build/default/tiny/TinyC.exe}
TML=${TML:-$ROOT/_build/default/tiny/TinyML.exe}
W=${W:-$(mktemp -d)}
[ -n "${KEEP:-}" ] || trap 'rm -rf $W' EXIT

# what the compilers write
for c in $ROOT/tiny/tests/TinyC_tests/*.c; do
  (cd $(dirname $c) && $TC -o $W/$(basename $c .c).tm $(basename $c)) || { echo "FAIL tiny-c $c"; exit 1; }
done
b=
for m in Stdlib Char Seq List String; do
  $TML -c -nostdlib -o $W/$m.tm $b $ROOT/tiny/TinyLibCore/$m.ml || { echo "FAIL tiny-ml $m"; exit 1; }
  b="$b $W/$m.tmi"
done

if $LAW $(cd $ROOT && git ls-files '*.tm' | sed "s|^|$ROOT/|") $W/*.tm > $W/law.out
then echo "ok TinyMachineAsm: $(tail -1 $W/law.out)"
else echo "FAIL TinyMachineAsm:"; head -20 $W/law.out; exit 1
fi
