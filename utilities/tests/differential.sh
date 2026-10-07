#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The utilities against principia's (plan_rio.md): each of ix's, built
# for Plan 9 (mini-mk O=5 OS=plan9 in utilities/*), and principia's own
# arm binary of the same name, both run by mini-5i on the same
# arguments in a directory made here: the same output, errors and exit
# status.
# usage: utilities/tests/differential.sh     (PRINCIPIA: default ~/principia)

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
U=$ROOT/_mk/5-plan9/utilities
P=${PRINCIPIA:-$HOME/principia}/ROOT/arch/arm/bin
M=$ROOT/bin/mini-5i
[ -x $P/ls ] || { echo "skipped: no principia binaries in $P"; exit 0; }
[ -x $U/process/mini-sleep ] || { echo "FAIL: not built (mini-mk O=5 OS=plan9 in utilities/files, misc, namespace, time, pipe, compare, process, text, byte)"; exit 1; }
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
-t
-s
-ls sub f1
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
  after() { find . -printf '%p %m %y\n' | sort; find . -type f | sort | xargs -d '\n' cat | tr -d '\0'; }
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
# time)
while read -r args; do eval "changed $U/files/mini-touch $P/touch $args"; done <<'END'

new
f1 new other
-c new
-c f1
-t1000000000 f1
-t 1000000000 new
-t
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
-s f1 old
-s f1 f1
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
# (mtime's number is the file's, set at the top)
while read -r args; do eval "same $U/files/mini-mtime $P/mtime $args"; done <<'END'
f1
f1 old sub
nonexistent f1
-x
END
while read -r args; do eval "same $U/misc/mini-cleanname $P/cleanname $args"; done <<'END'

a/b/../c
/a//b/./c/
../a/../../b
/../a
.
""
a/..
-d /usr/pad a ../b /c
-d/usr a
-d
-x a
a b/. c//d
END
# seq: principia's arm binary computes with the FPA's instructions,
# which mini-5i does not have; against plan9port's, the same seq.c, when
# it is there (its floats are the host's). Not a last number an
# increment falls just short of (1 100000 1000000): plan9port's counts
# the steps and rounds, principia's seq.c and mini-seq stop before it
P9SEQ=${PLAN9:-/usr/lib/plan9}/bin/seq
seq9() { n=$((n + 1)); local a b
  a=$($M $U/misc/mini-seq "$@" 2>&1 < /dev/null | tr -d '\0'; echo "status ${PIPESTATUS[0]}")
  b=$($P9SEQ "$@" 2>&1 < /dev/null; echo "status $?")
  if [ "$a" != "$b" ]; then failures=$((failures + 1)); echo "FAIL seq $*"; diff <(echo "$a") <(echo "$b") | head -6; fi
}
[ -x $P9SEQ ] || echo "skipped: seq (no plan9port: $P9SEQ)"
[ -x $P9SEQ ] && while read -r args; do eval "seq9 $args"; done <<'END'

5
3 6
1 2 9
10 -3 1
1 0.5 3
-w 8 11
-w 1 0.5 3
-w 98 102
0 0 5
1 2 3 4
5 1
-w 1 100000 900001
0.1 0.1 0.5
-2 2
END
while read -r args; do eval "same $U/misc/mini-du $P/du $args"; done <<'END'

-a
-as
-s
-n
-a sub f1
-as sub "a dir" nonexistent
-s sub "a dir"
-b 4k
-b1 -a sub
f1
-f nonexistent
-x
"it's"
END
while read -r args; do eval "same $U/process/mini-sleep $P/sleep $args"; done <<'END'

0
0.01
.05
x
0.
END
while read -r args; do eval "same $U/namespace/mini-unmount $P/unmount $args"; done <<'END'

a b c
/nonexistent
f1 sub
sub
END
# (the text of the directory's files: f1 "hi", old empty, it's "there",
# sub/inner "x"; more of it made here)
printf 'one two\nthree\nFour five\n\nsix\nseven 7\neight\nnine\nten\neleven\ntwelve' > text
head -c 70 /dev/urandom > bytes; printf 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaab\tc\n' > same
touch -d "2020-01-08 03:04" text bytes same
while read -r args; do eval "same $U/text/mini-grep $P/grep $args"; done <<'END'

