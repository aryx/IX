#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-troff -T pdf on every page of principia's manual, the file read
# back by a program that is not ix's: poppler's pdftotext. For each
# page: the file is read without a complaint, and its words are those
# mini-troff says it wrote (-T words: the page as a typesetter is given
# it, as text), in the same order. The blanks, the hyphens and the
# quotes are not compared (a line's end is not the same place in the
# two; a minus is a dash on paper, a quote a quotation mark), nor a
# character that is not ASCII; the header and the number that each
# sheet has are taken off. A page with a line that goes past the
# paper's right edge (mini-troff says so) is counted apart: pdftotext
# does not give what is off the sheet.
# At the end: the pages, the sheets, the characters that the fonts
# have not and how often, and the pages whose words differ.
# (docs/plans/done/plan_typesetting.md, stage 2)
#
# usage: pdf.sh [-k dir] [page ...]
#   -k dir  the files are kept there
#   page    1/tr ...; default: all of sections 1 to 8
# PRINCIPIA says where principia is (~/github/principia-softwarica)

HERE=$(cd "$(dirname "$0")" && pwd); ROOT=$(cd $HERE/../.. && pwd)
S=$(readlink -f ${PRINCIPIA:-$HOME/github/principia-softwarica}); MINI=$ROOT/_build/default/typesetting/troff/Main.exe
command -v pdftotext > /dev/null || { echo "skipped: no pdftotext (poppler)"; exit 0; }
[ -d $S/ROOT/docs/man ] || { echo "skipped: no $S/ROOT/docs/man"; exit 0; }
keep=; [ "${1:-}" = -k ] && { keep=$2; shift 2; }
W=${keep:-$(mktemp -d)}; [ -n "$keep" ] || trap 'rm -rf $W' EXIT
mkdir -p $W
cd $S/ROOT/docs/man
pages=${*:-$(ls -d [1-8]/* | grep -v INDEX)}
# are a file's words, as pdftotext gives them, those of mini-troff's
# text? The header (the words of the text's first line) and the number
# are what each sheet's content ends with: taken off there.
same_words() { python3 - "$1" "$2" <<'PY'
import sys, re
def letters(t): return re.sub(r"[\s`'-]|[^\x00-\x7f]", "", t)
words = open(sys.argv[2], encoding="utf-8", errors="replace").read().split("\n")
head = words[0].split()
body = []
for n, sheet in enumerate(open(sys.argv[1], encoding="utf-8", errors="replace").read().split("\f")):
    lines = [l for l in sheet.split("\n") if l.strip()]
    if lines and lines[-1].strip() == str(n + 1): lines.pop()
    while lines and head and all(w in head for w in lines[-1].split()): lines.pop()
    body += lines
sys.exit(0 if letters("".join(body)) == letters("".join(words[1:])) else 1)
PY
}
n=0; same=0; sheets=0; over=0; : > $W/differ; : > $W/missing; : > $W/bad; : > $W/over
for p in $pages; do
  mkdir -p $W/$(dirname $p)
  $MINI -T pdf $p > $W/$p.pdf 2> $W/$p.err; $MINI -T words $p > $W/$p.words 2> /dev/null
  n=$((n + 1))
  pdftotext -raw $W/$p.pdf $W/$p.txt 2> $W/$p.poppler || echo $p >> $W/bad
  [ -s $W/$p.poppler ] && echo $p >> $W/bad
  sheets=$((sheets + $(grep -a -o '/Count [0-9]*' $W/$p.pdf | head -1 | cut -d' ' -f2)))
  grep 'not in the fonts' $W/$p.err | sed 's/.*character \(.*\): not.*/\1/' >> $W/missing
  # (a line past the paper's edge: its end is in the file, and no reader gives it)
  if same_words $W/$p.txt $W/$p.words; then same=$((same + 1))
  elif grep -q "past the paper" $W/$p.err; then echo $p >> $W/over
  else echo $p >> $W/differ; fi
done
echo "pages: $n, on $sheets sheets; read by pdftotext with the same words: $same"
echo "characters not in the fonts: $(wc -l < $W/missing) in $(grep -l 'not in the fonts' $(find $W -name '*.err') /dev/null | wc -l) pages: $(sort $W/missing | uniq -c | sort -rn | awk '{printf "%s %s  ", $1, $2}')"
echo "pages with a line past the paper's right edge: $(grep -l 'past the paper' $(find $W -name '*.err') /dev/null | wc -l) ($(cat $(find $W -name '*.err') | grep 'past the paper' | sed 's/.*: \([0-9]*\) lines.*/\1/' | paste -sd+ | bc) lines); of them, read with other words: $(wc -l < $W/over)"
[ -s $W/bad ] && echo "pdftotext complains of: $(sort -u $W/bad | tr '\n' ' ')" | fold -s -w 110
[ -s $W/differ ] && echo "words differ: $(tr '\n' ' ' < $W/differ)" | fold -s -w 110
[ ! -s $W/differ ] && [ ! -s $W/bad ]
