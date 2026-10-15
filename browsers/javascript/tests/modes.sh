#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The engine's unit tests three times, as mini-chrome's dune runs them:
# as they are, with the simple code paths (MINI_OPTI=off), and with a
# function's body walked and not compiled (MINI_OPTI=walk): the three
# agree.
# usage: browsers/javascript/tests/modes.sh
cd "$(dirname "$0")/../../.."
# macOS: an async body's thread has a 512 KB stack (Linux's: 8 MB), too
# small for max_depth's 2000 calls by the simple paths: a SIGBUS, not a
# RangeError (docs/plans/bugs/ix.md); its one check left out there
small=
[ "$(uname)" = Darwin ] && small=1
for mode in "" off walk; do
  JS_SMALL_THREAD_STACK=${mode:+$small} MINI_OPTI=$mode _build/default/browsers/javascript/tests/Test.exe > /dev/null 2>&1 || { echo "FAIL browsers/javascript's tests, MINI_OPTI=$mode"; exit 1; }
done
echo "ok: browsers/javascript's tests, three ways"
