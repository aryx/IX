#!/bin/sh
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# Where a program's instructions go, function by function
# (docs/notes/notes_profiling_techniques.md): an arm program of mini-ml's (or
# mini-cc's) run by mini-5i -t, each instruction's address counted, and
# the addresses charged to the function they are in, by the listing of
# its link (mini-ld -v with the program's own link command: its lines
# "address: word TEXT name+0(SB), $frame"). Every instruction, not a
# sample: the same numbers each time, on any host.
#
#   usage: profile.sh [-n lines] listing program [args...]
#
#   cd apps/music/play && mini-mk O=5      its link's command is printed
#   mini-ld -v ...the same... -o /tmp/play5 > /tmp/play5.lst
#   machine/tests/profile.sh /tmp/play5.lst /tmp/play5 -c -s 0.2 tune.mod
#
# The listing and the program are to be one link's: after a rebuild the
# names are a few functions off, and nothing says so. A trace is a line
# an instruction: a hundred million instructions is a few minutes, so
# the run is the shortest that has the steady part in it (and what the
# start costs is known by a run that stops before it: -s 0, 5 frames).
# A function's name is mini-ml's: f8_next is the eighth unit's next;
# name<> is a function local to its file (the runtime's copy<>: the
# collector copying).
n=40
[ "$1" = -n ] && { n=$2; shift 2; }
[ $# -ge 2 ] || { sed -n '5,25p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
lst=$1; shift
T=$(mktemp -d); trap 'rm -rf $T' EXIT
mini-5i -t "$@" 2>&1 > /dev/null | awk '{ c[$1]++ } END { for (a in c) print a, c[a] }' > $T/addr
grep 'TEXT' "$lst" | awk '{ sub(":", "", $1); sub(/\+0\(SB\),?/, "", $4); print $1, $4 }' > $T/syms
python3 - $T/syms $T/addr $n <<'PY'
import sys, bisect
syms = sorted((int(a, 16), n) for a, n in (l.split()[:2] for l in open(sys.argv[1])))
starts = [a for a, _ in syms]
total, all = {}, 0
for l in open(sys.argv[2]):
    f = l.split()
    try: a, c = int(f[0], 16), int(f[1])
    except (ValueError, IndexError): continue       # (a line of the program's own on stderr)
    i = bisect.bisect_right(starts, a) - 1
    name = syms[i][1] if i >= 0 else "?"
    total[name] = total.get(name, 0) + c
    all += c
print(all, "instructions")
for name, c in sorted(total.items(), key=lambda x: -x[1])[:int(sys.argv[3])]:
    print("%5.1f%% %11d %s" % (100 * c / all, c, name))
PY
