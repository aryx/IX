#!/bin/bash
# Claude Code
#
# Copyright (C) 2026 Yoann Padioleau
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Library General Public License
# (LGPL) as published by the Free Software Foundation; either version
# 2 of the License, or (at your option) any later version.
#
# The fixed point of ix built by ix (plan_mkfiles.md, step 3): ix built
# twice from nothing by mini-mk over the mkfiles, first by the programs
# dune built (./bin), then by the programs of that first build alone
# (mini-ml compiled by mini-ml, mini-ld linked by mini-ld, the mkfiles
# run by mini-mk...). Every file of the two builds is the same, to the
# byte: objects, libraries, the lexers and parsers written, programs.
# So a third build, by the second's programs, would be the second again.
# usage: mkfiles/fixpoint.sh      (after dune build; about 5 minutes)

ROOT=$(cd "$(dirname "$0")/.." && pwd)
W=$(mktemp -d); trap 'rm -rf $W' EXIT
cd $ROOT
rm -rf _mk
PATH=$ROOT/bin:$PATH mini-mk > $W/1.log 2>&1 || { echo "FAIL the first build: $(tail -3 $W/1.log | cut -c1-300)"; exit 1; }
mv _mk $W/1
mkdir $W/bin
cp $(find $W/1 -name 'mini-*' -type f) $W/bin/
echo "ok the first build, by dune's programs: $(find $W/1 -type f | wc -l) files, $(ls $W/bin | wc -l) programs ($(ls $W/bin | tr '\n' ' '))"
# only those programs, and the system's (the shell, ls, mkdir): not ./bin, not what make install put in the PATH
PATH=$W/bin:/usr/bin:/bin mini-mk > $W/2.log 2>&1 || { echo "FAIL the second build: $(tail -3 $W/2.log | cut -c1-300)"; exit 1; }
if diff -rq $W/1 _mk > $W/diff.txt; then echo "ok the second build, by the first's programs: the same $(find _mk -type f | wc -l) files"
else echo "FAIL the second build differs:"; head -20 $W/diff.txt; exit 1; fi
