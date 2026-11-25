#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# plan_analysis_scale.md's numbers: mini-analyze FLAG on each program of
# ix's build, by its manifest (mini-ld -map's), its run timed (seconds,
# peak memory) and its facts counted (a -facts run of the same program):
# the program's own units', the library's, the primitives'. A line a
# program in out-dir/TABLE: name, own lines, facts own, facts library,
# facts prim, seconds, MB.
# (old: the 44 programs by sweep.sh, read from their mkfiles)
# usage: docs/plans/analysis_scale/measure.sh -dead|-bugs|-exn out-dir
#   MK: the build (_mk/7: make ix first); minutes, -exn's more.
# ANALYZE: the program, if not dune's.
cd "$(dirname "$0")/../../.."
export LC_ALL=C
flag=$1; out=$(realpath -m $2); mkdir -p $out/runs
export real=${ANALYZE:-$PWD/_build/default/analyzers/Main.exe} flag out MK=${MK:-_mk/7}
one() { # a manifest
  local m=$1 n own
  n=$(echo ${m#$MK/} | sed 's/\.manifest$//' | tr / _)
  # (its own files, the ones it gives: -v's "a file given")
  $real -facts -v $m > $out/runs/$n.f 2> $out/runs/$n.v
  sed -nE 's/.*reading (.*) \(a file given\)/\1/p' $out/runs/$n.v > $out/runs/$n.files
  own=" $(xargs -n1 basename < $out/runs/$n.files | sed 's/\.ml$//; s/^./\U&/' | tr '\n' ' ')"
  awk -F"'" -v own="$own" '
    { u = $2; sub(/[.:].*/, "", u)
      if (u == "prim") p++; else if (index(own, " " u " ")) o++; else l++ }
    END { printf "%d %d %d\n", o, l, p }' $out/runs/$n.f > $out/runs/$n.facts
  rm -f $out/runs/$n.f
  timeout 900 /usr/bin/time -f '%e %M' -o $out/runs/$n.time $real $flag $m > /dev/null 2>&1
}
export -f one
find $MK -name '*.manifest' | sort | xargs -P 8 -n 1 bash -c 'one "$0"'
for f in $out/runs/*.time; do
  n=$(basename $f .time)
  loc=$(cat $(cat $out/runs/$n.files) 2> /dev/null | wc -l)
  read o l p < $out/runs/$n.facts
  read s m < <(tail -1 $f)
  printf '%-40s %6d %8d %8d %6d %7.1f %6d\n' $n $loc $o $l $p $s $((m / 1024))
done | sort -k2 -n > $out/TABLE
echo "name lines own library prim s MB" | cat - $out/TABLE
