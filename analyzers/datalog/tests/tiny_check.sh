#!/usr/bin/env bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-analyze FLAG on tiny/'s programs: the host's, those OCaml builds and
# checks (tiny/dune's executables: Cap.main or TinyLibSystem.main), and
# those tiny-kernel runs alone (windows, www, trace, debug, ...: OCaml only
# checks their units, no program on the host), each with the units
# TinyKernel/Makefile's UNITS_x gives it, on the host's TinyLibSystem.ml,
# the same .mli as tiny-kernel's (whose functions only tiny-kernel's
# builds of rc, ed, ml... would keep from being said dead, and whose
# externals' capabilities mini-analyze does not know), since TinyLibSystem
# is the one library of both systems' programs (old: left out,
# TinyCalls.ml their calls). Each with
# the modules of its tiny libraries, lib_core's found by itself, the
# other ix libraries by -I. Not here: the SDL programs (tsdl, which
# mini-analyze does not read: tiny-machine-window, tiny/user/sdl/'s apps)
# and the kernel (its calls are the machine's, not a library's).
# coupling: TinyKernel/Makefile's UNITS_x (I_x, F_x) for tiny-kernel's
# programs below.
# Each report once, sorted, recorded: -caps caps_tiny.txt (its one line
# TinyBuildSystem.start's, analyzers/datalog/README.md), -bugs
# bugs_tiny.txt, -dead dead_tiny.txt (what every program that has the
# file says dead: TinyLibSystem's functions one program does not call are
# not dead), -exn exn_tiny.txt (a program's toplevel exceptions, but
# lib_core's every program may raise). -check (make test's): the answer against the recording,
# without line numbers (an edit above a function moves it). Seconds.
# usage: analyzers/datalog/tests/tiny_check.sh -caps|-dead|-bugs|-exn out-file|-check
#   (dune build first)
# ANALYZE: the program, if not dune's.
cd "$(dirname "$0")/../../.."
ANALYZE=${ANALYZE:-_build/default/analyzers/Main.exe}
export LC_ALL=C
# (no analyzer, being rebuilt say: every program would say nothing)
[ -x "${ANALYZE%% *}" ] || { echo "no analyzer: $ANALYZE"; exit 2; }
flag=$1; out=$2; check=
case $flag in
  -caps) expected=caps_tiny.txt; said=': (no capability|has <|names .* itself)';;
  -bugs) expected=bugs_tiny.txt; said='^bug\? ';;
  -dead) expected=dead_tiny.txt; said=': dead( [a-z]+)?:';;
  -exn) expected=exn_tiny.txt; said='the toplevel may let ';;
  *) echo "usage: tiny_check.sh -caps|-dead|-bugs|-exn out-file|-check"; exit 2;;
esac
expected=analyzers/datalog/tests/$expected
if [ "$out" = -check ]; then check=1; out=$(mktemp); fi
T=tiny; S=$T/TinyLibSystem/unix/TinyLibSystem.ml; R=$T/TinyLibRegex.ml
M=$T/TinyMachine
L=$T/TinyLibMachine.ml
CPU="$L $M/TinyMachineCPU.ml"
BROWSER=$(for m in Strings Charset Tokens Lines Html Url Http; do
  printf "%s " $T/TinyBrowser/$m.ml; done)
TML="$L "$(for m in Lexer Tree Formats Parser Types Machine Compile; do
  printf "%s " $T/TinyML/$m.ml; done)
TC="$L "$(for m in Types Lexer Tree Lower Parser Machine; do
  printf "%s " $T/TinyC/TinyC$m.ml; done)
NET="-I lib_networking/tcp -I lib_networking/tls -I lib_networking/http"
NET="$NET -I lib_crypto -I lib_compression"
# tiny-kernel's programs: the Makefile's GUI and OFFICE
GUI="$S $T/TinyLibDraw.ml $T/TinyLibPlayground.ml $T/TinyLibGUI.ml"
OFFICE=$(for m in Model Text Sheet Drawing Paint Chart File; do
  printf "%s " $T/TinyOffice/$m.ml; done)
