#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-analyze on Plan 9's rc, goken's (plan_dotnet_languages.md, step
# 0's numbers): its 30 files as one program, the report, and the time
# of the front end (-facts) and of the whole. By hand: it needs a
# goken checkout, which make test does not take.
# usage: analyzers/tests/rc.sh   (dune build first)
# GOKEN: goken's checkout (~/goken); ANALYZE: the program, if not dune's.
cd "$(dirname "$0")/../.."
GOKEN=${GOKEN:-$HOME/goken}
ANALYZE=${ANALYZE:-$PWD/_build/default/analyzers/Main.exe}
RULES=$PWD/languages/datalog/analyses
[ -d $GOKEN/rc ] || { echo "no $GOKEN/rc"; exit 2; }
cd $GOKEN/rc
# (main's files on Linux: goken.c's, notify_full's, rfork_fork's, not plan9.c, unix.c, the windows ones)
F="builtins.c code.c env.c error.c exec.c executils.c fmt.c getflags_.c globals.c glob.c goken.c here.c input.c io.c lex.c main.c notify_full.c path.c pcmd.c pfnc.c processes.c rfork_fork.c simple.c status.c trap.c tree.c utils.c var.c words.c y.tab.c"
I="-I $GOKEN/include/ALL -I $GOKEN/include/arch/arm64 -I $GOKEN/include"
t0=$(date +%s.%N)
facts=$($ANALYZE -facts $I $F | wc -l)
t1=$(date +%s.%N)
$ANALYZE -r $RULES $I $F
t2=$(date +%s.%N)
printf "%d facts; the front end %.1f s, all %.1f s\n" $facts $(echo "$t1 - $t0" | bc) $(echo "$t2 - $t1" | bc)
