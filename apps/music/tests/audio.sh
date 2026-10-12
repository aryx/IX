#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-rebirth's sound (docs/plans/plan_audio.md, stage 6): the games'
# test (games/tests/audio.sh says how) of the sessions of
# audio.expected: each one's WAV, its sum, and byte for byte the
# playground's own TinyReBirth's -dump-audio where it is built.
# usage: apps/music/tests/audio.sh [dir]
cd "$(dirname "$0")/../../.."
AUDIO=apps/music/tests/audio.expected THEIRS=apps exec games/tests/audio.sh ${1:-_build/default/apps}
