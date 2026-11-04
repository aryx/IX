#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-analyze FLAG on tiny/'s host programs, those OCaml builds and
# checks (tiny/dune's executables: Cap.main or TinyLibSystem.main), each
# with the modules of its tiny libraries, lib_core's found by itself, the
# other ix libraries by -I. Not here: the SDL programs (tsdl, which
# mini-analyze does not read: tiny-machine-window, tiny/sdl/'s apps) and
# what runs on tiny-kernel (its system is tiny's kernel, TinyCalls).
# Each report once, sorted, recorded: -caps caps_tiny.txt (its one line
# TinyBuildSystem.start's, analyzers/datalog/README.md), -bugs
# bugs_tiny.txt, -dead dead_tiny.txt (what every program that has the
# file says dead: TinyLibSystem's functions one program does not call are
# not dead). -check (make test's): the answer against the recording,
# without line numbers (an edit above a function moves it). Seconds.
# usage: analyzers/datalog/tests/tiny_check.sh -caps|-dead|-bugs out-file|-check
#   (dune build first)
# ANALYZE: the program, if not dune's.
cd "$(dirname "$0")/../../.."
ANALYZE=${ANALYZE:-_build/default/analyzers/Main.exe}
export LC_ALL=C
# (no analyzer, being rebuilt say: every program would say nothing)
[ -x "${ANALYZE%% *}" ] || { echo "no analyzer: $ANALYZE"; exit 2; }
flag=$1; out=$2; check=
case $flag in
  -caps) expected=caps_tiny.txt; said=': (no capability|has <)';;
  -bugs) expected=bugs_tiny.txt; said='^bug\? ';;
  -dead) expected=dead_tiny.txt; said=': dead( [a-z]+)?:';;
  *) echo "usage: tiny_check.sh -caps|-dead|-bugs out-file|-check"; exit 2;;
esac
expected=analyzers/datalog/tests/$expected
if [ "$out" = -check ]; then check=1; out=$(mktemp); fi
T=tiny; S=$T/TinyKernel/host/TinyLibSystem.ml; R=$T/TinyLibRegex.ml
M=$T/TinyMachine
CPU="$M/TinyMachineISA.ml $M/TinyMachineCPU.ml"
BROWSER=$(for m in Text Tokens Lines Html Address Http; do
  printf "%s " $T/TinyBrowser/TinyBrowser$m.ml; done)
TML=$(for m in Lexer Tree Printf Parser Types Machine Compile; do
  printf "%s " $T/TinyML/TinyML$m.ml; done)
TC=$(for m in Types Lexer Tree Lower Parser Machine; do
  printf "%s " $T/TinyC/TinyC$m.ml; done)
NET="-I lib_networking/tcp -I lib_networking/tls -I lib_networking/http"
NET="$NET -I lib_crypto -I lib_compression"
# a program a line: its name, its -I's (- for none), its files
programs() {
  cat <<EOF
tiny-build|-I lib_crypto|$S $T/TinyBuildSystem.ml
tiny-shell|-|$S $R $T/TinyShell.ml
tiny-editor|-|$S $R $T/TinyEditorLine.ml
tiny-utils|-|$S $R $T/TinyUtilities.ml
tiny-c|-|$S $TC $T/TinyC.ml
tiny-db|-|$S $T/TinyDatabase.ml
tiny-vcs|-I lib_crypto|$S $T/TinyVCS.ml
tiny-assembler|-|$CPU $S $T/TinyLibSymbols.ml $T/TinyAssembler.ml
tiny-linker|-|$CPU $S $T/TinyLibSymbols.ml $T/TinyLinker.ml
tiny-cpu|-|$CPU $T/TinyCPU.ml
tiny-prof|-|$S $T/TinyLibSymbols.ml $T/TinyProfiler.ml
tiny-ml|-|$S $TML $T/TinyML.ml
tiny-machine|-I lib_core/parallel|$CPU $M/TinyMachineDevices.ml $T/TinyKernel/TinyKernelNetwork.ml $BROWSER $M/TinyMachinePeer.ml $T/TinyMachine.ml
tiny-machine-socket|-|$M/TinyMachineSocket.ml
tiny-machine-fetch|$NET -I lib_graphics/core -I lib_graphics/images|$CPU $M/TinyMachineDevices.ml $BROWSER $M/TinyMachineFetch.ml
tiny-mkfs|-|$T/TinyKernel/steps/t6/TinyMkfs.ml
mkfont|-I lib_graphics/core -I lib_graphics/geometry -I lib_graphics/fonts -I lib_graphics/software|$T/TinyKernel/fonts/Mkfont.ml
EOF
}
W=$(mktemp -d); trap 'rm -rf $W' EXIT
# (the programs at once, the analyses first: seconds, not a minute)
programs | { while IFS='|' read -r name flags files; do
  [ "$flags" = - ] && flags=
  timeout 300 $ANALYZE $flag $flags $files > $W/$name.out 2>&1 &
done; wait; }
programs | while IFS='|' read -r name flags files; do
  n=$(grep -cE "$said" $W/$name.out)
  # (a unit not read: its program's 0 would say nothing)
  unread=$(grep -cE 'unbound module|not read' $W/$name.out)
  [ -z "$check" ] && printf '%-20s %3d%s\n' $name $n "$([ $unread -gt 0 ] && echo "  NOT READ: $(grep -m1 -E 'unbound module|not read' $W/$name.out)")"
  [ $unread -gt 0 ] && echo "$name NOT READ" >> $W/unread
  grep -E "$said" $W/$name.out | sed 's/^bug? //; s|^|'$name'\t|' >> $W/said
  for x in $files; do printf '%s\t%s\n' $name $x; done >> $W/has
done
if [ $flag = -dead ]; then
  # (kept where every program that has the file says it)
  awk -F'\t' 'NR == FNR { has[$2]++; next }
    { split($2, p, ":"); key = $2; sub(/:[0-9]+:/, ":", key)
      n[key]++; line[key] = $2; file[key] = p[1] }
    END { for (k in n) if (n[k] >= has[file[k]]) print line[k] }' \
    $W/has $W/said | sort -u > $out
else
  cut -f2- $W/said 2> /dev/null | sort -u > $out
fi
[ -s $W/unread ] && { cat $W/unread; }
if [ -z "$check" ]; then echo "$(wc -l < $out) reports: $out"; exit 0; fi
# (a program not read: a failure, all tiny/'s programs readable here)
[ -s $W/unread ] && { echo "FAIL mini-analyze $flag on tiny/'s host programs: not all read"; rm -f $out; exit 1; }
. analyzers/datalog/tests/compare.sh
compare "mini-analyze $flag on tiny/'s host programs" $out $expected /dev/null
st=$?; rm -f $out; exit $st
