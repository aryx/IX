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
[ -x $U/compare/mini-cmp ] || { echo "FAIL: not built (mini-mk O=5 OS=plan9 in utilities/files, misc, namespace, time, pipe, compare)"; exit 1; }
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
# the programs that change files: each of the two in its own copy of
# the directory, and what is there after (the names, the modes, the
# files' bytes) compared too
changed() {
  local ours=$1 theirs=$2; shift 2
  n=$((n + 1))
  local a b
  rm -rf $W.a $W.b; cp -a $W $W.a; cp -a $W $W.b
  after() { find . -printf '%p %m %y\n' | sort; find . -type f | sort | xargs -d '\n' cat; }
  a=$(cd $W.a && { $M $ours "$@" 2>&1 < /dev/null | tr -d '\0'; echo "status ${PIPESTATUS[0]}"; after; })
  b=$(cd $W.b && { $M $theirs "$@" 2>&1 < /dev/null | tr -d '\0'; echo "status ${PIPESTATUS[0]}"; after; })
  b=${b//$theirs/$ours}; b=${b//$W.b/$W.a}
  if [ "$a" != "$b" ]; then failures=$((failures + 1)); echo "FAIL $(basename $theirs) $*"; diff <(echo "$a") <(echo "$b") | head -6; fi
}
trap 'rm -rf $W $W.a $W.b' EXIT
changed $U/files/mini-pwd $P/pwd
while read -r args; do eval "changed $U/files/mini-mkdir $P/mkdir $args"; done <<'END'

new
new other
sub
f1
sub/inner/x
nothere/x
-p nothere/x/y
-p sub/inner
-p sub/a/b new
-p /nonexistent/x
-m 750 new
-m700 new
-pm 700 new/x
-m
-m 1000 new
-x new
-- -x
END
while read -r args; do eval "changed $U/files/mini-rm $P/rm $args"; done <<'END'

f1
f1 old "it's"
nonexistent
nonexistent f1
sub
"a dir"
-r sub
-r sub f1 nonexistent
-f nonexistent
-rf nonexistent sub
-f sub
-x f1
sub/inner sub
END
# (not cp's usage, nor -g, -u, -x: mini-cp has no option)
while read -r args; do eval "changed $U/files/mini-cp $P/cp $args"; done <<'END'
f1 new
f1 old
f1 sub
f1 old sub
f1 old new
f1 f1
f1 sub/../f1
sub new
nonexistent new
f1 nonexistent/new
sub/inner .
sub/inner "a dir"
"it's" "sp ace"
nonexistent f1 sub
END
while read -r args; do eval "changed $U/files/mini-mv $P/mv $args"; done <<'END'

f1
f1 new
f1 old
f1 f1
f1 ./f1
f1 sub
f1 old sub
f1 old new
f1 sub/new
sub/inner .
sub/inner sub/renamed
sub new
sub "a dir"
sub nonexistent/new
nonexistent new
f1 nonexistent/new
sub//inner ./sub/../moved
"it's" "sp ace"
f1 sub/
END
# (mini-5i's wstat changes no time: what touch makes is compared, not its
# time; and -t alone is mini-5i's own: its value is written after it)
while read -r args; do eval "changed $U/files/mini-touch $P/touch $args"; done <<'END'

new
f1 new other
-c new
-c f1
-t1000000000 f1
-t1000000000 new
-tabc new
-ct5 nonexistent
-x new
nonexistent/new
sub
END
while read -r args; do eval "changed $U/files/mini-chmod $P/chmod $args"; done <<'END'

644
600 f1
755 old sub
+x old
-w f1 old
u-x f1
go-rwx f1
a=r f1
o+w,g f1
=rw f1
ug+rw f1
x f1
u+z f1
644 nonexistent f1
+t f1
u f1
END
# (date without seconds is the time of the run: not compared)
while read -r args; do eval "same $U/time/mini-date $P/date $args"; done <<'END'
1000000000
-u 1000000000
-n 1000000000
-n 5
0
-u 86399
1790380800
-x
END
while read -r args; do eval "same $U/misc/mini-basename $P/basename $args"; done <<'END'

/a/b/c.ml
/a/b/c.ml .ml
c.ml
-d /a/b/c.ml
-d c.ml
c.ml c.ml
a b c d
/a/b/
END
while read -r args; do eval "same $U/misc/mini-wc $P/wc $args"; done <<'END'
f1
f1 old sub/inner
-l f1
-c f1 old
-wl f1
-r "it's"
-lwrbc f1
nonexistent f1
sub
-x f1
END
while read -r args; do eval "same $U/compare/mini-cmp $P/cmp $args"; done <<'END'
f1 f1
f1 old
-L f1 old
-l f1 old
-Ls f1 old
-Ls f1 f1
f1 "it's"
-l f1 "it's"
f1 nonexistent
nonexistent f1
f1 old 1
f1 old 1 1
f1 f1 0 1
f1 old x
f1
-x f1 old
"sp ace" f1
END
# (-s alone is mini-5i's own: with another letter above; mtime's
# number is the file's, set at the top)
while read -r args; do eval "same $U/files/mini-mtime $P/mtime $args"; done <<'END'
f1
f1 old sub
nonexistent f1
-x
END
# tee: what it writes, its files, with a standard input
teed() { n=$((n + 1)); local a b
  rm -rf $W.a $W.b; cp -a $W $W.a; cp -a $W $W.b
  a=$(cd $W.a && { printf 'one\ntwo\n' | $M $U/pipe/mini-tee "$@" 2>&1 | tr -d '\0'; echo "status ${PIPESTATUS[1]}"; find . -type f | sort | xargs -d '\n' cat; })
  b=$(cd $W.b && { printf 'one\ntwo\n' | $M $P/tee "$@" 2>&1 | tr -d '\0'; echo "status ${PIPESTATUS[1]}"; find . -type f | sort | xargs -d '\n' cat; })
  b=${b//$P\/tee/$U/pipe/mini-tee}
  if [ "$a" != "$b" ]; then failures=$((failures + 1)); echo "FAIL tee $*"; diff <(echo "$a") <(echo "$b") | head -6; fi
}
teed; teed new; teed f1 new; teed -a f1 new; teed nonexistent/x new; teed -x; teed -i new
echo "ok $((n - failures)) of $n cases as principia's"
[ $failures = 0 ]
