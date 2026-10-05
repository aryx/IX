#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The utilities against principia's (plan_rio.md): each of ix's, built
# for Plan 9 (mini-mk O=5 OS=plan9 in utilities/*), and principia's own
# arm binary of the same name, both run by mini-5i on the same
# arguments in a directory made here: the same output, errors and exit
# status. (Not ls -s, -t alone, -y: mini-5i takes them for its own.)
# usage: utilities/tests/differential.sh     (PRINCIPIA: default ~/principia)

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
U=$ROOT/_mk/5-plan9/utilities
P=${PRINCIPIA:-$HOME/principia}/ROOT/arch/arm/bin
M=$ROOT/bin/mini-5i
[ -x $P/ls ] || { echo "skipped: no principia binaries in $P"; exit 0; }
[ -x $U/files/mini-ls ] || { echo "FAIL: not built (mini-mk O=5 OS=plan9 in utilities/files, misc, namespace)"; exit 1; }
W=$(mktemp -d); trap 'rm -rf $W' EXIT
cd $W
mkdir -p sub "a dir"; echo hi > f1; echo there > "it's"; echo x > sub/inner; chmod 755 f1; touch "sp ace"
# each its own time: for ls -t, equal times are in the order of ls.c's
# qsort (not a stable one), which mini-ls does not copy
k=0; for f in old f1 "it's" "sp ace" sub/inner sub "a dir"; do k=$((k + 1)); touch -d "2020-01-0$k 03:04" "$f"; done

n=0; failures=0
# ours, theirs, the arguments
same() {
  local ours=$1 theirs=$2; shift 2
  n=$((n + 1))
  local a b
  a=$($M $ours "$@" 2>&1 < /dev/null | tr -d '\0'; echo "status ${PIPESTATUS[0]}")
  b=$($M $theirs "$@" 2>&1 < /dev/null | tr -d '\0'; echo "status ${PIPESTATUS[0]}")
  # (a program names itself by its path: principia's, here ours)
  b=${b//$theirs/$ours}
  if [ "$a" != "$b" ]; then failures=$((failures + 1)); echo "FAIL $(basename $theirs) $*"; diff <(echo "$a") <(echo "$b") | head -6; fi
}
while read -r args; do eval "same $U/files/mini-ls $P/ls $args"; done <<'END'

-l
-d .
-ld sub f1
sub f1
-F
-m
-q
-lt
-ltr
-r
-n
-p sub
-Q
-lu
-T
nonexistent
nonexistent f1
-z
sub/
sub//inner
$W/f1
-lQF sub f1 old
f1 sub old
-lm 'a dir' "it's"
-d / /tmp
END
while read -r args; do eval "same $U/files/mini-cat $P/cat $args"; done <<'END'
f1
f1 old sub/inner
nonexistent
sub
"it's" "sp ace"
END
while read -r args; do eval "same $U/misc/mini-echo $P/echo $args"; done <<'END'
a b

-n a
-n
a -n
--
"two  words" x
END
while read -r args; do eval "same $U/namespace/mini-bind $P/bind $args"; done <<'END'

-x a b
a
-ab a b
/nonexistent f1
f1 /nonexistent
-q /nonexistent f1
END
while read -r args; do eval "same $U/namespace/mini-mount $P/mount $args"; done <<'END'

-x
/nonexistent sub
-q /nonexistent sub
-ab f1 sub
f1
END
echo "ok $((n - failures)) of $n cases as principia's"
[ $failures = 0 ]
