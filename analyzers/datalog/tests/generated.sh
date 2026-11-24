#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The units ix's build makes (a .mll's lexer by mini-lex, a .mly's
# parser by mini-yacc, mini-smalltalk's St_kernel), in DIR as it puts
# them in _mk/7: each mkfile's GEN, made alone by mini-mk, not the
# programs. For ix_check.sh (MK=DIR) where _mk/7 is not built: it reads
# ix's sources, and these are the 44 programs' units that are not files
# of the tree. A few seconds.
# usage: analyzers/datalog/tests/generated.sh DIR   (dune build first: bin/'s mini-mk, mini-lex, mini-yacc)
cd "$(dirname "$0")/../../.."
ROOT=$PWD
X=$(mkdir -p "$1" && cd "$1" && pwd)
export PATH=$ROOT/bin:$PATH MINI=mini-
# (the tree's mkfiles: not a worktree's under .claude/, an older ix
# whose parsers would be made in the same places)
mkfiles=$(git ls-files '*mkfile' 2> /dev/null ||
          find . -mindepth 1 \( -name '_*' -o -name '.*' \) -prune -o -name mkfile -print | sed 's,^\./,,')
for mk in $(grep -l '^GEN=.' $mkfiles | sort); do
  d=$(dirname $mk)
  targets=$(sed -n 's/^GEN=//p' $mk | sed "s|\$B|$X|g")
  (cd $d && mini-mk B=$X $targets) > $X/mk.log 2>&1 ||
    { echo "generated.sh: $mk's GEN:"; tail -3 $X/mk.log; exit 1; }
done
# and three a mkfile makes outside its GEN, which its objects' rules
# name: mini-troff's pic parser (mini-man's), mini-squeak's Which
for t in typesetting/troff/Pic_parser.ml kernels/squeak/Which.ml; do
  (cd $(dirname $t) && mini-mk B=$X $X/$t) > $X/mk.log 2>&1 ||
    { echo "generated.sh: $t:"; tail -3 $X/mk.log; exit 1; }
done
# mini-datalog's Parallel, copied by the rule of its object, which
# compiles it (its mkfile's: lib_core's single-core implementation)
mkdir -p $X/languages/datalog
cp lib_core/parallel/Parallel.mli $X/languages/datalog/Parallel.mli
cp lib_core/parallel/host/single.ml.in $X/languages/datalog/Parallel.ml
rm -f $X/mk.log
