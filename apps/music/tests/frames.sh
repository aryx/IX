#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-rebirth's frames (docs/plans/plan_audio.md, stage 6): the games'
# test (games/tests/frames.sh says how) of the sessions of
# frames.expected, each compared with the playground's golden frame of
# its name too (TinyReBirth, TinyReBirth_running, TinyReBirth_edited).
# usage: apps/music/tests/frames.sh [dir]
#   dir: where apps/'s programs are (default: dune's, _build/default/apps;
#        else mini-mk's, as _mk/7/apps)
cd "$(dirname "$0")/../../.."
FRAMES=apps/music/tests/frames.expected exec games/tests/frames.sh ${1:-_build/default/apps}
