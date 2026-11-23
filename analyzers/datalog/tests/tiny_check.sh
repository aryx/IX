#!/usr/bin/env bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-analyze FLAG on tiny/'s programs, each read as each system builds
# it: on tiny-kernel, by tiny-ml on TinyLibCore and tiny-kernel's
# TinyLibSystem (the Buildfile's programs); on the host, by OCaml on
# lib_core and the host's TinyLibSystem (tiny/dune's tools, the windows'
# programs of user/sdl/, tiny-machine...). A program is given by its main
# file alone, the analyzer reading the units it names (-own: tiny/'s
# directories, their units reported on as the program's); lib_core's
# units it finds by itself, the other ix libraries' by -I. -caps reads
# each on the host alone: the analyzer does not know tiny-kernel's calls'
# capabilities yet. Not here: the SDL library (tsdl, which mini-analyze
# does not read: tiny-machine-window, user/sdl/'s own TinyLibSystem,
# stood for by the host's, whose code it includes), js_of_ocaml
# (tiny-machine-web) and the kernel (its calls are the machine's, not a
# library's).
# Each report once, sorted, recorded: -caps caps_tiny.txt (its one line
# TinyBuildSystem.start's, analyzers/datalog/README.md), -bugs
# bugs_tiny.txt, -dead dead_tiny.txt (what every build that has the
# file says dead: TinyLibSystem's functions one program does not call are
# not dead), -exn exn_tiny.txt (a build's toplevel exceptions, a tool's
# two builds each named, the host's name-host, but lib_core's every
# program may raise). -check (make test's): the answer against the recording,
# without line numbers (an edit above a function moves it). With no
# out-file, the reports on the standard output. Seconds.
# usage: analyzers/datalog/tests/tiny_check.sh -caps|-dead|-bugs|-exn [out-file|-check]
#   (dune build first)
# ANALYZE: the program, if not dune's.
cd "$(dirname "$0")/../../.."
ANALYZE=${ANALYZE:-_build/default/analyzers/Main.exe}
export LC_ALL=C
# (no analyzer, being rebuilt say: every program would say nothing)
[ -x "${ANALYZE%% *}" ] || { echo "no analyzer: $ANALYZE"; exit 2; }
flag=$1; out=$2; check=; show=
case $flag in
  -caps) expected=caps_tiny.txt; said=': (no capability|has <|names .* itself)';;
  -bugs) expected=bugs_tiny.txt; said='^bug\? ';;
  -dead) expected=dead_tiny.txt; said=': dead( [a-z]+)?:';;
  -exn) expected=exn_tiny.txt; said='the toplevel may let ';;
  *) echo "usage: tiny_check.sh -caps|-dead|-bugs|-exn [out-file|-check]"; exit 2;;
