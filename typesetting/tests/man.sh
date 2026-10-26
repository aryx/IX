#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-troff on every page of principia's manual, against troff itself:
# goken's troff (principia's, built for Linux) as nroff, with Plan 9's
# tmac.an, made not to hyphenate and to have one page as long as the
# document, which is how mini-troff writes a page. For each page:
#   words   the same characters in the same order, the blanks aside
#           (nothing lost, doubled or moved; where the lines break is
#           not looked at)
#   lines   the same lines, the runs of blank lines taken as one
#   said    requests mini-troff says it does not know
# and at the end how many pages are the same by each, the requests not
# known by how often, and the pages whose words differ.
#
# A character that is not ASCII is taken as a blank on both sides:
# goken's troff writes a blank for each one a page names (\(bu, \(mu,
# \(*a: docs/plans/bugs/goken.md), mini-troff the character.
#
# Pages not expected to be the same, said apart ("known"):
#   a table, a picture, an equation (through goken's tbl and eqn in the
#     reference; not read yet by mini-troff): 1/eqn 1/tbl 1/pic ...
#   two columns (.2C: troff makes them of a terminal's reverse line
#     feeds, mini-troff leaves the list in one)
#   the lines' right edge made even (.ad; a page's own doing, the
#     manual's being ragged on a terminal): 8/lp
#   a text set aside to measure it (.di, with \k: a table's columns
#     taken from where three tabs end): 6/man 6/ms
#   troff's own accidents, where mini-troff has what the page's author
#     wrote: 2/pushtls (a line that starts with a font and then a dot
#     is taken for a request, and lost), 6/authsrv (.IR K { m }: the
#     brace is a conditional's, in tmac.an's macro), 1/spin (the same
#     macro's own request printed as text after an argument with spaces), 8/scuzz and 6/ms (the same), 6/namespace (a double quote inside
#     an argument, lost when that macro passes it on)
#     8/mouse (.SH alone, its words on the next line: tmac.an's own
#     line for the HTML manual is taken for them, and the heading is in
#     the paragraph)
# (docs/plans/done/plan_typesetting.md, stage 1)
#
# usage: man.sh [-k dir] [page ...]
#   -k dir  what each made is kept there (dir/ref, dir/out) to be looked at
#   page    1/tr ...; default: all of sections 1 to 8
# PRINCIPIA and GOKEN say where the two are (~/github/principia-softwarica, ~/goken)

HERE=$(cd "$(dirname "$0")" && pwd); ROOT=$(cd $HERE/../.. && pwd)
S=$(readlink -f ${PRINCIPIA:-$HOME/github/principia-softwarica}); G=$(readlink -f ${GOKEN:-$HOME/goken})
TROFF=$G/ROOT/arch/boot-gcc/bin/troff; TBL=$G/ROOT/arch/boot-gcc/bin/tbl; EQN=$G/ROOT/arch/boot-gcc/bin/eqn; MINI=$ROOT/_build/default/typesetting/troff/Main.exe
[ -x $TROFF ] || { echo "skipped: no $TROFF"; exit 0; }
[ -d $S/ROOT/docs/man ] || { echo "skipped: no $S/ROOT/docs/man"; exit 0; }
keep=; [ "${1:-}" = -k ] && { keep=$2; shift 2; }
W=${keep:-$(mktemp -d)}; [ -n "$keep" ] || trap 'rm -rf $W' EXIT
mkdir -p $W/ref $W/out
printf '.de HY\n..\n.nh\n' > $W/nohy
cd $S/ROOT/docs/man
pages=${*:-$(ls -d [1-8]/* | grep -v INDEX)}
# the lines of a page, without the blank ones at its two ends and with one for several
squeeze() { perl -CSD -pe 's/[^\x00-\x7f]/ /g' "$1" | sed -e 's/[ \t]*$//' | cat -s | sed -e '/./,$!d' | sed -e '${/^$/d}'; }
# its characters, the blanks aside (a word cut after its hyphen at a line's end is the same word)
letters() { perl -CSD -pe 's/[^\x00-\x7f]//g' "$1" | tr -d ' \t\n'; }
accidents=" 2/pushtls 6/authsrv 1/spin 8/scuzz 6/namespace 6/ms 8/mouse "
n=0; words=0; lines=0; : > $W/said; : > $W/differ; : > $W/lines_differ; : > $W/known
for p in $pages; do
  mkdir -p $W/ref/$(dirname $p) $W/out/$(dirname $p)
  known=
  if grep -q '^\.\(TS\|EQ\|PS\)' $p; then known="a table, a picture or an equation"
    cat $W/nohy $p | $TBL 2> /dev/null | $EQN 2> /dev/null | GOROOT=$S/ROOT/lib $TROFF -N -Tutf -rL4000000 -man > $W/ref/$p 2> /dev/null
  else GOROOT=$S/ROOT/lib $TROFF -N -Tutf -rL4000000 -man $W/nohy $p > $W/ref/$p 2> /dev/null; fi
  grep -q '^\.2C' $p && known="two columns"
  [ $p = 8/lp ] && known="an even right edge"
  grep -q '^\.di' $p && known="a text set aside"
  case "$accidents" in *" $p "*) known="troff's accident";; esac
  $MINI $p > $W/out/$p 2> $W/out/$p.err
  n=$((n + 1))
  sed 's/.*: \(.*\): not known/\1/' $W/out/$p.err >> $W/said
  if cmp -s <(letters $W/ref/$p) <(letters $W/out/$p); then words=$((words + 1)); elif [ -z "$known" ]; then echo $p >> $W/differ; fi
  [ -n "$known" ] && echo "$p ($known)" >> $W/known
  if cmp -s <(squeeze $W/ref/$p) <(squeeze $W/out/$p); then lines=$((lines + 1)); elif [ -z "$known" ]; then echo $p >> $W/lines_differ; fi
done
echo "pages: $n; the same words: $words; the same lines: $lines"
echo "not known: $(wc -l < $W/said) in $(grep -l . $(find $W/out -name '*.err') /dev/null | wc -l) pages: $(sort $W/said | uniq -c | sort -rn | awk '{printf "%s %s  ", $1, $2}')"
[ -s $W/known ] && echo "not expected to be the same ($(wc -l < $W/known)): $(tr '\n' ' ' < $W/known)" | fold -s -w 110
[ -s $W/differ ] && echo "words differ: $(tr '\n' ' ' < $W/differ)" | fold -s -w 110
[ -s $W/lines_differ ] && echo "lines differ: $(tr '\n' ' ' < $W/lines_differ)" | fold -s -w 110
[ ! -s $W/differ ]
