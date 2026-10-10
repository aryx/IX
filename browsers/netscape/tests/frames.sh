#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-netscape's frames (docs/plans/plan_browser.md, stage 7), as the
# games' (games/tests/frames.sh, which says how): the program run
# without a window on the pages of pages/ (files: no network), a session
# a line of frames.expected here (a link clicked, Back, an address
# typed, a form sent, a #fragment, the keys, a file that is not there),
# its last frame's sum. RECORD=1 writes the sums again.
# usage: browsers/netscape/tests/frames.sh [dir]
#   dir: where the program is (default: dune's, _build/default/browsers)
cd "$(dirname "$0")/../../.."
FRAMES=browsers/netscape/tests/frames.expected exec games/tests/frames.sh ${1:-_build/default/browsers}