esac
expected=analyzers/datalog/tests/$expected
if [ "$out" = -check ]; then check=1; out=$(mktemp); fi
if [ -z "$out" ]; then show=1; out=$(mktemp); fi
T=tiny
# How each program is read. On the host (O), as OCaml builds it, on
# lib_core and the host's TinyLibSystem: the directories of tiny/'s
# units are -own (the analyzer reads the units a program names from
# there, and reports on them as on the program's own files), the host's
# TinyLibSystem first so that it is the one found. On tiny-kernel (K), as
# t-IX builds it: on TinyLibCore and tiny-kernel's TinyLibSystem
# (TinyLibCore's Cap.mli names the capabilities TinyLibSystem.mli takes,
# which tiny-ml leaves out). TinyML/ and TinyC/ have units of the same
# names (Lexer, Types...), so each is given only to its own program.
O="-own $T/TinyLibSystem/unix -own $T"
K="-L $T/TinyLibCore -own $T/TinyLibSystem/tinykernel -own $T"
M="-own $T/TinyMachine"
NET="-I lib_networking/tcp -I lib_networking/tls -I lib_networking/http"
NET="$NET -I lib_crypto -I lib_compression"
# a program a line: its name; where it runs: k tiny-kernel alone (the
# Buildfile's windows' programs), h the host alone (tiny-machine...,
# mkfont, built by OCaml on lib_core), b both (the tools: tiny/dune's and
# the Buildfile's; and the windows' programs of user/sdl/dune, whose
# TinyLibSystem includes the host's, read here for it: the analyzer does
# not read tsdl); its flags beside O's or K's; its main file
programs() {
  cat <<EOF
tiny-build|b|-I lib_crypto|$T/TinyBuildSystem.ml
tiny-shell|b||$T/TinyShell.ml
tiny-editor|b||$T/TinyEditorLine.ml
tiny-utils|b||$T/TinyUtilities.ml
tiny-cc|b|-own $T/TinyC|$T/TinyC.ml
tiny-db|b||$T/TinyDatabase.ml
tiny-vcs|b|-I lib_crypto|$T/TinyVCS.ml
tiny-as|b||$T/TinyAssembler.ml
tiny-ld|b||$T/TinyLinker.ml
tiny-ar|b||$T/TinyArchiver.ml
tiny-cpu|h|$M|$T/TinyCPU.ml
tiny-prof|b||$T/TinyProfiler.ml
tiny-ml|b|-own $T/TinyML|$T/TinyML.ml
tiny-machine|h|$M -own $T/TinyKernel -own $T/TinyBrowser -I lib_core/parallel|$T/TinyMachine.ml
tiny-machine-socket|h|$M|$T/TinyMachine/TinyMachineSocket.ml
tiny-machine-fetch|h|$M $NET -I lib_graphics/core -I lib_graphics/images|$T/TinyMachine/TinyMachineFetch.ml
tiny-mkfat|h||$T/TinyKernel/steps/t6/TinyMkfat.ml
tiny-mkfs|h|$M -I $T/TinyKernel/host -I $T/TinyKernel|$T/TinyKernel/host/TinyMkfs.ml
mkfont|h|-I lib_graphics/core -I lib_graphics/geometry -I lib_graphics/fonts -I lib_graphics/software|$T/TinyKernel/fonts/Mkfont.ml
windows|k||$T/user/windows.ml
bigmem|k||$T/user/bigmem.ml
square|k||$T/user/square.ml
tetris|b||$T/user/tetris.ml
orrery|b||$T/user/orrery.ml
calc|b||$T/user/calc.ml
temp|k||$T/user/temp.ml
emacs|b||$T/user/emacs.ml
office|b|-own $T/TinyOffice|$T/user/office.ml
troff|b|-own $T/TinyOffice|$T/user/troff.ml
play|b||$T/user/play.ml
www|b|-own $T/TinyBrowser|$T/user/www.ml
trace|k||$T/user/trace.ml
debug|k||$T/user/debug.ml
EOF
}
# a run a line: its name, its flags, its main file. A tool runs on both
# systems, read both ways (its host's run named -host): a function is
# dead only if every build that has its file says so. -caps: each on the
# host, whose externals' capabilities the analyzer knows (tiny-kernel's
# calls not yet).
runs() {
  programs | while IFS='|' read -r name sys flags main; do
    if [ $flag = -caps ]; then echo "$name|$O $flags|$main"; continue; fi
    case $sys in
      k) echo "$name|$K $flags|$main";;
      h) echo "$name|$O $flags|$main";;
      b) echo "$name|$K $flags|$main"; echo "$name-host|$O $flags|$main";;
    esac
  done
}
W=$(mktemp -d); trap 'rm -rf $W' EXIT
. analyzers/datalog/tests/compare.sh
notes=$(notes_of $expected)
# (the programs at once, the analyses first: seconds, not a minute)
# (-v: the files each program reads as its own, its "reading" lines, for
# -dead's "every program that has the file"; the rest of -v left out)
runs | { while IFS='|' read -r name flags files; do
  timeout 300 $ANALYZE -v $flag $flags $files > $W/$name.v 2>&1 &
done; wait; }
# (a unit not read, or the analyzer stopped: its program's 0 would say
# nothing)
failed='unbound (module|value|type)|not read|syntax error|Fatal error'
runs | while IFS='|' read -r name flags files; do
  grep -v '^mini-analyze: \[INFO\]' $W/$name.v > $W/$name.out
  files=$(sed -n 's/^mini-analyze: \[INFO\] reading \(.*\.ml\)$/\1/p' $W/$name.v)
  n=$(grep -cE "$said" $W/$name.out)
  unread=$(grep -cE "$failed" $W/$name.out)
  [ -z "$check$show" ] && printf '%-20s %3d%s\n' $name $n "$([ $unread -gt 0 ] && echo "  NOT READ: $(grep -m1 -E "$failed" $W/$name.out)")"
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
if [ -n "$show" ]; then cat $out; rm -f $out; exit 0; fi
if [ -z "$check" ]; then
  keep_notes "$notes" $out; echo "$(grep -vc '^#' $out) reports: $out"; exit 0
fi
# (a program not read: a failure, all tiny/'s programs readable here)
[ -s $W/unread ] && { echo "FAIL mini-analyze $flag on tiny/'s programs: not all read"; rm -f $out; exit 1; }
compare "mini-analyze $flag on tiny/'s programs" $out $expected /dev/null
st=$?; rm -f $out; exit $st
