#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The test of TinyUtilities.ml: each utility of tiny-utils and its twin
# of m-ix's utilities/ (mini-wc for wc...) run on the same arguments and
# the same input, in a directory made here. Their standard output and
# their exit status must be the same. Standard error is not compared:
# tiny-utils words all its errors as "tool: file: reason" on purpose.
# A case marked "sorted" compares the outputs sorted: du -a lists in
# name order, where the twin keeps the directory's order. Not tested:
# cat with a file it cannot open before others, as Plan 9's cat stops
# there and tiny-utils's goes on to the next file, as all its filters do.
# Then tiny-utils run by a link named after a utility.
# usage: TinyUtilities_test.sh

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
TU=${TU:-$ROOT/_build/default/tiny/TinyUtilities.exe}
MINI=${MINI:-$ROOT/bin}
[ -x $MINI/mini-wc ] || { echo "skip TinyUtilities_test.sh (no m-ix utilities in $MINI)"; exit 0; }
W=$(mktemp -d); trap 'rm -rf $W' EXIT
failures=0 n=0

# a fresh directory for each case, as removing and making change it
setup() {
  rm -rf $W/t; mkdir $W/t; cd $W/t
  printf 'hello world\nsecond line\n\nlast' > f
  printf 'hello' > p
  printf 'a\nb\n' > l1; printf 'a\nc\n' > l2
  seq 1 40 > nums
  printf '\001\t\r\n\177 ok' > bin
  mkdir -p d/e "a dir"; echo x > d/e/g; echo yy > d/h
  head -c 3000 nums > d/big
}

# [same input mode utility args...]: input is what is given on stdin
same() {
  local input=$1 mode=$2 tool=$3; shift 3
  n=$((n + 1))
  local a b
  setup; a=$(printf '%s' "$input" | $TU $tool "$@" 2>/dev/null; echo "status $?"; ls -R)
  setup; b=$(printf '%s' "$input" | $MINI/mini-$tool "$@" 2>/dev/null; echo "status $?"; ls -R)
  if [ "$mode" = sorted ]; then a=$(echo "$a" | sort); b=$(echo "$b" | sort); fi
  if [ "$a" != "$b" ]; then
    failures=$((failures + 1)); echo "FAIL $tool $*"
    diff <(echo "$b") <(echo "$a") | head -10
  fi
}

same "" - cat f
same "" - cat f p nosuch
same "from stdin" - cat
same "" - echo hello   world
same "" - echo -n no newline
same "" - echo
same "" - wc f
same "" - wc f p d/h
same "" - wc -l nums
same "" - wc -w -c f
same "  two  words
and three more " - wc
same "" - wc nosuch
same "" - tail nums
same "" - tail -3 nums
same "" - tail -n 1 f
same "" - tail -2 f
same "" - tail +38 nums
same "a
b
c
" - tail -2
same "tee'd" - tee out1 out2
same "" - xd f
same "" - xd -b f
same "" - xd -c f
same "" - xd -c bin
same "" - xd nums
same "ab" - xd
same "" - ls
same "" - ls d
same "" - ls d/ f
same "" - ls .
same "" - ls d/h
same "" - ls nosuch
same "" - walk
same "" - walk d
same "" - walk d/h
same "" - du
same "" - du d
same "" - du d/h
same "" sorted du -a d
same "" - rm f
same "" - rm d
same "" - rm nosuch
same "" - rm -r d
same "" - mkdir x y
same "" - mkdir d
same "" - mkdir -p d/e/f/g
same "" - mkdir q/r
same "" - seq 3
same "" - seq 0
same "" - seq 2 5
same "" - seq 1 3 10
same "" - seq 10 -3 1
same "" - basename /a/b.c
same "" - basename /a/b.c .c
same "" - basename b.c b.c
same "" - basename a/b/
same "" - basename -d a/b
same "" - basename -d b
same "" - cmp f f
same "" - cmp f p
same "" - cmp p f
same "" - cmp l1 l2
same "" - cmp -s l1 l2
same "" - cmp f nosuch

# by a link named after the utility
setup
ln -s $TU wc
n=$((n + 1))
[ "$(./wc -l nums)" = "     40 nums" ] || { failures=$((failures + 1)); echo "FAIL wc by a link: $(./wc -l nums)"; }

if [ $failures = 0 ]; then echo "ok $n cases, the same as the twins"; else echo "FAIL $failures of $n cases"; exit 1; fi