# a program a line: its name, its -I's (- for none), its files
programs() {
  cat <<EOF
tiny-build|-I lib_crypto|$S $T/TinyBuildSystem.ml
tiny-shell|-|$S $R $T/TinyShell.ml
tiny-editor|-|$S $R $T/TinyEditorLine.ml
tiny-utils|-|$S $R $T/TinyUtilities.ml
tiny-cc|-|$S $TC $T/TinyC.ml
tiny-db|-|$S $T/TinyDatabase.ml
tiny-vcs|-I lib_crypto|$S $T/TinyVCS.ml
tiny-as|-|$L $S $T/TinyAssembler.ml
tiny-ld|-|$L $S $T/TinyLinker.ml
tiny-ar|-|$L $S $T/TinyArchiver.ml
tiny-cpu|-|$CPU $S $T/TinyCPU.ml
tiny-prof|-|$S $L $T/TinyProfiler.ml
tiny-ml|-|$S $TML $T/TinyML.ml
tiny-machine|-I lib_core/parallel|$CPU $S $M/TinyMachineDevices.ml $T/TinyKernel/TinyKernelNetwork.ml $BROWSER $M/TinyMachinePeer.ml $T/TinyMachine.ml
tiny-machine-socket|-|$S $M/TinyMachineSocket.ml
tiny-machine-fetch|$NET -I lib_graphics/core -I lib_graphics/images|$CPU $S $M/TinyMachineDevices.ml $M/TinyMachineFetch.ml
tiny-mkfat|-|$S $T/TinyKernel/steps/t6/TinyMkfat.ml
mkfont|-I lib_graphics/core -I lib_graphics/geometry -I lib_graphics/fonts -I lib_graphics/software|$S $T/TinyKernel/fonts/Mkfont.ml
windows|-|$S $T/TinyLibDraw.ml $T/TinyWindows.ml $T/user/windows.ml
bigmem|-|$S $T/user/bigmem.ml
square|-|$GUI $T/TinyAppSquare.ml $T/user/square.ml
tetris|-|$GUI $T/TinyAppTetris.ml $T/user/tetris.ml
calc|-|$GUI $T/TinyAppCalculator.ml $T/user/calc.ml
temp|-|$GUI $T/TinyAppTemperature.ml $T/user/temp.ml
emacs|-|$GUI $T/TinyEditorScreen.ml $T/user/emacs.ml
office|-|$GUI $OFFICE $T/TinyOffice.ml $T/user/office.ml
troff|-|$GUI $OFFICE $T/TinyTroff.ml $T/user/troff.ml
play|-|$GUI $T/TinyPlay.ml $T/user/play.ml
www|-|$GUI $BROWSER $T/TinyBrowser/Screen.ml $T/TinyBrowser.ml $T/user/www.ml
trace|-|$S $T/TinyTracer.ml $T/user/trace.ml
debug|-|$GUI $L $T/TinyDebugger.ml $T/user/debug.ml
EOF
}
W=$(mktemp -d); trap 'rm -rf $W' EXIT
. analyzers/datalog/tests/compare.sh
notes=$(notes_of $expected)
# (the programs at once, the analyses first: seconds, not a minute)
programs | { while IFS='|' read -r name flags files; do
  [ "$flags" = - ] && flags=
  timeout 300 $ANALYZE $flag $flags $files > $W/$name.out 2>&1 &
done; wait; }
programs | while IFS='|' read -r name flags files; do
  n=$(grep -cE "$said" $W/$name.out)
  # (a unit not read: its program's 0 would say nothing)
  unread=$(grep -cE 'unbound (module|value)|not read|syntax error' $W/$name.out)
  [ -z "$check" ] && printf '%-20s %3d%s\n' $name $n "$([ $unread -gt 0 ] && echo "  NOT READ: $(grep -m1 -E 'unbound (module|value)|not read|syntax error' $W/$name.out)")"
  [ $unread -gt 0 ] && echo "$name NOT READ" >> $W/unread
  if [ $flag = -exn ]; then
    # (a program's name first: its exceptions, not a file's)
    exn_lines < $W/$name.out | sed 's|^|'$name'\t'$name': |' >> $W/said
  else
    grep -E "$said" $W/$name.out | sed 's/^bug? //; s|^|'$name'\t|' >> $W/said
  fi
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
if [ -z "$check" ]; then
  keep_notes "$notes" $out; echo "$(grep -vc '^#' $out) reports: $out"; exit 0
fi
# (a program not read: a failure, all tiny/'s programs readable here)
[ -s $W/unread ] && { echo "FAIL mini-analyze $flag on tiny/'s programs: not all read"; rm -f $out; exit 1; }
compare "mini-analyze $flag on tiny/'s programs" $out $expected /dev/null
st=$?; rm -f $out; exit $st
