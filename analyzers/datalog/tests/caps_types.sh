#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# capabilities_types.dl, OCaml's check again in Datalog, a test of the analysis.
# On tests/caps_wrong/ (programs OCaml refuses): each planted mismatch found,
# against expected.out. With programs (mkfiles' directories), or -all: every
# mismatch there is a mistake of the facts or the call graph, since OCaml accepts
# them; a line each: the calls found, those checked, the mismatches, what is not
# seen and why. Minutes with -all: by hand.
# usage: analyzers/datalog/tests/caps_types.sh [-record] [-all | dir...]   (dune build first)
# ANALYZE, DATALOG: the programs, if not dune's.
cd "$(dirname "$0")/../../.."
# sort's order the bytes', not the locale's (en_US put lacks_closure
# before lacks, a recording CI's C locale did not read the same)
export LC_ALL=C
R=analyzers/datalog; D=$R/points_to; T=$R/tests
export ANALYZE=${ANALYZE:-$PWD/_build/default/analyzers/Main.exe}
export DATALOG=${DATALOG:-$PWD/_build/default/languages/datalog/Main.exe}
W=$(mktemp -d); trap 'rm -rf $W' EXIT
export W R D
. $T/mk_units.sh

queries() { # out, facts
  (ulimit -v 12000000 2> /dev/null; timeout ${LIMIT:-180} $DATALOG -q 'mismatch(R, I, H, C)' -q 'by_need(R, I, H, S)' -q 'cap_call(I, H)' -q 'checked(I, H)' -q 'not_seen(I, H, W)' -q 'handed_unknown(I, G, V)' -q 'handed_in_dead(I, V)' \
    $D/instructions.dl $D/contexts.dl $D/insensitive.dl $R/dead.dl $R/capabilities.dl $R/capabilities_types.dl $2 2> /dev/null) > $1
}

one() { # a mkfile
  local mk=$1 dir=$(dirname $1) name flags files
  name=$(echo $dir | tr / _)
  case $(var $mk SRC) in *'`'*) return;; esac
  read flags files < <(program_args $mk)
  (ulimit -v 12000000 2> /dev/null; timeout 120 $ANALYZE -facts -L lib_core ${flags//,/ } $files) > $W/$name.facts 2> $W/$name.err
  if [ -s $W/$name.err ]; then printf '%-40s not read\n' $dir; return; fi
  queries $W/$name.out $W/$name.facts || { printf '%-40s past the limit\n' $dir; return; }
  printf '%-40s %5d %7d %6d  %s\n' $dir $(grep -c '^cap_call' $W/$name.out) $(grep -c '^checked' $W/$name.out) $(grep -c '^mismatch' $W/$name.out) \
    "$(grep '^not_seen' $W/$name.out | sed -E "s/.*,'?([^,']*)'?\)\.$/\1/" | sort | uniq -c | awk '{ c = $1; $1 = ""; printf "%s:%s; ", $0, c }')"
  grep -E '^(mismatch|by_need)' $W/$name.out | sed "s/^/    /" | head -${SHOW:-8}
  [ -n "$BLIND" ] && grep -E '^handed_' $W/$name.out | sed "s/^/    /" | head -$BLIND
  printf '%-40s by need %d; handed to a function not known to take one %d, in dead code %d\n' "" $(grep -c '^by_need' $W/$name.out) $(grep -c '^handed_unknown' $W/$name.out) $(grep -c '^handed_in_dead' $W/$name.out)
}
export -f one queries
export SHOW LIMIT BLIND

if [ "${1:-}" = -all ] || [ "${1:-}" != -record -a $# -gt 0 ]; then
  printf '%-40s %5s %7s %6s  %s\n' program calls checked wrong 'not seen'
  if [ "$1" = -all ]; then list=$(programs); else list=$(for d in "$@"; do echo $d/mkfile; done); fi
  echo "$list" | xargs -P 8 -n 1 bash -c '. analyzers/datalog/tests/mk_units.sh; one "$0"'
  exit 0
fi

failures=0
d=$T/caps_wrong
$ANALYZE -facts $d/*.ml > $W/facts 2>&1
queries $W/out $W/facts
{ grep '^mismatch' $W/out | sed -E "s/mismatch\('?([^,']*)'?,'[^']*','?([^,']*)'?,'?([^,')]*)'?\)\./\1 gives \2, which asks \3/" | sort
  echo "$(grep -c '^cap_call' $W/out) calls, $(grep -c '^checked' $W/out) checked"
  grep '^not_seen' $W/out | sed -E "s/.*,'?([^,']*)'?\)\.$/not seen: \1/" | sort | uniq -c |
    # (the count in 7 columns, GNU's uniq's; BSD's, macOS's, pads to 4)
    awk '{ n = $1; sub(/^ *[0-9]+ /, ""); printf "%7d %s\n", n, $0 }'
} > $W/expected.out
if [ "${1:-}" = -record ]; then cp $W/expected.out $d/expected.out; echo "recorded $d/expected.out"
elif cmp -s $W/expected.out $d/expected.out; then echo "ok capabilities as OCaml's types: what it refuses found"
else echo "FAIL capabilities as OCaml's types"; diff $d/expected.out $W/expected.out | head -12; failures=1; fi
exit $failures
