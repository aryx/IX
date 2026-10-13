#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The new format (Ixdoc: Markdown's lines and \name[options]{text}),
# checked three ways.
#
# 1. Written and read again. Each page of principia's manual and each
#    of its papers is read by mini-troff and written in the new format
#    (-T md), and that is read again: its words must be those of the
#    page read directly (-T words: both as a typesetter reads them,
#    a page saying one thing to it and another to a terminal). Also
#    counted, though not asked: how many come out with the same lines
#    (runs of blank lines as one).
# 2. ix's own Markdown, the files of the repository: what the reader
#    says it does not know, by kind, and that each is made a PDF file.
# 3. Nothing lost: a document written in the new format and read
#    again is written the same (the writer's output is a fixed point).
#
# usage: md.sh [-k dir]     (-k: the files made are kept there)
# Needs principia for 1 (PRINCIPIA, default ~/github/principia-softwarica).

HERE=$(cd "$(dirname "$0")" && pwd); ROOT=$(cd $HERE/../.. && pwd)
S=$(readlink -f ${PRINCIPIA:-$HOME/github/principia-softwarica})
MINI=$ROOT/_build/default/typesetting/troff/Main.exe
keep=; [ "${1:-}" = -k ] && { keep=$2; shift 2; }
W=${keep:-$(mktemp -d)}; [ -n "$keep" ] || trap 'rm -rf $W' EXIT
mkdir -p $W/md $W/a $W/b
# two papers have a table wider than the line, whose columns tbl was
# told the widths of: the new format has no way to say them, the long
# cells are filled in what room there is, and a row's words are then
# read in another order (and a word with a hyphen cut at it)
tables=" MISC/BIG/doc/spin.ms typesetting/docs/troff.ms "
letters() { perl -CSD -pe 's/[^\x00-\x7f]//g' "$1" | tr -d ' \t\n|_=-'; }
status=0

if [ -d $S/ROOT/docs/man ]; then
  for kind in man ms; do
    if [ $kind = man ]; then cd $S/ROOT/docs/man; files=$(ls -d [1-8]/* | grep -v INDEX); else cd $S; files=$(git -c core.quotepath=off ls-files '*.ms'); fi
    n=0; same=0; lines=0; fixed=0; : > $W/differ.$kind; : > $W/known.$kind
    for f in $files; do
      b=$(echo $f | tr / _); n=$((n + 1)); d=$(dirname $f); p=$(basename $f)
      (cd $d && $MINI -$kind -T words $p 2> /dev/null > $W/a/$b; $MINI -$kind -T md $p 2> /dev/null > $W/md/$b.md
       $MINI -md -T words $W/md/$b.md > $W/b/$b 2> /dev/null; $MINI -md -T md $W/md/$b.md > $W/b/$b.md 2> /dev/null)
      if cmp -s <(letters $W/a/$b) <(letters $W/b/$b); then same=$((same + 1))
      else case "$tables" in *" $f "*) echo $f >> $W/known.$kind;; *) echo $f >> $W/differ.$kind;; esac; fi
      cmp -s <(cat -s $W/a/$b) <(cat -s $W/b/$b) && lines=$((lines + 1))
      cmp -s $W/md/$b.md $W/b/$b.md && fixed=$((fixed + 1))
    done
    echo "$kind: $n; written in the new format and read again: the same words: $same; the same lines: $lines; written again the same: $fixed"
    [ -s $W/known.$kind ] && echo "the same words in another order, a wide table's: $(tr '\n' ' ' < $W/known.$kind)" | fold -s -w 110
    [ -s $W/differ.$kind ] && { echo "words differ: $(head -40 $W/differ.$kind | tr '\n' ' ')" | fold -s -w 110; status=1; }
  done
else echo "skipped: no $S/ROOT/docs/man"; fi

cd $ROOT
n=0; quiet=0; pdf=0; : > $W/said
for f in $(git ls-files '*.md' | grep -v prompt-history); do
  n=$((n + 1))
  $MINI $f > /dev/null 2> $W/err || status=1
  [ -s $W/err ] || quiet=$((quiet + 1))
  sed 's/^[^:]*:[0-9]*: //; s/: not known$//; s/^!\[.*(a picture in a file)/a picture in a file/; s/^<.*(HTML)/HTML/' $W/err >> $W/said
  $MINI -T pdf $f > $W/x.pdf 2> /dev/null && pdf=$((pdf + 1))
done
echo "ix's Markdown: $n files; with nothing not known: $quiet; made a PDF file: $pdf"
echo "not known: $(wc -l < $W/said): $(sort $W/said | uniq -c | sort -rn | head -30 | awk '{c=$1; $1=""; printf "%s%s;  ", c, $0}')" | fold -s -w 110
exit $status
