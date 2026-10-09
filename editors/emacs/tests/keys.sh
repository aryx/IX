#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-emacs with no screen (docs/plans/plan_emacs.md, stage 2): a
# session is a file and a line of keys (mini-emacs-tty -keys), what it
# leaves the screen as text, and the file if it was saved. Each by
# dune's build must be keys.expected's (read by a person once: efuns
# needs GTK and is not run), and mini-ml's build's the same (as it is,
# arm64; -5: arm, under mini-5i).
# usage: editors/emacs/tests/keys.sh [-5] [-record] [mk's tree]
#   (dune build, and mini-mk O=7 or O=5 in editors/emacs/tty, first;
#   mk's tree: where _mk is, when it is not here)
cd "$(dirname "$0")/../../.."
ROOT=$PWD
O=7; RUN=; RECORD=
[ "${1:-}" = -5 ] && { O=5; RUN=$ROOT/_build/default/machine/Main.exe; shift; }
[ "${1:-}" = -record ] && { RECORD=1; shift; }
NATIVE=$ROOT/_build/default/editors/emacs/tty/Main.exe
MINI=$(cd ${1:-.} && pwd)/_mk/$O/editors/emacs/tty/mini-emacs-tty
EXPECTED=$ROOT/editors/emacs/tests/keys.expected
W=$(mktemp -d); trap 'rm -rf $W' EXIT
failures=0
session() { # its name, its file's text (none: no file named; -: one named that is not there), its keys
  rm -f $W/f.txt; [ -n "$2" ] && [ "$2" != - ] && printf "$2" > $W/f.txt
  echo "== $1: $3"
  (cd $W && if [ -n "$2" ]; then "${@:4}" -keys "$3" f.txt; else "${@:4}" -keys "$3"; fi 2>&1; echo "exit $?")
  case "$3" in *"C-x C-s"*) echo "-- f.txt:"; (cd $W && cat f.txt 2>&1);; esac
}
lines=$(seq 1 60 | tr '\n' '|' | sed 's/|/\\n/g')
all() {
  session first '' '' "$@"
  session typed '' '8x40 =hello Enter =world' "$@"
  session file 'ab\n\tc\nd\n' '6x44 ArrowDown C-e' "$@"
  # the keys' names: a prefix shown, a key bound to nothing, Escape for Meta
  session prefix 'ab\n' '6x44 C-x' "$@"
  session undefined 'ab\n' '6x44 C-x =z' "$@"
  session undefined-key 'ab\n' '6x44 C-z' "$@"
  session escape 'one two three\n' '6x44 Escape =f Escape' "$@"
  # moves: a character, a word, a line and its column kept past a short one
  session words 'one two, three\n' '6x44 A-f A-f A-f A-b =X' "$@"
  session column 'a long line\n\nshort\nanother long line\n' '8x44 C-e C-n C-n C-n =X' "$@"
  session column-tab 'abcdefghij\n\tx\n' '6x44 C-f C-f C-f C-n =X' "$@"
  session ends 'one\ntwo\n' '6x44 C-p A-> C-n' "$@"
  session utf8 'h\303\251llo w\303\266rld\n' '6x44 C-f C-f =X C-e C-b Backspace C-a C-d C-d' "$@"
  # the text changed, and saved
  session save 'one\ntwo\n' '6x44 C-n Enter =1.5 Tab =x C-x C-s' "$@"
  session delete 'one\ntwo\n' '6x44 C-e C-d Delete Backspace C-x C-s' "$@"
  session new - '6x44 =text Enter C-x C-s' "$@"
  session nofile '' '6x44 =text C-x C-s' "$@"
  # the frame moves over the text
  session scroll "$lines" '8x44 C-v C-v' "$@"
  session scroll-back "$lines" '8x44 C-v C-v C-v A-v' "$@"
  session scroll-point "$lines" '8x44 C-n C-n C-n C-n C-n C-n C-n' "$@"
  session scroll-ends "$lines" '8x44 A-> PageUp A-< PageUp' "$@"
  session recenter "$lines" '8x44 C-v C-n C-n C-l' "$@"
  session fold 'a line that is longer than the frame is folded, here twice\nshort\n' '8x24 C-e =! C-n' "$@"
  session fold-scroll 'a line that is longer than the frame is folded, here twice\nb\nc\nd\ne\n' '6x24 A->' "$@"
  session control 'a\001b\177c\377d\n' '6x44 C-e' "$@"
  # the screen's size
  session small 'one\ntwo\nthree\n' '3x12 C-n C-n' "$@"
  session tiny 'one\n' '1x5 =x' "$@"
  session nokey '' 'F99' "$@"
}
all $NATIVE > $W/native
if [ -n "$RECORD" ]; then cp $W/native $EXPECTED; echo "recorded: $(grep -c '^== ' $EXPECTED) sessions, $(wc -l < $EXPECTED) lines"; exit 0; fi
if cmp -s $W/native $EXPECTED; then echo "ok mini-emacs's screens by dune: $(grep -c '^== ' $EXPECTED) sessions, $(wc -l < $EXPECTED) lines"
else echo "FAIL mini-emacs's screens by dune"; diff $EXPECTED $W/native | head -20; failures=$((failures + 1)); fi
if [ -x $MINI ]; then
  all $RUN $MINI > $W/mini
  if cmp -s $W/native $W/mini; then echo "ok mini-emacs's screens by mini-ml ($O) as by dune"
  else echo "FAIL mini-emacs's screens by mini-ml ($O)"; diff $W/native $W/mini | head -20; failures=$((failures + 1)); fi
else echo "not run: $MINI is not built"; fi
[ $failures = 0 ]
