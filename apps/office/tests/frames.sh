#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-office's frames (docs/plans/plan_office.md), as the games' are
# (games/tests/frames.sh, which says how): the program run without a
# window, a session a line of frames.expected here (the playground's
# sixteen scenes of TinyOffice, its tests/common/scenes/Scenes_2d.ml's
# scripts), its last frame's sum and, where the playground is there, its
# golden frame pixel by pixel. Each session has a store of documents of
# its own, empty (reopened saves one and opens it).
# usage: apps/office/tests/frames.sh [dir]
#   dir: where the programs are (default: dune's, _build/default/apps;
#        else mini-mk's, as _mk/7/apps)
cd "$(dirname "$0")/../../.."
FRAMES=apps/office/tests/frames.expected exec games/tests/frames.sh ${1:-_build/default/apps}
