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
# there and tiny-utils's goes on to the next file, as all its filters do;
# cp f f, which the twin refuses and tiny-utils's cp does harmlessly (it
# reads the file whole before it writes the copy); mv of a directory
# into another directory, which the twin refuses (a move between two
# directories is a copy and a remove in 9P) and the host's rename does;
# sleep x, which the twin reads as 0 and tiny-utils refuses.
# Then ln, checked by itself, and tiny-utils run by a link named after
# a utility.
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
  printf 'hello' > p; : > empty
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
same "" - cp f g
same "" - cp f d
same "" - cp f p d/e
same "" - cp f p l1
same "" - cp nosuch g
same "" - cp d g
same "" - cp
same "" - mv f g
same "" - mv f d
same "" - mv f p d/e
same "" - mv d dd
same "" - mv d/e d/ee
same "" - mv nosuch g
same "" - mv f p l1
same "" - touch f new
same "" - touch d/e/new2
same "" - touch nosuch/x
same "" - pwd
same "" - sleep 0
same "" - sleep .1
same "" - test
same "" - test -f f
same "" - test -f d
same "" - test -d d
same "" - test -e nosuch
same "" - test -s f
same "" - test -s empty
same "" - test -n ""
same "" - test -z ""
same "" - test abc
same "" - test ""
same "" - test a = a
same "" - test a != a
same "" - test 3 -lt 10
same "" - test 10 -le 3
same "" - test 4 -eq 4 -a 5 -gt 6
same "" - test ! -f f
same "" - test -f nosuch -o -d d
same "" - test ! -f f -o -d d
same "" - test "(" -f f -a -d nosuch ")" -o a = a
same "" - test -f f -a "(" -d nosuch -o -e p ")"
same "" - test "(" -f f
same "" - test -f
same "" - test a b

# ln, which has no twin (Plan 9 has no hard links): checked by itself.
# [check NAME COMMANDS]: COMMANDS succeed, in a fresh directory
check() {
  n=$((n + 1)); setup
  if ! (eval "$2") > $W/check.out 2>&1; then failures=$((failures + 1)); echo "FAIL ln: $1"; cat $W/check.out | head -5; fi
}
check "the same bytes by a second name" '$TU ln f g && cmp -s f g'
check "a write by one name seen by the other" '$TU ln f g && echo more >> g && tail -1 f | grep -q more'
check "the file kept when its first name goes" '$TU ln f g && rm f && [ "$(head -1 g)" = "hello world" ]'
check "into a directory, under its own name" '$TU ln f p d && cmp -s f d/f && cmp -s p d/p'
check "a directory refused" '! $TU ln d dd 2>/dev/null && [ ! -e dd ]'
check "a file that is not there refused" '! $TU ln nosuch g 2>/dev/null'
check "a name already there refused" '! $TU ln f p 2>/dev/null && [ "$(cat p)" = hello ]'

# by a link named after the utility
setup
ln -s $TU wc
n=$((n + 1))
[ "$(./wc -l nums)" = "     40 nums" ] || { failures=$((failures + 1)); echo "FAIL wc by a link: $(./wc -l nums)"; }
# and [, which is test with a ] at the end
ln -s $TU [
n=$((n + 1))
[ "$(./[ -f f ]; echo $?; ./[ -d f ]; echo $?; ./[ -f f 2>/dev/null; echo $?)" = "$(printf '0\n1\n1')" ] || { failures=$((failures + 1)); echo "FAIL [ by a link"; }

if [ $failures = 0 ]; then echo "ok $n cases: the same as the twins, and ln as it should"; else echo "FAIL $failures of $n cases"; exit 1; fi
