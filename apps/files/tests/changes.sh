#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-files changing files: a session of keys on a scratch tree made new
# for it, then what the tree holds compared with what it should. What must
# not happen is checked as much as what must: an answer of n, a name taken,
# a folder into itself, a link's target.
# usage: apps/files/tests/changes.sh [dir]
#   dir: where the program is (default: dune's, _build/default/apps)
cd "$(dirname "$0")/../../.."
D=${1:-_build/default/apps}/files
F=$D/Files.exe; [ -x $F ] || F=$D/files
F=$(realpath $F)
T=$(mktemp -d); trap 'rm -rf $T' EXIT
r=0

# docs/ music/ a.txt b.txt, the rows in that order
fresh() {
  rm -rf $T/tree
  mkdir -p $T/tree/docs/deep $T/tree/music
  echo inner > $T/tree/docs/deep/inner.txt
  echo a > $T/tree/a.txt
  echo b > $T/tree/b.txt
  chmod 755 $T/tree/b.txt
}
run() { # script
  HOME=$T timeout 20 $F -dump-frame 40 $T/f.ppm -script "$1" root=$T/tree $T/tree > /dev/null 2>&1
}
held() { (cd $T/tree && find . -mindepth 1 | sort | sed 's#^\./##' | tr '\n' ' '); }
same() { # what got wanted
  if [ "$2" = "$3" ]; then echo "ok $1"; else echo "FAIL $1: [$2], not [$3]"; r=1; fi
}
session() { # what script wanted
  fresh; run "$2"; same "$1" "$(held)" "$3"
}
ALL='a.txt b.txt docs docs/deep docs/deep/inner.txt music '
A=down:2,down:4
B=down:2,down:4,down:6

session "d then y: a file deleted" "$A,type(d):8,type(y):10" \
  'b.txt docs docs/deep docs/deep/inner.txt music '
session "d then y: a folder with all it holds" "type(d):2,type(y):4" \
  'a.txt b.txt music '
session "d then n: nothing deleted" "type(d):2,type(n):4" "$ALL"
session "d then Escape: nothing deleted" "type(d):2,escape:4" "$ALL"
session "d then Enter: nothing deleted, only y deletes" "type(d):2,return:4" "$ALL"

session "r: renamed, the field holding the old name" \
  "$A,type(r):8,backspace:10,backspace:12,backspace:14,backspace:16,type(old):18,return:20" \
  'aold b.txt docs docs/deep docs/deep/inner.txt music '
session "r onto a taken name: refused, neither file lost" \
  "$A,type(r):8,backspace:10,backspace:12,backspace:14,backspace:16,backspace:18,type(b.txt):20,return:22" "$ALL"
session "r then Escape: nothing renamed" "$A,type(r):8,type(z):10,escape:12" "$ALL"
session "r to a name with a slash: refused" "$A,type(r):8,type(/z):10,return:12" "$ALL"

session "n: a new folder" "type(n):2,type(new):4,return:6" \
  'a.txt b.txt docs docs/deep docs/deep/inner.txt music new '
session "n with a taken name: refused" "type(n):2,type(docs):4,return:6" "$ALL"
session "n with nothing typed: refused" "type(n):2,return:4" "$ALL"

session "c, v in another folder: copied, the first still there" \
  "$A,type(c):8,up:10,return:12,type(v):14" \
  'a.txt b.txt docs docs/deep docs/deep/inner.txt music music/a.txt '
session "c, v in its own folder: a copy of it" "$A,type(c):8,type(v):10" \
  'a.txt b.txt copy of a.txt docs docs/deep docs/deep/inner.txt music '
session "c, v twice in its own folder: the second another name" "$A,type(c):8,type(v):10,type(v):12" \
  'a.txt b.txt copy 2 of a.txt copy of a.txt docs docs/deep docs/deep/inner.txt music '
session "c of a folder, v elsewhere: the tree copied" \
  "type(c):2,down:4,return:6,type(v):8" \
  'a.txt b.txt docs docs/deep docs/deep/inner.txt music music/docs music/docs/deep music/docs/deep/inner.txt '
session "x, v in another folder: moved" "$A,type(x):8,up:10,return:12,type(v):14" \
  'b.txt docs docs/deep docs/deep/inner.txt music music/a.txt '
session "x of a folder, v elsewhere: the tree moved" "type(x):2,down:4,return:6,type(v):8" \
  'a.txt b.txt music music/docs music/docs/deep music/docs/deep/inner.txt '
