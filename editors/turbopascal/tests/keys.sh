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
# mini-5i).
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
  echo "== $1: $2"; "${@:3}" -keys "$2" 2>&1; echo "exit $?"
}
all() {
  session first '' "$@"
  session run 'C-F9' "$@"
  session menu 'A-c' "$@"
  session pcode 'PageDown ArrowDown A-c =p' "$@"
  session error '=x F9' "$@"
  session debug 'A-s =g22 Enter C-F8 C-F9 C-F9 C-F7 =x Enter C-F7 =j Enter' "$@"
  session nokey 'F99' "$@"
}
all $NATIVE > $W/native
[ -n "$RECORD" ] && { cp $W/native $EXPECTED; echo "recorded: $(grep -c '^== ' $EXPECTED) sessions, $(wc -l < $EXPECTED) lines"; exit 0; }
if cmp -s $W/native $EXPECTED; then echo "ok mini-turbopascal's screens by dune: $(grep -c '^== ' $EXPECTED) sessions, $(wc -l < $EXPECTED) lines"
else echo "FAIL mini-turbopascal's screens by dune"; diff $EXPECTED $W/native | head -20; failures=$((failures + 1)); fi
if [ -x $MINI ]; then
  all $RUN $MINI > $W/mini
  if cmp -s $W/native $W/mini; then echo "ok mini-turbopascal's screens by mini-ml ($O) as by dune"
  else echo "FAIL mini-turbopascal's screens by mini-ml ($O)"; diff $W/native $W/mini | head -20; failures=$((failures + 1)); fi
else echo "not run: $MINI is not built"; fi
exit $failures
