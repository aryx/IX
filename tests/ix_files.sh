#!/bin/sh
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# ix's files, for the tests over "every file of ix": each file (and
# symbolic link: a kernel shares a unit with another that way) under
# the paths, relative to ix's root, sorted; not the directories a
# build makes (dune's _build, mini-mk's _mk, a kernel's build). A test
# takes its kind of file of them (grep '\.ml$').
# The file system is asked, not git (git ls-files): a checkout without
# its .git (Docker's) has the same files, and a new file is tested
# before it is added.
#
# Usage: ix_files.sh [path...]   (default: all of ix)

cd "$(dirname "$0")/.." || exit 1
[ $# = 0 ] && set -- .
find "$@" \( -name _build -o -name _mk -o -name .git -o -name build -o -name __pycache__ \) -prune \
  -o \( -type f -o -type l \) -print | sed 's|^\./||' | LC_ALL=C sort
