#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# plan_caps_syscalls.md's census: capabilities.dl with the plan's
# requires rows for the clock, pipes, and the process's own facts under
# env (a copy of the rules), mini-analyze -caps over the 44 programs,
# and the functions that would need one of them, each site once:
# sites.txt.
# usage: docs/plans/caps_syscalls/census.sh out-dir   (dune build first;
# minutes: sweep.sh's)
cd "$(dirname "$0")/../../.."
out=$(realpath -m $1); mkdir -p $out
rm -rf $out/rules; cp -r analyzers/datalog $out/rules
cat >> $out/rules/capabilities.dl <<'EOF'
requires('Unix.gettimeofday', clock).
requires('Unix.time', clock).
requires('prim:sys_time', clock).
requires('Unix.sleepf', clock).
requires('Unix.pipe', pipe).
requires('Unix.socketpair', pipe).
requires('Unix.getpid', env).
requires('Unix.getppid', env).
requires('Unix.getcwd', env).
requires('prim:sys_getcwd', env).
requires('Unix.gethostname', env).
EOF
cp _build/default/analyzers/Main.exe $out/analyze.exe
printf '#!/bin/bash\nexec %s -r %s "$@"\n' $out/analyze.exe $out/rules \
  > $out/analyze.sh
chmod +x $out/analyze.sh
FLAG=-caps ANALYZE=$out/analyze.sh \
  analyzers/datalog/tests/sweep.sh $out/sweep 300 > /dev/null
# (Cap.env for what it did not need before: the pid, the directory, the
# machine's name)
new='Cap\.(clock|pipe) |Cap\.env \([^)]*(getpid|getppid|getcwd|gethostname)'
cat $out/sweep/*.out | grep -E "$new" |
  grep -v 'functions with no capability' | sort -u > $out/sites.txt
wc -l < $out/sites.txt