session "x, v in its own folder: nothing" "$A,type(x):8,type(v):10" "$ALL"
session "x of a folder, v inside itself: refused, nothing lost" "type(x):2,return:4,type(v):6" "$ALL"
session "c of a folder, v inside itself: refused" "type(c):2,return:4,type(v):6" "$ALL"
session "v with nothing cut or copied: nothing" "type(v):2" "$ALL"

fresh; echo other > $T/tree/music/a.txt
run "$A,type(x):8,up:10,return:12,type(v):14"
same "x, v where the name is taken: refused, the source still there" \
  "$(cat $T/tree/a.txt $T/tree/music/a.txt | tr '\n' ' ')" 'a other '

fresh; run "$B,type(c):10,up:12,up:14,return:16,type(v):18"
same "a copy keeps the bytes" "$(cat $T/tree/music/b.txt)" b
[ -x $T/tree/music/b.txt ] && echo "ok a copy keeps the execute bit" || { echo "FAIL a copy loses the execute bit"; r=1; }
fresh; touch -d "2020-02-02 12:00:00 UTC" $T/tree/b.txt
run "$B,type(x):10,up:12,up:14,return:16,type(v):18"
same "a move keeps the day" "$(date -u -r $T/tree/music/b.txt +%F)" 2020-02-02

# a link is what it is: its target is outside the tree, and must survive
fresh; mkdir -p $T/out/kept; echo safe > $T/out/kept/safe.txt
ln -s $T/out $T/tree/docs/deep/link
run "type(d):2,type(y):4"
same "a folder deleted, a link in it to a folder: the target's files stay" \
  "$(cat $T/out/kept/safe.txt 2>&1)" safe
same "... and the folder is gone" "$(held)" 'a.txt b.txt music '

fresh; ln -s $T/out $T/tree/alink
run "type(d):2,type(y):4"
same "a link to a folder selected and deleted: the link goes, not the target" \
  "$([ -L $T/tree/alink ] && echo there || echo gone) $(cat $T/out/kept/safe.txt 2>&1)" 'gone safe'

fresh; ln -s $T/out $T/tree/docs/deep/link
run "type(c):2,down:4,return:6,type(v):8"
same "a tree with a link copied: refused, nothing left of the copy" \
  "$([ -e $T/tree/music/docs ] && echo left || echo clean)" clean
same "... the target as it was" "$(cat $T/out/kept/safe.txt 2>&1)" safe

fresh; ln -s $T/out $T/tree/docs/deep/link
run "type(x):2,down:4,return:6,type(v):8"
same "a tree with a link moved: refused, the source still whole" \
  "$([ -f $T/tree/docs/deep/inner.txt ] && echo whole || echo lost) $([ -e $T/tree/music/docs ] && echo left || echo clean)" 'whole clean'

# entries that a careless listing hides or waits on
fresh; ln -s /nothing/there $T/tree/docs/deep/dangling; mkfifo $T/tree/docs/deep/pipe
run "type(d):2,type(y):4"
same "a folder holding a link to nothing and a pipe: deleted" "$(held)" 'a.txt b.txt music '
fresh; mkfifo $T/tree/docs/deep/pipe
run "type(c):2,down:4,return:6,type(v):8"
same "a tree holding a pipe copied: refused, and no waiting for ever" \
  "$([ -e $T/tree/music/docs ] && echo left || echo clean)" clean
fresh; mkfifo $T/tree/apipe
run "down:2,return:4"
same "a pipe selected and Enter: the window goes on" "$?" 0
fresh; chmod 000 $T/tree/docs/deep/inner.txt
run "type(d):2,type(y):4"
same "a folder holding a file one may not read: deleted" "$(held)" 'a.txt b.txt music '

# a file that cannot be read stops a copy, and a move then keeps its source
if [ "$(id -u)" != 0 ]; then
  fresh; chmod 000 $T/tree/docs/deep/inner.txt
  run "type(x):2,down:4,return:6,type(v):8"
  same "a move failing halfway: the source whole, no half copy" \
    "$([ -e $T/tree/docs/deep/inner.txt ] && echo whole || echo lost) $([ -e $T/tree/music/docs ] && echo left || echo clean)" 'whole clean'
  chmod 644 $T/tree/docs/deep/inner.txt
fi
exit $r
