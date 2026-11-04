#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-analyze on toy programs: each directory of tests/c/ and
# tests/ml/, and of dead/, caps/, exn/ and bugs/ by their option (its .c
# or .ml files one program) against its expected.out, read, not made by
# another analysis. A directory of bugs/ is a fix's commit: Before.ml the
# code before it, reported, After.ml after it, not; one of raises/, C
# and ML, -bugs's check of the externals' [@@raise] against the C.
# usage: analyzers/tests/run.sh [-record]   (dune build first)
# ANALYZE: the program, if not dune's.
cd "$(dirname "$0")/../.."
ANALYZE=${ANALYZE:-_build/default/analyzers/Main.exe}
W=$(mktemp -d); trap 'rm -rf $W' EXIT
failures=0
for d in analyzers/tests/c/*/ analyzers/tests/ml/*/ analyzers/tests/dead/*/ analyzers/tests/caps/*/ analyzers/tests/exn/*/ analyzers/tests/bugs/*/ analyzers/tests/raises/*/; do
  d=${d%/}; n=$(basename $d)
  case $d in */dead/*) n=dead_$n; flag=-dead;; */caps/*) n=caps_$n; flag=-caps;; */exn/*) n=exn_$n; flag=-exn;; */bugs/*) n=bugs_$n; flag=-bugs;; */raises/*) n=raises_$n; flag=-bugs;; *) flag=;; esac
  # (a .mli is found beside its .ml; args, the options a test needs: its
  # units' -start order, an -I)
  args=$([ -f $d/args ] && cat $d/args)
  eval "$ANALYZE $flag $args $(ls $d/*.c $d/*.ml 2> /dev/null | tr '\n' ' ')" > $W/$n.out 2>&1
  if [ "${1:-}" = -record ]; then cp $W/$n.out $d/expected.out; echo "recorded $d/expected.out"
  elif cmp -s $W/$n.out $d/expected.out; then echo "ok mini-analyze: $n"
  else echo "FAIL mini-analyze: $n"; diff $d/expected.out $W/$n.out | head -10; failures=$((failures + 1)); fi
done
# models/: List's and Hashtbl's models (analyzers/ml/Models) against their
# code as written (-no-models): for each function of Probe.ml, what may
# escape it, and whether it is called (a function given a container's)
DATALOG=${DATALOG:-_build/default/languages/datalog/Main.exe}
R=analyzers/datalog; P=$R/points_to
for m in models no-models; do
  $ANALYZE -facts $([ $m = no-models ] && echo -no-models) analyzers/tests/models/Probe.ml > $W/$m.facts 2>&1
  $DATALOG -q 'escapes(F, none, none, E)' -q 'called(F)' $P/instructions.dl $P/andersen.dl \
    $P/contexts.dl $P/insensitive.dl $R/calls.dl $R/exceptions.dl $W/$m.facts 2> /dev/null |
    grep -E "^[a-z]+\('Probe\.[a-z_0-9]*'" > $W/$m.answers
done
if [ -s $W/models.answers ] && cmp -s $W/models.answers $W/no-models.answers; then
  echo "ok mini-analyze: models raise and call as the library's code ($(wc -l < $W/models.answers) answers)"
else
  echo "FAIL mini-analyze: models, not as the library's code (< models, > as written)"
  diff $W/models.answers $W/no-models.answers | head -10; failures=$((failures + 1))
fi
# capabilities.dl's groups: each function of lib_core's two Unix (Linux's,
# plan9's) that makes a system call is in one (needs a capability, acts on
# a descriptor, computes), its .mli's vals as unix_val
for u in system system/plan9; do
  $ANALYZE -facts -alone -I lib_core/$u lib_core/$u/Unix.ml > $W/unix.facts 2>&1
  awk '/^module LargeFile/ { m = "LargeFile." } /^end/ { m = "" }
    match($0, /^ *val [a-z_0-9]+/) { v = substr($0, RSTART, RLENGTH)
      sub(/^ *val /, "", v); printf "unix_val(\047Unix.%s%s\047).\n", m, v }' \
    lib_core/$u/Unix.mli > $W/vals.facts
  $DATALOG -q 'unclassified(F)' $P/instructions.dl $P/contexts.dl \
    $P/insensitive.dl $R/dead.dl $R/capabilities.dl $W/unix.facts \
    $W/vals.facts > $W/unclassified 2> /dev/null
  n=$(wc -l < $W/vals.facts)
  if [ $n -gt 20 ] && [ ! -s $W/unclassified ]; then
    echo "ok mini-analyze: each system call of $u's Unix in a group ($n vals)"
  else
    echo "FAIL mini-analyze: $u's Unix, in no group of capabilities.dl ($n):"
    head -10 $W/unclassified; failures=$((failures + 1))
  fi
done
exit $failures
