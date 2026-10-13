#!/bin/sh
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The functions of a trace: what a program of mini-ml's says after an
# uncaught exception,
#
#   Thread 5 killed on uncaught exception Invalid_argument("index out of bounds")
#   raised at: 9c30 9cf0 9df4 16628
#
# are addresses of calls, the innermost first (languages/ml/runtime's
# exceptions.c says how they are found, and what they are worth). The
# map mini-ld writes beside each program it links (-map: program.map,
# a function's address and its name a line) says which function each
# is in.
#
#   usage: scripts/where.sh program address...
#
#   scripts/where.sh _mk/5-plan9/games/arcade/tinybreakout 9c30 9cf0 9df4
#
# The program is the one that ran: the same build (mini-9pi's are under
# _mk/5-plan9, as kernels/9pi/Makefile's CARD_ lists say). A name is
# mini-ml's: f12_find<> is a function find of the twelfth unit linked,
# name<> one local to its file.
[ $# -ge 2 ] || { sed -n '5,23p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
map=$1.map; shift
[ -f "$map" ] || { echo "no $map: link the program again (mini-ld -map, mkfiles/mkconfig's LD)"; exit 1; }
for a in "$@"; do
  awk -v a="$a" '
    function hex(s,   i, n, c) { n = 0; s = tolower(s); sub(/^0x/, "", s)
      for (i = 1; i <= length(s); i++) { c = index("0123456789abcdef", substr(s, i, 1)); if (c == 0) return -1; n = n * 16 + c - 1 }
      return n }
    BEGIN { want = hex(a) }
    { v = hex($1); if (v <= want && v >= best) { best = v; name = $2 } }
    END { if (name == "") print a, "?"; else printf "%s %s+%d\n", a, name, want - best }' "$map"
done
