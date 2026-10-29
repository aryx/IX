#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The fixed point of ix built by ix (plan_mkfiles.md, steps 3 and 4): ix
# built from nothing by mini-mk over the mkfiles, first by the programs
# dune built (./bin), then by the programs of that first build alone
# (mini-ml compiled by mini-ml, mini-ld linked by mini-ld, the mkfiles
# run by mini-mk...). Every file of the two builds is the same, to the
# byte: objects, libraries, the lexers and parsers written, programs.
# So a third build, by the second's programs, would be the second again.
#
# For arm (fixpoint.sh 5) the second build's programs run under
# qemu-arm, their ints of 31 bits, the first's were the host's, of 63:
# as the card's against Linux's (make self-mix), so a value one takes
# whole and the other wraps is another file here (Sha1's and Chacha20's
# summaries, bugs/ix.md), not after two hours of self-mix.
# old: a third build, by the second's programs, the same as the second,
# the first allowed to differ (said: C objects' shared constants; they
# were those summaries, 6 files, and passed)
# usage: mkfiles/fixpoint.sh [7|5]   (after dune build; 7, arm64: about
#   10 minutes; 5: about an hour)

# (the mkfiles' recipes are rc's: mkfiles/mkconfig)
export MKSHELL=mini-rc
O=${1:-7}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
W=$(mktemp -d); trap 'rm -rf $W' EXIT
cd $ROOT
build() {   # the build's number, the PATH
  rm -rf _mk/$O
  PATH=$2 mini-mk O=$O > $W/$1.log 2>&1 || { echo "FAIL build $1: $(grep -v '^mini-\|^mkdir\|^for \|^if ' $W/$1.log | tail -3 | cut -c1-300)"; exit 1; }
  mv _mk/$O $W/$1
  mkdir $W/bin$1
  cp $(find $W/$1 -name 'mini-*' -type f) $W/bin$1/
}
build 1 $ROOT/bin:$PATH
echo "ok the first build, by dune's programs: $(find $W/1 -type f | wc -l) files, $(ls $W/bin1 | wc -l) programs ($(ls $W/bin1 | tr '\n' ' '))"
# only those programs, and the system's (the shell, ls, mkdir): not ./bin, not what make install put in the PATH
build 2 $W/bin1:/usr/bin:/bin
cp -r $W/2 _mk/$O
if diff -rq $W/1 $W/2 > $W/diff.txt; then echo "ok the second build, by the first's programs: the same $(find $W/2 -type f | wc -l) files"
else echo "FAIL the second build differs:"; head -20 $W/diff.txt; exit 1; fi
