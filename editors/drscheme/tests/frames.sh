#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-drscheme's frames (docs/plans/plan_scheme.md), as the games'
# (games/tests/frames.sh, which says how): the program run without a
# window, a session a line of frames.expected here, its last frame's sum
# and, where the playground is there, its golden frame pixel by pixel.
# usage: editors/drscheme/tests/frames.sh [dir]
#   dir: where the programs are (default: dune's, _build/default/editors;
#        else mini-mk's, as _mk/7/editors)
cd "$(dirname "$0")/../../.."
FRAMES=editors/drscheme/tests/frames.expected exec games/tests/frames.sh ${1:-_build/default/editors}
