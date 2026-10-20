#!/bin/sh
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The units of libraries of ix's (mkfiles/mklib's lib.a), in the order
# they start in: what mini-ar t lists, a unit's source file, made its
# name. usage: mkfiles/units.sh lib.a...
for a in "$@"; do mini-ar t "$a"; done | sed 's,.*/,,; s,\.ml$,,'
