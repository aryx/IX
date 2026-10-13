#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-troff -ms on each paper of principia (its .ms files), against
# troff itself: goken's troff as nroff with Plan 9's tmac.s, on one
# page as long as the paper (its footnotes are then at the end, as
# mini-troff's on a terminal). troff's lines are not mini-troff's
# here (its right edge is even, its words hyphenated), so what is
# compared is the words:
#   order  the same characters in the same order, the blanks and the
#          hyphens aside
#   bag    the same characters, in whatever order (when the order
#          differs: nothing is lost or made up, something is elsewhere)
#   said   requests mini-troff says it does not know
# A character that is not ASCII is taken off both (goken's troff
# writes a blank for those a paper names: docs/plans/bugs/goken.md).
# A table goes through goken's tbl first, in the reference. A paper
# with a picture or an equation is said apart: a picture has no
# reference here (goken's pic is not built; mini-troff writes its
# words on a terminal), and equations are not read yet. So are those where troff's output is an accident
# and mini-troff has what the paper says: a double quote in an
# argument of .CW (.CW \&"." , comes out ."", from the macro passing
# its arguments on between quotes: ape, lexnames, utf, 8½, rc), in
# acid.ms one closing parenthesis of a .tl that troff does not write
# (not looked into), in bootpc.ms a letter lost by goken's troff next
# to a line drawn with a character that is not ASCII, in lp.ms \(en
# written "en" (Plan 9's table for a terminal has no dash of that name).
# (docs/plans/plan_typesetting.md, stage 3)
#
# usage: ms.sh [-k dir] [file.ms ...]
#   -k dir  what each made is kept there (dir/ref, dir/out)
# PRINCIPIA and GOKEN say where the two are

HERE=$(cd "$(dirname "$0")" && pwd); ROOT=$(cd $HERE/../.. && pwd)
S=$(readlink -f ${PRINCIPIA:-$HOME/github/principia-softwarica}); G=$(readlink -f ${GOKEN:-$HOME/goken})
TROFF=$G/ROOT/arch/boot-gcc/bin/troff; TBL=$G/ROOT/arch/boot-gcc/bin/tbl; MINI=$ROOT/_build/default/typesetting/troff/Main.exe
[ -x $TROFF ] || { echo "skipped: no $TROFF"; exit 0; }
[ -f $S/typesetting/troff/tmac.s ] || { echo "skipped: no $S/typesetting/troff/tmac.s"; exit 0; }
keep=; [ "${1:-}" = -k ] && { keep=$2; shift 2; }
W=${keep:-$(mktemp -d)}; [ -n "$keep" ] || trap 'rm -rf $W' EXIT
mkdir -p $W/ref $W/out $W/root/tmac
# troff's files where it looks for them: the terminal's table, and
# tmac.s with the files it reads (it names them by /sys/lib/tmac)
ln -sfn $S/ROOT/lib/troff $W/root/troff
cp $S/ROOT/lib/tmac/tmac.s* $W/root/tmac/; sed "s|^\.ds sd /sys/lib/tmac|.ds sd $W/root/tmac|" $S/typesetting/troff/tmac.s > $W/root/tmac/tmac.s
printf '.pl 30000v\n' > $W/long
today=$(date '+%B %-d, %Y')
cd $S
files=${*:-$(git -c core.quotepath=off ls-files '*.ms')}
# a text's letters: no blank, no hyphen, nothing that is not ASCII; and
# its words, sorted
# (nor a run of underscores: what goken's troff makes of a character
# that is not ASCII in a heading, which a terminal underlines)
# (nor what a table's lines are drawn with on a terminal)
letters() { perl -CSD -pe 's/[^\x00-\x7f]//g; s/_{5,}//g' "$1" | tr -d ' \t\n|_=-'; }
bag() { letters "$1" | fold -w 1 | sort | uniq -c; }
accidents=" APE/docs/ape.ms docs/articles/lexnames.ms docs/articles/utf.ms windows/docs/8½.ms debuggers/docs/acid.ms shells/docs/rc.ms MISC/BIG/boot-pc-kernel/bootpc.ms MISC/BIG/doc/lp.ms "
n=0; order=0; bags=0; : > $W/said; : > $W/differ; : > $W/moved; : > $W/later; : > $W/known
for f in $files; do
  b=$(echo $f | tr / _); n=$((n + 1))
  # (the date troff puts at the first sheet's foot is taken off, and
  # the rule over the footnotes; a letter, a backspace and another are
  # a terminal's bold, an underscore and a backspace its italic)
  (cd $(dirname $f) && cat $W/long $(basename $f) | $TBL 2> /dev/null | GOROOT=$W/root $TROFF -N -Tutf -ms 2> /dev/null) | perl -pe 's/_\x08//g; s/\x08_//g; s/.\x08//g; s/\x1b[0-9]//g' | grep -v "^[ \t]*$today *\$" | grep -v '^[ \t]*__*[ \t]*$' > $W/ref/$b
  (cd $(dirname $f) && $MINI -ms $(basename $f) 2> $W/out/$b.err) | grep -v '^[ \t]*__*[ \t]*$' > $W/out/$b
  sed 's/.*: \(.*\): not known/\1/' $W/out/$b.err >> $W/said
  # (.so: net.ms's picture, made by pic into another file)
  if grep -q '^\.\(EQ\|PS\|BP\|so\)' $f; then echo $f >> $W/later
  elif cmp -s <(letters $W/ref/$b) <(letters $W/out/$b); then order=$((order + 1)); bags=$((bags + 1))
  elif cmp -s <(bag $W/ref/$b) <(bag $W/out/$b); then bags=$((bags + 1)); echo $f >> $W/moved
  else case "$accidents" in *" $f "*) echo $f >> $W/known;; *) echo $f >> $W/differ;; esac; fi
done
echo "papers: $n; with a picture or an equation (not compared): $(wc -l < $W/later); of the others, the same words in order: $order; the same words: $bags"
echo "not known: $(wc -l < $W/said): $(sort $W/said | uniq -c | sort -rn | awk '{printf "%s %s  ", $1, $2}')" | fold -s -w 110
[ -s $W/known ] && echo "troff's accidents: $(tr '\n' ' ' < $W/known)" | fold -s -w 110
[ -s $W/moved ] && echo "the same words, elsewhere: $(tr '\n' ' ' < $W/moved)" | fold -s -w 110
[ -s $W/differ ] && echo "words differ: $(tr '\n' ' ' < $W/differ)" | fold -s -w 110
[ ! -s $W/differ ]