e text
-n e text
-v e text
-c e text f1
-i four text
-l e text f1 old
-L e text f1 old
-h e text f1
e text f1 nonexistent
'^t' text
'e$' text
'o|x' text f1
-e one -e six text
-n '^$' text
'[0-9]' text
-ci 'T' text
-vn 'e' text
zzz text
e nonexistent
-x e text
-e
'se+v' text
-nv . text
't.*e' text f1 sub/inner
END
while read -r args; do eval "same $U/pipe/mini-tail $P/tail $args"; done <<'END'
text
-3 text
+3 text
-n 2 text
-n2 text
-c 9 text
-c9 text
+10c text
-1c text
-r text
-2r text
+0 text
-100 text
+100 text
-0 text
f1
old
nonexistent
-3 -4 text
-r -c 3 text
text f1
-n text
-5l text
END
# (not xd -r on lines that are the same: principia's loses the file's
# end after them, docs/plans/bugs/goken.md)
while read -r args; do eval "same $U/byte/mini-xd $P/xd $args"; done <<'END'
text
-c text
-bx text
-b text
-c -bx text
-ao -wd text
-vx bytes
-lo bytes
-ad -1d bytes
-r text
-x same
old
f1 text
nonexistent
text nonexistent f1
-q text
-rr text
-ax -c -ao -bo text
-2x -4x -8x bytes
-wo -vd bytes
END
# a program given a standard input (a file of the directory): fed FILE ours theirs args
fed() { local input=$1 ours=$2 theirs=$3; shift 3; n=$((n + 1)); local a b
  a=$($M $ours "$@" 2>&1 < $input | tr -d '\0'; echo "status ${PIPESTATUS[0]}")
  b=$($M $theirs "$@" 2>&1 < $input | tr -d '\0'; echo "status ${PIPESTATUS[0]}")
  b=${b//$theirs/$ours}
  if [ "$a" != "$b" ]; then failures=$((failures + 1)); echo "FAIL $(basename $theirs) $* < $input"; diff <(echo "$a") <(echo "$b") | head -6; fi
}
printf 'a 1\na 1\nb 1\nb 2\nb 2\nb 2\n\n\nc 3\nd 3\nlast' > dups
printf 'Hello, World\nfoo  bar\tbaz\naaabbbccc\n\303\251t\303\251 12345\n' > mixed
touch -d "2020-01-08 03:04" dups mixed
while read -r args; do eval "same $U/text/mini-uniq $P/uniq $args"; done <<'END'
dups
-c dups
-u dups
-d dups
-1 dups
-1 -c dups
+2 dups
-1 +1 -c dups
old
f1
nonexistent
dups text
-9 dups
END
fed dups $U/text/mini-uniq $P/uniq
fed dups $U/text/mini-uniq $P/uniq -c
while read -r args; do eval "fed mixed $U/text/mini-tr $P/tr $args"; done <<'END'
a-z A-Z
A-Z a-z
abc x
-d a-c
-d 'lo '
-cd a-z
-s ab AB
-s ' ' ' '
-ds b c
-c a-z _
-cs a-zA-Z '\012'
'\011' ' '
'\x65' E
é e
0-9 '#'
a-c
-d
-d a b
a b c
-x a b
ab x
aa xy
z-a x
'\400' x
'' ''
END
# sed: its scripts have spaces, quotes and newlines: each case a line of
# script, then the files (a script of several lines by $'...')
sedcase() { changed $U/text/mini-sed $P/sed "$@"; }
sedcase -n 2,3p text
sedcase 's/e/E/g' text
sedcase 's/e/E/' text f1
sedcase -g 's/e/E/' text
sedcase 3q text
sedcase -n '/six/,$p' text
sedcase '$!d' text
sedcase -n '$=' text
sedcase -n '/t/{=;p;}' text
sedcase 'N;s/\n/+/' text
sedcase -n l mixed
sedcase $'2c\\\nchanged' text
sedcase $'c\\\nall' text
sedcase $'2,4c\\\nrange' text
sedcase $'/six/a\\\nafter six\\\nand more' text
sedcase $'1i\\\nbefore' text
sedcase 'y/abc/xyz/' mixed
sedcase 's/(o)n(e)/\2\1/' text
sedcase 's/t/[&]/g' text
sedcase 's/$/!/;s/^/> /' text
sedcase 's/x*/-/g' f1
sedcase -n 's/e/E/p' text
sedcase -n 's/e/E/gw out' text
sedcase 'w copy' text
sedcase -e 's/one/1/' -e 's/two/2/' text
sedcase -n '2{p;p;}' text
sedcase '/^$/d' text
sedcase '1!G;h;$!d' text
sedcase -n 'h;n;G;p' text
sedcase 'x;G' f1
sedcase -n '/three/,/six/{/Four/!p;}' text
sedcase $':a\ns/e/E/\nta' text
sedcase $'s/one/ONE/\nt done\ns/$/ ./\n:done' text
sedcase '2,3!d' text
sedcase 'P;D' text
sedcase '$!N;P;D' text
sedcase 'r f1' text
sedcase '2r nonexistent' text
sedcase '=' f1
sedcase 's/a/b' text
sedcase 'k' text
sedcase '0p' text
sedcase 'b nowhere' text
sedcase '{p' text
sedcase 'p}' text
sedcase 2p nonexistent text
sedcase -n p text nonexistent
sedcase
sedcase -x p f1
sedcase 's/ *$//' mixed
sedcase 's/[0-9]+/<&>/g' mixed text
sedcase 's,/,|,g' mixed
sedcase -n '$p' text f1
sedcase 'n;d' text
sedcase '5,2p' text
sedcase 's/\(.*\)/x/' mixed
fed text $U/text/mini-sed $P/sed -n '$p'
fed text $U/text/mini-sed $P/sed 's/e/E/;2q'
printf 'pear 10 x\napple 9 y\nBanana 100 z\napple 9 y\n  cherry -3 w\nfig 2.5 v\nDate 010 u\nelder 1e2 t\n_under 0 s\n\ngrape .5 r\n' > fruit
printf 'c:3:x\na:10:y\nb:2:z\na:1:w\n' > colon
touch -d "2020-01-08 03:04" fruit colon
while read -r args; do eval "changed $U/text/mini-sort $P/sort $args"; done <<'END'
fruit
-r fruit
-u fruit
-f fruit
-d fruit
-b fruit
-n fruit
-nr fruit
+1n fruit
+1nr fruit
+1 fruit
+1 -2 fruit
+2 fruit
+0f +1n fruit
-fu fruit
+1n -u fruit
-t: +1n colon
-t: +0 -1 +1nr colon
-t : +2 colon
-k 2n fruit
-k 2,2n -k 1 fruit
+0.1 fruit
+0.1 -0.3 fruit
-g +1 fruit
+1g fruit
-c fruit
-c f1
-c colon
-u -c fruit
-o sorted fruit
-o fruit fruit
fruit colon
text
mixed
old
nonexistent
fruit nonexistent
-x fruit
+x fruit
-i mixed
-w fruit
-df fruit
-bf +0 fruit
-rn +1 fruit
+1 -2 +0r fruit
-c fruit colon
-T /tmp fruit
-m fruit
-nf fruit
END
fed fruit $U/text/mini-sort $P/sort
fed fruit $U/text/mini-sort $P/sort -n +1
fed text $U/text/mini-sort $P/sort
# (ps reads /proc, which under mini-5i is the host's, and time says
# times: not compared here but time's usage; the two are run on
# mini-9pi, kernel/9pi's card-proc)
same $U/process/mini-time $P/time
# tee: what it writes, its files, with a standard input
teed() { n=$((n + 1)); local a b
  rm -rf $W.a $W.b; cp -a $W $W.a; cp -a $W $W.b
  a=$(cd $W.a && { printf 'one\ntwo\n' | $M $U/pipe/mini-tee "$@" 2>&1 | tr -d '\0'; echo "status ${PIPESTATUS[1]}"; find . -type f | sort | xargs -d '\n' cat | tr -d '\0'; })
  b=$(cd $W.b && { printf 'one\ntwo\n' | $M $P/tee "$@" 2>&1 | tr -d '\0'; echo "status ${PIPESTATUS[1]}"; find . -type f | sort | xargs -d '\n' cat | tr -d '\0'; })
  b=${b//$P\/tee/$U/pipe/mini-tee}
  if [ "$a" != "$b" ]; then failures=$((failures + 1)); echo "FAIL tee $*"; diff <(echo "$a") <(echo "$b") | head -6; fi
}
teed; teed new; teed f1 new; teed -a f1 new; teed nonexistent/x new; teed -x; teed -i new
echo "ok $((n - failures)) of $n cases as principia's"
[ $failures = 0 ]
