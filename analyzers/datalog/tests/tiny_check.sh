#!/usr/bin/env bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-analyze FLAG on tiny/'s programs: the host's, those OCaml builds and
# checks (tiny/dune's executables: Cap.main or TinyLibSystem.main), and
# those tiny-kernel runs alone (windows, www, trace, debug, ...: OCaml only
# checks their units, no program on the host), each given by its main
# file alone, the analyzer reading the units it names (-own: tiny/'s
# directories, their units reported on as the program's), on the host's
# TinyLibSystem.ml,
# the same .mli as tiny-kernel's (whose functions only tiny-kernel's
# builds of rc, ed, ml... would keep from being said dead, and whose
# externals' capabilities mini-analyze does not know), since TinyLibSystem
# is the one library of both systems' programs (old: left out,
# TinyCalls.ml their calls). lib_core's units are found by the
# analyzer itself, the other ix libraries' by -I. Not here: the SDL
# programs (tsdl, which mini-analyze does not read: tiny-machine-window,
# tiny/user/sdl/'s apps) and the kernel (its calls are the machine's,
# not a library's).
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
T=tiny
# The directories of tiny/'s units (-own): the analyzer reads the units a
# program names from there, and reports on them as on the program's own
# files. The host's TinyLibSystem first, so that it is the one found.
# TinyML/ and TinyC/ have units of the same names (Lexer, Types...), so
# each is given only to its own program.
O="-own $T/TinyLibSystem/unix -own $T"
M="-own $T/TinyMachine"
NET="-I lib_networking/tcp -I lib_networking/tls -I lib_networking/http"
NET="$NET -I lib_crypto -I lib_compression"
# a program a line: its name, its flags, its main file
programs() {
  cat <<EOF
tiny-build|$O -I lib_crypto|$T/TinyBuildSystem.ml
tiny-shell|$O|$T/TinyShell.ml
tiny-editor|$O|$T/TinyEditorLine.ml
tiny-utils|$O|$T/TinyUtilities.ml
tiny-cc|$O -own $T/TinyC|$T/TinyC.ml
tiny-db|$O|$T/TinyDatabase.ml
tiny-vcs|$O -I lib_crypto|$T/TinyVCS.ml
tiny-as|$O|$T/TinyAssembler.ml
tiny-ld|$O|$T/TinyLinker.ml
tiny-ar|$O|$T/TinyArchiver.ml
tiny-cpu|$O $M|$T/TinyCPU.ml
tiny-prof|$O|$T/TinyProfiler.ml
tiny-ml|$O -own $T/TinyML|$T/TinyML.ml
tiny-machine|$O $M -own $T/TinyKernel -own $T/TinyBrowser -I lib_core/parallel|$T/TinyMachine.ml
tiny-machine-socket|$O $M|$T/TinyMachine/TinyMachineSocket.ml
tiny-machine-fetch|$O $M $NET -I lib_graphics/core -I lib_graphics/images|$T/TinyMachine/TinyMachineFetch.ml
tiny-mkfat|$O|$T/TinyKernel/steps/t6/TinyMkfat.ml
mkfont|$O -I lib_graphics/core -I lib_graphics/geometry -I lib_graphics/fonts -I lib_graphics/software|$T/TinyKernel/fonts/Mkfont.ml
windows|$O|$T/user/windows.ml
bigmem|$O|$T/user/bigmem.ml
square|$O|$T/user/square.ml
tetris|$O|$T/user/tetris.ml
calc|$O|$T/user/calc.ml
temp|$O|$T/user/temp.ml
emacs|$O|$T/user/emacs.ml
office|$O -own $T/TinyOffice|$T/user/office.ml
troff|$O -own $T/TinyOffice|$T/user/troff.ml
play|$O|$T/user/play.ml
www|$O -own $T/TinyBrowser|$T/user/www.ml
trace|$O|$T/user/trace.ml
debug|$O|$T/user/debug.ml
EOF
}
W=$(mktemp -d); trap 'rm -rf $W' EXIT
. analyzers/datalog/tests/compare.sh
notes=$(notes_of $expected)
# (the programs at once, the analyses first: seconds, not a minute)
# (-v: the files each program reads as its own, its "reading" lines, for
# -dead's "every program that has the file"; the rest of -v left out)
programs | { while IFS='|' read -r name flags files; do
  timeout 300 $ANALYZE -v $flag $flags $files > $W/$name.v 2>&1 &
done; wait; }
programs | while IFS='|' read -r name flags files; do
  grep -v '^mini-analyze: \[INFO\]' $W/$name.v > $W/$name.out
  files=$(sed -n 's/^mini-analyze: \[INFO\] reading \(.*\.ml\)$/\1/p' $W/$name.v)
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
