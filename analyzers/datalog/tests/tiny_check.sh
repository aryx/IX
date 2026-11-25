#!/usr/bin/env bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-analyze FLAG on tiny/'s programs, each read as each system builds
# it, by one mini-analyze call over both builds:
# - tiny-kernel's: t-IX's build, made here as TinyKernel/Makefile makes
#   it, in a copy of tiny/, each program's manifest (tiny-ld -map's), its
#   paths read in tiny/ (-project); the kernel's among them;
# - the host's: the executables dune builds under tiny/, their manifests
#   made by mini-analyze from dune's own answers (Dune_manifest).
# mini-analyze runs each program as linked, its platform's files among
# them, and merges their reports (-dead's: what every program that has
# the file says, so a library's function one program does not call is
# not dead). tiny-cc's programs are not read (no ML unit).
# Each report once, sorted, recorded: -caps caps_tiny.txt, -bugs
# bugs_tiny.txt, -dead dead_tiny.txt, -exn exn_tiny.txt (a program's
# toplevel exceptions, by the program, build or tiny/TinyBuildSystem,
# lib_core's that every program may raise left out: compare.sh's
# exn_lines). -check (make test's): the answer against the recording,
# without line numbers (an edit above a function moves it). With no
# out-file, the reports on the standard output. Seconds.
# (old, before the manifests: a table of the programs, each one's main
# file, its platform's flags, -L, -own, -I's, its runs merged here)
# usage: analyzers/datalog/tests/tiny_check.sh -caps|-dead|-bugs|-exn [out-file|-check]
#   (dune build first)
# ANALYZE: the analyzer, if not dune's.
cd "$(dirname "$0")/../../.."
ANALYZE=${ANALYZE:-_build/default/analyzers/Main.exe}
export LC_ALL=C
# (no analyzer, being rebuilt say: every program would say nothing)
[ -x "${ANALYZE%% *}" ] || { echo "no analyzer: $ANALYZE"; exit 2; }
flag=$1; out=$2; check=; show=
case $flag in
  -caps|-bugs|-dead|-exn) expected=analyzers/datalog/tests/${flag#-}_tiny.txt;;
  *) echo "usage: tiny_check.sh -caps|-dead|-bugs|-exn [out-file|-check]"; exit 2;;
esac
if [ "$out" = -check ]; then check=1; out=$(mktemp); fi
if [ -z "$out" ]; then show=1; out=$(mktemp); fi
W=$(mktemp -d); trap 'rm -rf $W' EXIT
. analyzers/datalog/tests/compare.sh
notes=$(notes_of $expected)
make -s -C tiny/TinyKernel O=$W/tix $W/tix/disk.img > $W/tix.log 2>&1 ||
  { tail -5 $W/tix.log; echo "tiny_check.sh: t-IX's build failed"; exit 2; }
$ANALYZE $flag -project tiny $W/tix/src tiny > $W/answer 2> $W/err ||
  { grep -v WARNING $W/err | tail -5; echo "FAIL mini-analyze $flag on tiny/'s programs: not all read"; exit 1; }
# (the reports, not the programs' list under them)
sed '/^[0-9]* reports, over the/,$d' $W/answer |
  if [ $flag = -exn ]; then exn_lines by; else cat; fi | sort -u > $out
if [ -n "$show" ]; then cat $out; rm -f $out; exit 0; fi
if [ -z "$check" ]; then
  keep_notes "$notes" $out; echo "$(grep -vc '^#' $out) reports: $out"; exit 0
fi
compare "mini-analyze $flag on tiny/'s programs" $out $expected /dev/null
st=$?
rm -f $out; exit $st
