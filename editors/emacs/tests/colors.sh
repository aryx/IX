#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The colors of a part of a text against the whole text's
# (Ebuffer.colors: the highlighter is given the lines shown, from an
# item's start before them; mini-emacs-tty -whole gives it the text):
# each of ix's sources of a language mini-emacs has a mode for, its
# screen (with the author's colors: a parameter's and a local's show) at four places (its start, its end, six screens down, three
# up from the end), by the two ways. The screens that differ are where
# a part does not say what the whole does (a comment or a string with
# a line that looks like an item's start; an assembly file's labels, a
# Smalltalk class's variables, said far from their uses). And the time
# of 100 characters typed in the largest OCaml source, by each way.
# The numbers of docs/plans/plan_emacs.md and of Ebuffer.ml's comment.
# usage: editors/emacs/tests/colors.sh [-v]   (some minutes; -v: each screen that differs)
cd "$(dirname "$0")/../../.."
E=$PWD/_build/default/editors/emacs/tty/Main.exe
W=$(mktemp -d); trap 'rm -rf $W' EXIT
files=0; screens=0; bad=0
for f in $(tests/ix_files.sh . | grep -E '\.(ml|mli|c|h|s|scm|pas|st)$'); do
  files=$((files + 1))
  for k in '40x100' '40x100 A->' '40x100 C-v C-v C-v C-v C-v C-v' '40x100 A-> A-v A-v A-v'; do
    screens=$((screens + 1))
    $E -colors -keys "$k" $f > $W/part 2>&1; $E -whole -colors -keys "$k" $f > $W/whole 2>&1
    cmp -s $W/part $W/whole || { bad=$((bad + 1)); [ "${1:-}" = -v ] && echo "$f [$k]"; }
  done
done
echo "$files files, $screens screens, $bad not the whole text's"
big=$(tests/ix_files.sh . | grep '\.ml$' | xargs wc -c | sort -n | tail -2 | head -1 | awk '{print $2}')
keys=$(printf '=x %.0s' $(seq 1 100))
# (a run's time, 100 characters typed in it: milliseconds a character)
ms() { local a=$(date +%s%N); "$@" > /dev/null 2>&1; awk "BEGIN { printf \"%.1f\", ($(date +%s%N) - $a) / 100000000 }"; }
echo "$big ($(wc -c < $big) bytes): 100 characters typed, milliseconds a character:"
echo "  at its start: $(ms $E -keys "40x100 $keys" $big) a part, $(ms $E -whole -keys "40x100 $keys" $big) the whole"
echo "  at its end: $(ms $E -keys "40x100 A-> $keys" $big) a part, $(ms $E -whole -keys "40x100 A-> $keys" $big) the whole"
