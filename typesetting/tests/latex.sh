#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-troff on principia's books and its article: the .nw files that
# are a document (they have a \documentclass), simple LaTeX with
# noweb's chunks of code in it (Latex.mli).
#
# 1. Each as a PDF file: that it is made, its sheets, and what
#    mini-troff says of it, counted by kind (a command not known, a
#    reference to a label that is not there, a picture from a file, a
#    character the fonts have not, lines past the right edge).
# 2. Its words against pdflatex's, where a PDF file made by principia's
#    build is beside the book (Make-1.0.pdf, iwp9.pdf; the newest): the
#    words of three letters and more that poppler's pdftotext reads in
#    each, each as many times as it is there, and how many of pdflatex's
#    are ours. Not all: that file is of an earlier day's source, noweb
#    writes "Uses" where this writes "used in", the references have
#    other labels ([Pik+95], and the pages they are cited on), and a
#    page's header is words too. Under 90 of 100 is a failure.
#
# Needs principia (PRINCIPIA, default ~/github/principia-softwarica)
# and poppler's pdfinfo and pdftotext.
#
# usage: latex.sh [-k dir] [dir]
#   -k dir  the PDF files and what was said kept there
#   dir     where _mk's programs are (typesetting/troff/mini-troff
#           under it); default: dune's

HERE=$(cd "$(dirname "$0")" && pwd); ROOT=$(cd $HERE/../.. && pwd)
keep=; [ "${1:-}" = -k ] && { keep=$2; shift 2; }
if [ $# -ge 1 ]; then TROFF=$(realpath $1)/typesetting/troff/mini-troff; else TROFF=$ROOT/_build/default/typesetting/troff/Main.exe; fi
S=$(readlink -f ${PRINCIPIA:-$HOME/github/principia-softwarica})
[ -d $S ] || { echo "latex.sh: no principia at $S (PRINCIPIA)"; exit 2; }
[ -x $TROFF ] || { echo "latex.sh: no $TROFF"; exit 2; }
W=$(mktemp -d); trap 'rm -rf $W' EXIT
[ -n "$keep" ] && { mkdir -p $keep; W=$(realpath $keep); trap - EXIT; }

words() { pdftotext "$1" - 2> /dev/null | tr -cs 'A-Za-z' '\n' | tr A-Z a-z | awk 'length >= 3' | sort | uniq -c | awk '{ print $2, $1 }'; }

cd $S
failures=0; books=0; sheets=0; compared=0
for f in $(grep -l '\\documentclass' */*.nw */*/*.nw | grep -v 'Template\|_old' | sort); do
  n=$(basename $f .nw); d=$(dirname $f)
  books=$((books + 1))
  if ! timeout 300 $TROFF -T pdf $f > $W/$n.pdf 2> $W/$n.err; then echo "FAIL $f: no PDF file"; failures=$((failures + 1)); continue; fi
  pages=$(pdfinfo $W/$n.pdf 2> /dev/null | awk '/^Pages/ { print $2 }')
  [ -n "$pages" ] || { echo "FAIL $f: not a PDF file"; failures=$((failures + 1)); continue; }
  sheets=$((sheets + pages))
  line="ok $f: $pages sheets, $(wc -l < $W/$n.err) said"
  ref=$(ls -t $d/$n-*.pdf $d/$n.pdf 2> /dev/null | head -1)
  if [ -n "$ref" ]; then
    words $W/$n.pdf > $W/ours.w; words $ref > $W/theirs.w
    part=$(join -a1 -a2 -e 0 -o 0,1.2,2.2 $W/ours.w $W/theirs.w | awk '{ b += $3; m += ($2 < $3 ? $2 : $3) } END { printf "%d", (b ? 100 * m / b : 0) }')
    compared=$((compared + 1))
    line="$line; of the words of $(basename $ref), $part in 100"
    [ $part -ge 90 ] || { line="FAIL${line#ok}"; failures=$((failures + 1)); }
  fi
  echo "$line"
done
echo "== what was said, by kind"
cat $W/*.err | sed -E 's#^[^ ]*:[0-9]+: ##; s#^[^ ]*\.nw: ##; s#^[A-Za-z_0-9]*\.(nw|tex): ##; s#: not known$##; s#\\ref\{[^}]*\}#\\ref{...}#; s#\\cite\{[^}]*\}#\\cite{...}#; s#no file .*#no file ...#; s#a picture from a file .*#a picture from a file#; s#the character .*: not in#a character not in#; s#^[0-9]+ lines go past#lines past#; s#\(in mathematics\)#(in mathematics)#' \
  | awk '/^\\[A-Za-z]+( \(in mathematics\))?$/ { print "a command not known: " $0; next } { print }' | sed -E 's#^(a command not known): .*#\1#' | sort | uniq -c | sort -rn | sed 's/^/  /'
echo "books: $books; sheets: $sheets; compared with pdflatex's: $compared; failures: $failures"
[ $failures = 0 ]
