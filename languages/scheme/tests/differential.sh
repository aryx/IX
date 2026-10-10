#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-scheme by mini-ml against mini-scheme by dune
# (docs/plans/plan_scheme.md, stage 1): the programs of the unit tests
# (Unit_scheme's: what they run with), a line each, typed at the prompt
# of both, in Scheme's way of printing (the steps counted: -s) and in
# Beginning Student's; and
# the stepper's steps of Unit_scheme_step's. What the two say must be
# the same, values and errors. The one by mini-ml runs as it is (arm64),
# or under mini-5i (-5: arm, a Pi1's integers of 31 bits and its floats).
# usage: languages/scheme/tests/differential.sh [-5]   (dune build, and mini-mk O=7 or O=5 here, first; MINISCHEME: mini-ml's build, if not _mk's)
cd "$(dirname "$0")/../../.."
O=7; RUN=; [ "${1:-}" = -5 ] && { O=5; RUN=_build/default/machine/Main.exe; }
NATIVE=_build/default/languages/scheme/Main.exe
MINI=${MINISCHEME:-_mk/$O/languages/scheme/mini-scheme}
W=$(mktemp -d); trap 'rm -rf $W' EXIT
failures=0
# a test file's programs: the strings given to a function (run, steps),
# one a line (not those of several lines)
programs() { python3 -I - "$1" "$2" <<'P'
import re, sys
text = open(sys.argv[1]).read()
for m in re.finditer(r'\((?:%s) (?:"((?:[^"\\]|\\.)*)"|\{\|(.*?)\|\})\)' % sys.argv[2], text, re.S):
    e = m.group(2) if m.group(1) is None else m.group(1).replace('\\"', '"').replace('\\\\', '\\')
    if '\n' in e or '\\n' in e: continue
    print(e)
P
}
programs languages/scheme/tests/Unit_scheme.ml 'run|error_at' > $W/run.txt
programs languages/scheme/tests/Unit_scheme_step.ml 'show' > $W/step.txt
for case in "run scheme -s" "run student -student" "step stepper -step"; do
  set -- $case
  $NATIVE $3 < $W/$1.txt > $W/$2.native 2>&1
  $RUN $MINI $3 < $W/$1.txt > $W/$2.mini 2>&1
  if cmp -s $W/$2.native $W/$2.mini; then echo "ok mini-scheme $3, by mini-ml ($O) as by dune: $(wc -l < $W/$1.txt) programs, $(wc -l < $W/$2.native) lines said"
  else echo "FAIL mini-scheme $3"; diff $W/$2.native $W/$2.mini | head -10; failures=$((failures + 1)); fi
done
# Landin's SECD machine against the CESK machine, by each build: the same
# programs, the same values and errors (the prompt's way, and Beginning
# Student's)
for build in "dune $NATIVE" "mini-ml($O) $RUN $MINI"; do
  set -- $build; what=$1; shift
  for flag in "" -student; do
    "$@" $flag < $W/run.txt > $W/cesk.txt 2>&1
    "$@" -secd $flag < $W/run.txt > $W/secd.txt 2>&1
    "$@" -secd -landin $flag < $W/run.txt > $W/landin.txt 2>&1
    if cmp -s $W/cesk.txt $W/secd.txt && cmp -s $W/cesk.txt $W/landin.txt; then echo "ok mini-scheme -secd $flag, by $what as its first machine: $(wc -l < $W/cesk.txt) lines said"
    else echo "FAIL mini-scheme -secd $flag, by $what"; diff $W/cesk.txt $W/secd.txt | head -10; diff $W/cesk.txt $W/landin.txt | head -4; failures=$((failures + 1)); fi
  done
done
exit $failures
