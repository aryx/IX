#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-analyze on mini-9pi's kernel, as sweep.sh on the programs: its
# units (kernels/9pi/mkfile's KML), their -Is (KI), their order of start
# (-start, KML's: what bugs/init.dl compares), lib_core and lib_machine.
# The kernel's lines of bugs_ix.txt (-bugs) are this one's.
# usage: analyzers/datalog/tests/kernel.sh flag out [option...]
#   (dune build first; ANALYZE: the program, if not dune's)
cd "$(dirname "$0")/../../.."
T=$PWD; F=$1; O=$2; shift 2
case $O in /*) ;; *) O=$T/$O;; esac
cd kernels/9pi
list() { # the mkfile's variable $1, a word each, $UREG and $GFX said
  sed -n "/^$1=/,/^[A-Z#]/p" mkfile | sed '$d' | sed "s/^$1=//; s/\\\\//" |
    tr -s ' \n' ' ' | sed 's/\$UREG/syscalls\/arm/g; s/\$GFX/lib_graphics/g'
}
KML=$(list KML); KI=$(list KI)
files=""; for u in $KML; do files="$files $u.ml"; done
START=$(for u in $KML; do b=$(basename $u); echo -n "${b^} "; done)
(ulimit -v 12000000
 timeout 900 ${ANALYZE:-$T/_build/default/analyzers/Main.exe} $F \
   -r $T/analyzers/datalog -start "$START" "$@" -L ../../lib_core $KI \
   -I ../lib_machine $files) > $O 2>&1
