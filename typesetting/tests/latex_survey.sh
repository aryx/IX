#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# What a .nw file (or a .tex) asks of a LaTeX reader: its commands and
# its environments, counted, in its prose (the code chunks, <<name>>=
# to a line with @ alone, and the verbatim environments are taken
# out, and the comments); and its chunks. For plan_typesetting.md's
# stage 7: the table of commands of Latex is what this prints for the
# article and the books.
#
# usage: latex_survey.sh file...
for f in "$@"; do
  echo "== $f: $(wc -l < $f) lines, $(grep -c '^<<.*>>=$' $f) chunks, $(grep -c '^#include' $f) #include, $(grep -c '\\input{' $f) \\input"
  prose=$(awk '/^<<.*>>=$/ { code = 1; next } code && /^@( |$)/ { code = 0; next } code { next }
       /\\begin\{(verbatim|vdiagram|Verbatim)\}/ { verb = 1; next } /\\end\{(verbatim|vdiagram|Verbatim)\}/ { verb = 0; next } verb { next }
       { print }' $f | sed -e 's/\\%/ /g' -e 's/%.*//' -e 's/\[\[[^]]*\]\]//g' -e 's/\\verb\(.\)[^\1]*\1//g')
  echo "  commands: $(echo "$prose" | grep -o '\\[a-zA-Z]\+\*\?' | sort | uniq -c | sort -rn | awk '{ printf "%s %s  ", $1, $2 }')"
  echo "  environments: $(echo "$prose" | grep -o '\\begin{[a-zA-Z*]\+}' | sed 's/\\begin{//; s/}//' | sort | uniq -c | sort -rn | awk '{ printf "%s %s  ", $1, $2 }')"
  echo "  lines with \$: $(echo "$prose" | grep -c '\$')"
done
