#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# plan_analysis_scale.md's numbers: mini-analyze FLAG on the 44 programs
# (sweep.sh's), each program's run timed (seconds, peak memory) and its
# facts counted (a -facts run of the same arguments): the program's own
# units', lib_core's, the primitives'. A line a program in out-dir/TABLE:
# name, own lines, facts own, facts lib_core, facts prim, seconds, MB.
# usage: docs/plans/analysis_scale/measure.sh -dead|-bugs|-exn out-dir
#   (dune build, ix built: sweep.sh's; minutes, -exn's more)
# ANALYZE: the program, if not dune's.
cd "$(dirname "$0")/../../.."
export LC_ALL=C
flag=$1; out=$(realpath -m $2); mkdir -p $out/runs
real=${ANALYZE:-$PWD/_build/default/analyzers/Main.exe}
# the wrapper sweep.sh runs: the facts counted, then the analysis timed;
# a run keyed by its files (sweep.sh's name.files say which program)
cat > $out/wrap.sh <<EOF
#!/bin/bash
files=\$(printf '%s\n' "\$@" | grep -E '\.(ml|c)\$' | sort | md5sum | cut -c1-12)
own=\$(printf '%s\n' "\$@" | grep -E '\.ml\$' | xargs -n1 basename | sed 's/\.ml\$//; s/^./\U&/' | tr '\n' ' ')
$real -facts "\${@:2}" 2> /dev/null |
  awk -F"'" -v own=" \$own" '{ u = \$2; sub(/[.:].*/, "", u)
    if (u == "prim") p++; else if (index(own, " " u " ")) o++; else l++ }
    END { printf "%d %d %d\n", o, l, p }' > $out/runs/\$files.facts
/usr/bin/time -f '%e %M' -o $out/runs/\$files.time $real "\$@"
EOF
chmod +x $out/wrap.sh
rm -rf $out/sweep
FLAG=$flag ANALYZE=$out/wrap.sh analyzers/datalog/tests/sweep.sh $out/sweep 900 \
  > $out/sweep.log 2>&1
for f in $out/sweep/*.files; do
  n=$(basename $f .files)
  k=$(tr ' ' '\n' < $f | grep . | sort | md5sum | cut -c1-12)
  [ -f $out/runs/$k.time ] || continue
  loc=$(cat $(cat $f) 2> /dev/null | wc -l)
  read o l p < $out/runs/$k.facts
  read s m < <(tail -1 $out/runs/$k.time)
  printf '%-40s %6d %8d %8d %6d %7.1f %6d\n' $n $loc $o $l $p $s $((m / 1024))
done | sort -k2 -n > $out/TABLE
echo "name lines own lib_core prim s MB" | cat - $out/TABLE
