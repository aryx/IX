#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-datalog's time on programs made here (the numbers of
# languages/datalog/README.md): the paths of a chain of N nodes
# (N(N+1)/2 tuples, N rounds: the worst for the rounds) with the
# recursion on the left and on the right, the semi-naive way and the
# naive one; and the author's pointer analysis
# (analyses/pointer.dl) on M assignments made by a generator of random
# numbers written here, the same on every machine.
# For each: the build, the seconds, the memory, the engine's own counts.
# usage: languages/datalog/tests/bench.sh [N] [M]   (dune build, and mini-mk in languages/datalog, first)
cd "$(dirname "$0")/../../.."
N=${1:-1000}; M=${2:-1000}
W=$(mktemp -d); trap 'rm -rf $W' EXIT
chain() {   # $1: left or right, $2: the nodes
  if [ $1 = left ]; then echo 'path(X, Y) :- edge(X, Y). path(X, Y) :- path(X, Z), edge(Z, Y).'
  else echo 'path(X, Y) :- edge(X, Y). path(X, Y) :- edge(X, Z), path(Z, Y).'; fi
  awk -v n=$2 'BEGIN { for (i = 0; i < n; i++) printf "edge(n%d, n%d).\n", i, i + 1 }'
}
# p = &x, p = q, *p = q, p = *q, by a linear congruential generator: a
# fifth of the variables have their address taken
assignments() {
  awk -v m=$1 'BEGIN { s = 12345; v = int(m / 4) + 2
    for (i = 0; i < m; i++) {
      s = (s * 1103515245 + 12345) % 2147483648; a = int(s / 65536) % v
      s = (s * 1103515245 + 12345) % 2147483648; b = int(s / 65536) % v
      s = (s * 1103515245 + 12345) % 2147483648; k = int(s / 65536) % 10
      if (k < 2) printf "assign_address(v%d, v%d).\n", a, b
      else if (k < 8) printf "assign(v%d, v%d).\n", a, b
      else if (k < 9) printf "assign_deref(v%d, v%d).\n", a, b
      else printf "assign_content(v%d, v%d).\n", a, b } }'
}
chain left $N > $W/left.dl; chain right $N > $W/right.dl; chain left $((N / 5)) > $W/small.dl
assignments $M > $W/facts.dl
one() {   # $1: what, the rest: the command
  local what=$1; shift
  [ -x "$1" ] || return
  /usr/bin/time -f "%es %MKB" "$@" 2> $W/err > /dev/null
  printf "%-44s %-12s %s | %s\n" "$what" "$(tail -1 $W/err)" "$(basename $1 | sed 's/Main.exe/by dune/; s/mini-datalog/by mini-ml/')" "$(grep rounds $W/err)"
}
for X in _build/default/languages/datalog/Main.exe _mk/7/languages/datalog/mini-datalog; do
  one "a chain of $N, recursion on the left" $X -s $W/left.dl
  one "a chain of $N, recursion on the right" $X -s $W/right.dl
  one "a chain of $((N / 5)), semi-naive" $X -s $W/small.dl
  one "a chain of $((N / 5)), naive" $X -naive -s $W/small.dl
  one "pointer analysis, $M assignments" $X -s languages/datalog/analyses/pointer.dl $W/facts.dl
done
