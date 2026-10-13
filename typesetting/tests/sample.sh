#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-troff and mini-man on a page of ix's own, sample.1, written to
# have each macro of man(6) and each of troff's requests that the
# manual's pages use; what they say compared with sample.expected.
# The same page as a PDF file: its bytes by their sum, and its words
# (pdf.sh reads such files back with another program's reader).
# And a paper of ix's own, sample.ms, with each macro of ms(6) that
# principia's papers use: as text (troff's own lines but for its even
# right edge, by ms.sh's way, once) and as a PDF file.
# And a document in the new format, sample.md (Ixdoc), with each
# thing of it once: as text, written back, as a PDF file.
# Then what mini-troff says of a request it does not know, mini-man
# finding a page in a tree, and one that is not there.
#
# sample.expected is what troff itself writes of sample.1 (goken's, as
# nroff, with Plan 9's tmac.an), but for the characters that are not
# ASCII, where goken's troff writes a blank: man.sh compares the two on
# principia's whole manual, when principia and goken are there; this
# one needs nothing outside the repository.
#
# usage: sample.sh [-u] [dir]
#   -u   sample.expected written from this run
#   dir  where _mk's programs are (typesetting/troff/mini-troff,
#        typesetting/man/mini-man under it); default: dune's

HERE=$(cd "$(dirname "$0")" && pwd); ROOT=$(cd $HERE/../.. && pwd)
update=; [ "${1:-}" = -u ] && { update=1; shift; }
if [ $# -ge 1 ]; then set -- $(realpath $1); TROFF=$1/typesetting/troff/mini-troff; MAN=$1/typesetting/man/mini-man
else TROFF=$ROOT/_build/default/typesetting/troff/Main.exe; MAN=$ROOT/_build/default/typesetting/man/Main.exe; fi
W=$(mktemp -d); trap 'rm -rf $W' EXIT
cd $HERE
{ echo "== mini-troff sample.1"
  $TROFF sample.1 2>&1
  echo "== mini-troff -T pdf sample.1: its sheets, its bytes' sum (the same whatever compiled mini-troff), what it says"
  $TROFF -T pdf sample.1 > $W/sample.pdf 2> $W/err; echo "status $?"
  grep -a -o '/Count [0-9]*' $W/sample.pdf | head -1; cksum < $W/sample.pdf; cat $W/err
  echo "== mini-troff -T words sample.1: the file's words"
  $TROFF -T words sample.1 2>&1
  echo "== mini-troff sample.ms: a paper"
  $TROFF sample.ms 2>&1
  echo "== mini-troff -T pdf sample.ms"
  $TROFF -T pdf sample.ms > $W/paper.pdf 2> $W/err; echo "status $?"
  grep -a -o '/Count [0-9]*' $W/paper.pdf | head -1; cksum < $W/paper.pdf; cat $W/err
  echo "== mini-troff sample.md: the new format"
  $TROFF sample.md 2>&1
  echo "== mini-troff -T md sample.md: written back; and that read and written again, the same"
  $TROFF -T md sample.md 2> /dev/null | tee $W/again.md
  $TROFF -md -T md $W/again.md 2> /dev/null | cmp - $W/again.md; echo "status $?"
  echo "== mini-troff -T pdf sample.md"
  $TROFF -T pdf sample.md > $W/md.pdf 2> $W/err; echo "status $?"
  grep -a -o '/Count [0-9]*' $W/md.pdf | head -1; cksum < $W/md.pdf; cat $W/err
  echo "== mini-troff -T md sample.1: a manual page converted, its first lines"
  $TROFF -T md sample.1 2> /dev/null | head -30
  echo "== the standard input, a request not known, a table"
  printf '.TH X 1\n.SH NAME\nx \\- y\n.XY z\n.TS\nl l.\na\tb\n.TE\nafter\n' | $TROFF 2> $W/err; echo "status $?"; cat $W/err
  echo "== mini-man in a tree"
  mkdir -p $W/man/1 $W/man/6; cp sample.1 $W/man/1/sample
  printf '.TH SAMPLE 6\n.SH NAME\nsample \\- the format of nothing\n' > $W/man/6/sample
  $MAN -m $W/man sample 2>&1 | grep -c . ; echo "status $?"
  $MAN -m $W/man 6 sample 2>&1; echo "status $?"
  $MAN -m $W/man 1 nothing 2>&1 | sed "s|$W|TMP|"; echo "status ${PIPESTATUS[0]}"
  $MAN 2>&1; echo "status $?"
  $TROFF -x 2>&1 | head -1; echo "status ${PIPESTATUS[0]}"
  $TROFF /nonexistent 2>&1; echo "status $?"
} > $W/out
if [ -n "$update" ]; then cp $W/out sample.expected; echo "sample.expected written"; exit 0; fi
if cmp -s $W/out sample.expected; then echo "ok sample.sh ($(grep -c . sample.expected) lines)"
else echo "FAIL sample.sh"; diff sample.expected $W/out | head -20; exit 1; fi
