#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-smalltalk by mini-ml against mini-smalltalk by dune
# (docs/plans/plan_system_squeak.md, stage 1): the expressions of the
# unit tests (Unit_smalltalk's on the Blue Book's system, Unit_squeak's
# on Squeak's: what they print with), a line each, given to both; what
# the two say must be the same, answers and errors. The one by mini-ml
# runs under mini-5i (arm64; -5: arm, where 3 expressions differ today:
# OCaml's integers of 31 bits, the plan's Status, stage 1), some minutes.
# usage: languages/smalltalk/tests/differential.sh [-5]   (dune build, and mini-mk here, first)
cd "$(dirname "$0")/../../.."
O=7; [ "${1:-}" = -5 ] && O=5
NATIVE=_build/default/languages/smalltalk/Main.exe
MINI=_mk/$O/languages/smalltalk/mini-smalltalk
FIVE=_build/default/machine/Main.exe
W=$(mktemp -d); trap 'rm -rf $W' EXIT
failures=0
# the tests' expressions: the strings given to print, one a line (not
# those of several lines)
expressions() { python3 -I - "$1" <<'P'
import re, sys
for m in re.finditer(r'\(print "((?:[^"\\]|\\.)*)"\)', open(sys.argv[1]).read()):
    e = m.group(1)
    if '\\n' in e or '\\t' in e: continue
    print(e.replace('\\"', '"').replace('\\\\', '\\'))
P
}
for case in "blue Unit_smalltalk" "squeak Unit_squeak"; do
  set -- $case
  expressions languages/smalltalk/tests/$2.ml > $W/$1.txt
  $NATIVE -k $1 < $W/$1.txt > $W/$1.native 2>&1
  $FIVE $MINI -k $1 < $W/$1.txt > $W/$1.mini 2>&1
  if cmp -s $W/$1.native $W/$1.mini; then echo "ok mini-smalltalk -k $1, by mini-ml ($O) as by dune: $(wc -l < $W/$1.txt) expressions"
  else echo "FAIL mini-smalltalk -k $1"; diff $W/$1.native $W/$1.mini | head -10; failures=$((failures + 1)); fi
done
exit $failures
