#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-turbopascal's IDE with no screen (docs/plans/plan_pascal.md,
# stage 3): a session is a line of keys (Keys.mli), what it leaves the
# screen as text. The sessions are the author's playground's golden
# frames' (its tests' Scenes_2d: run, menu, pcode, error, debug), and
# the first screen. Each screen by dune's build must be keys.expected's,
# and mini-ml's build's the same (as it is, arm64; -5: arm, under
# mini-5i). Then the screen at other sizes (16x60 in a script: a window
# resized), the plan's stage 4. And pictures (stage 5): the screen as a
# window paints it, written to a file, its sum frames.expected's.
# usage: editors/turbopascal/tests/keys.sh [-5] [-record] [mk's tree]
#   (dune build, and mini-mk O=7 or O=5 in editors/turbopascal/tty, first;
#   mk's tree: where _mk is, when it is not here)
cd "$(dirname "$0")/../../.."
O=7; RUN=; RECORD=
[ "${1:-}" = -5 ] && { O=5; RUN=_build/default/machine/Main.exe; shift; }
[ "${1:-}" = -record ] && { RECORD=1; shift; }
NATIVE=_build/default/editors/turbopascal/tty/Main.exe
MINI=${1:-.}/_mk/$O/editors/turbopascal/tty/mini-turbopascal-tty
EXPECTED=editors/turbopascal/tests/keys.expected
W=$(mktemp -d); trap 'rm -rf $W' EXIT
failures=0
session() { # its name, its keys
  echo "== $1: $2"; "${@:3}" -keys "$2" $VIEWS 2>&1; echo "exit $?"
}
all() {
  session first '' "$@"
  session run 'C-F9' "$@"
  session menu 'A-c' "$@"
  session pcode 'PageDown ArrowDown A-c =p' "$@"
  session error '=x F9' "$@"
  session debug 'A-s =g22 Enter C-F8 C-F9 C-F9 C-F7 =x Enter C-F7 =j Enter' "$@"
  # a window made smaller, then larger: fewer rows and columns, more
  session small '16x60 PageDown' "$@"
  session small-debug '16x60 A-s =g22 Enter C-F8 C-F9 C-F7 =x Enter' "$@"
  session small-run '12x40 C-F9 . . . . .' "$@"
  session small-menu '10x44 A-c =p' "$@"
  session tiny '3x10' "$@"
  session large '40x100 A-s =g30 Enter A-r' "$@"
  # (a program's screen is the size the IDE had when it started)
  session after '16x60 C-F9 . . . . . 24x80' "$@"
  session after-key '16x60 C-F9 . . . . . 24x80 Enter ArrowDown' "$@"
  session nokey 'F99' "$@"
}
all $NATIVE > $W/native
[ -n "$RECORD" ] && { cp $W/native $EXPECTED; echo "recorded: $(grep -c '^== ' $EXPECTED) sessions, $(wc -l < $EXPECTED) lines"; RECORDFRAMES=1; }
if [ -z "$RECORD" ]; then
# the screen made after each key, as a window does: the rows a view keeps
# of the one before (Turbo_view.cache) give the same screens as none kept
for v in "-views" "-views -nocache"; do
  VIEWS=$v; all $NATIVE > $W/views; VIEWS=
  if cmp -s $W/views $EXPECTED; then echo "ok mini-turbopascal's screens with $v"
  else echo "FAIL mini-turbopascal's screens with $v"; diff $EXPECTED $W/views | head -20; failures=$((failures + 1)); fi
done
if cmp -s $W/native $EXPECTED; then echo "ok mini-turbopascal's screens by dune: $(grep -c '^== ' $EXPECTED) sessions, $(wc -l < $EXPECTED) lines"
else echo "FAIL mini-turbopascal's screens by dune"; diff $EXPECTED $W/native | head -20; failures=$((failures + 1)); fi
if [ -x $MINI ]; then
  all $RUN $MINI > $W/mini
  if cmp -s $W/native $W/mini; then echo "ok mini-turbopascal's screens by mini-ml ($O) as by dune"
  else echo "FAIL mini-turbopascal's screens by mini-ml ($O)"; diff $W/native $W/mini | head -20; failures=$((failures + 1)); fi
else echo "not run: $MINI is not built"; fi
fi
# the screen as the windows paint it (hosts/Cells and Picture: Plan 9's
# font, the PC's colours and box characters): a session's picture's sum
frames() {
  frame() { "${@:3}" -keys "$2" -frame $W/f.ppm > /dev/null 2>&1; echo "$1|$2|$(sha256sum < $W/f.ppm | cut -d' ' -f1)"; }
  frame first '' "$@"
  frame menu 'A-c' "$@"
  # (under mini-5i a picture is half a minute: two of them there)
  [ -n "$FEW" ] && return
  frame pcode 'PageDown ArrowDown A-c =p' "$@"
  frame error '=x F9' "$@"
  frame debug 'A-s =g22 Enter C-F8 C-F9 C-F9 C-F7 =x Enter C-F7 =j Enter' "$@"
  frame open 'F3' "$@"
  frame run '12x40 C-F9 . . . . .' "$@"
  frame large '40x100 A-s =g30 Enter A-r' "$@"
}
FRAMES=editors/turbopascal/tests/frames.expected
frames $NATIVE > $W/native
[ -n "$RECORDFRAMES" ] && { cp $W/native $FRAMES; echo "recorded: $(wc -l < $FRAMES) frames"; exit 0; }
if cmp -s $W/native $FRAMES; then echo "ok mini-turbopascal's frames by dune: $(wc -l < $FRAMES) pictures"
else echo "FAIL mini-turbopascal's frames by dune"; diff $FRAMES $W/native | cut -c1-60 | head; failures=$((failures + 1)); fi
if [ -x $MINI ]; then
  FEW=$RUN; frames $NATIVE > $W/native; frames $RUN $MINI > $W/mini
  if cmp -s $W/native $W/mini; then echo "ok mini-turbopascal's frames by mini-ml ($O) as by dune"
  else echo "FAIL mini-turbopascal's frames by mini-ml ($O)"; diff $W/native $W/mini | cut -c1-60 | head; failures=$((failures + 1)); fi
fi
exit $failures
