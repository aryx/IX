#!/usr/bin/env bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-analyze FLAG on tiny/'s programs, each read as each system builds
# it: on tiny-kernel, by tiny-ml on TinyLibCore and tiny-kernel's
# TinyLibSystem (the Buildfile's programs); on the host, by OCaml on
# lib_core and the host's TinyLibSystem (tiny/dune's tools, the windows'
# programs of user/sdl/, tiny-machine...). On tiny-kernel, a program is
# given by tiny-ld's manifest (-map's) of t-IX's build, made here: its
# files as linked, its platform's among them. On the host, by its main
# file alone: the analyzer finds the units it names in the project
# (Unit_finder), its own, and lib_core's by itself; the other ix
# libraries' are given by -I, read and not reported on. -caps reads
# each on the host alone: the analyzer does not know tiny-kernel's calls'
# capabilities yet. Not here: the SDL library (tsdl, which mini-analyze
# does not read: tiny-machine-window, user/sdl/'s own TinyLibSystem,
# stood for by the host's, whose code it includes), js_of_ocaml
# (tiny-machine-web). The kernel is read as a program of tiny-kernel,
# which it is, on TinyLibCore (TinyLibSystem, which it does not name, is
# not read): it shares KNetwork.ml with tiny-machine, and without it a
# function only the kernel calls would be said dead.
# Each report once, sorted, recorded: -caps caps_tiny.txt (its one line
# TinyBuildSystem.start's, analyzers/datalog/README.md), -bugs
# bugs_tiny.txt, -dead dead_tiny.txt (what every build that has the
# file says dead, TinyLibSystem's implementations one file: its functions
# one program does not call are not dead), -exn exn_tiny.txt (a build's toplevel exceptions, a tool's
# two builds each named, the host's name-host, but lib_core's every
# program may raise). -check (make test's): the answer against the recording,
# without line numbers (an edit above a function moves it). With no
# out-file, the reports on the standard output. Seconds.
# usage: analyzers/datalog/tests/tiny_check.sh -caps|-dead|-bugs|-exn [out-file|-check]
#   (dune build first)
# ANALYZE, DATALOG: the programs, if not dune's.
cd "$(dirname "$0")/../../.."
ANALYZE=${ANALYZE:-_build/default/analyzers/Main.exe}
DATALOG=${DATALOG:-_build/default/languages/datalog/Main.exe}
export LC_ALL=C
# (no analyzer, being rebuilt say: every program would say nothing)
[ -x "${ANALYZE%% *}" ] || { echo "no analyzer: $ANALYZE"; exit 2; }
flag=$1; out=$2; check=; show=
case $flag in
  -caps) expected=caps_tiny.txt; said=': (no capability|has <|names .* itself)';;
  -bugs) expected=bugs_tiny.txt; said='^bug\? ';;
  -dead) expected=dead_tiny.txt; said=': (dead( [a-z]+)?|never built):';;
  -exn) expected=exn_tiny.txt; said='the toplevel may let ';;
  *) echo "usage: tiny_check.sh -caps|-dead|-bugs|-exn [out-file|-check]"; exit 2;;
esac
expected=analyzers/datalog/tests/$expected
if [ "$out" = -check ]; then check=1; out=$(mktemp); fi
if [ -z "$out" ]; then show=1; out=$(mktemp); fi
T=tiny
# How each program is read on the host: its platform, the one choice
# the analyzer cannot make from a main file (TinyLibSystem's
# implementations have the same names), as OCaml builds it, on lib_core
# and the host's TinyLibSystem (O). On tiny-kernel, the manifest says it:
# TinyLibCore's members of stdlib.a and tiny-kernel's TinyLibSystem.
# (old: K="-L $T/TinyLibCore -own $T/TinyLibSystem/tinykernel" and the
# main file, before tiny-ld's manifests)
O="-L lib_core -own $T/TinyLibSystem/unix"
NET="-I lib_networking/tcp -I lib_networking/tls -I lib_networking/http"
NET="$NET -I lib_crypto -I lib_compression"
# a program a line: its name; where it runs: k tiny-kernel alone (the
# Buildfile's windows' programs), h the host alone (tiny-machine...,
# mkfont, built by OCaml on lib_core), b both (the tools: tiny/dune's and
# the Buildfile's; and the windows' programs of user/sdl/dune, whose
# TinyLibSystem includes the host's, read here for it: the analyzer does
# not read tsdl); its name in the Buildfile (its manifest's); its main
# file; its flags on the host. One is given (-I) only to what the host
# builds, as tiny/dune links it (tiny-build's and tiny-vcs's Sha1 is
# lib_crypto's there, TinyLibCore's on tiny-kernel, the runtime's C)
programs() {
  cat <<EOF
tiny-build|b|build|$T/TinyBuildSystem.ml|-I lib_crypto
tiny-shell|b|rc|$T/TinyShell.ml
tiny-editor|b|ed|$T/TinyEditorLine.ml
tiny-utils|b|utils|$T/TinyUtilities.ml
tiny-cc|b|cc|$T/TinyC/TinyC.ml
tiny-db|b|db|$T/TinyDatabase.ml
tiny-vcs|b|vcs|$T/TinyVCS.ml|-I lib_crypto
tiny-as|b|as|$T/TinyAssembler.ml
tiny-ld|b|ld|$T/TinyLinker.ml
tiny-ar|b|ar|$T/TinyArchiver.ml
tiny-cpu|h||$T/TinyCPU.ml
tiny-prof|b|prof|$T/TinyProfiler.ml
tiny-ml|b|ml|$T/TinyML/TinyML.ml
tiny-machine|h||$T/TinyMachine/TinyMachine.ml|-I lib_core/parallel
tiny-machine-socket|h||$T/TinyMachine/TinyMachineSocket.ml
tiny-machine-fetch|h||$T/TinyMachine/TinyMachineFetch.ml|$NET -I lib_graphics/core -I lib_graphics/images
tiny-mkfat|h||$T/TinyKernel/steps/t6/TinyMkfat.ml
tiny-mkfs|h||$T/TinyKernel/host/TinyMkfs.ml|-I $T/TinyKernel/host -I $T/TinyKernel
mkfont|h||$T/TinyKernel/fonts/Mkfont.ml|-I lib_graphics/core -I lib_graphics/geometry -I lib_graphics/fonts -I lib_graphics/software
windows|k|windows|$T/user/windows.ml
bigmem|k|bigmem|$T/user/bigmem.ml
square|k|square|$T/user/square.ml
tetris|b|tetris|$T/user/tetris.ml
orrery|b|orrery|$T/user/orrery.ml
calc|b|calc|$T/user/calc.ml
temp|k|temp|$T/user/temp.ml
emacs|b|emacs|$T/user/emacs.ml
office|b|office|$T/user/office.ml
troff|b|troff|$T/user/troff.ml
play|b|play|$T/user/play.ml
www|b|www|$T/user/www.ml
trace|k|trace|$T/user/trace.ml
debug|k|debug|$T/user/debug.ml
tiny-kernel|k|TinyKernel/kernel.img|$T/TinyKernel/TinyKernel.ml
EOF
}
# a run a line: its name, its flags, its main file. A tool runs on both
# systems, read both ways (its host's run named -host): a function is
# dead only if every build that has its file says so. -caps: each on the
# host, whose externals' capabilities the analyzer knows (tiny-kernel's
# calls not yet).
runs() {
  programs | while IFS='|' read -r name sys tix main host; do
    if [ $flag = -caps ]; then echo "$name|$O $host|$main"; continue; fi
    # (tiny-kernel's: tiny-ld's manifest of the build below, its paths
    # read in tiny/, where the build's copy of tiny/ came from)
    if [ -n "$tix" ]; then
      d=$(dirname $tix); src=$T; [ $d = . ] || src=$T/$d
      tixrun="$name|-sources $src|$W/tix/src/$tix.manifest"
    fi
    case $sys in
      k) echo "$tixrun";;
      h) echo "$name|$O $host|$main";;
      b) echo "$tixrun"; echo "$name-host|$O $host|$main";;
    esac
  done
}
W=$(mktemp -d); trap 'rm -rf $W' EXIT
# (t-IX built as tiny-kernel builds it, TinyKernel/Makefile's build of the
# Buildfile in a copy of tiny/: each program's manifest, seconds)
if [ $flag != -caps ]; then
  make -s -C $T/TinyKernel O=$W/tix $W/tix/disk.img > $W/tix.log 2>&1 ||
    { tail -5 $W/tix.log; echo "tiny_check.sh: t-IX's build failed"; exit 2; }
fi
. analyzers/datalog/tests/compare.sh
notes=$(notes_of $expected)
# (the programs at once, the analyses first: seconds, not a minute)
# (-dead: each program's files and reports as facts, merged below)
runs | { while IFS='|' read -r name flags files; do
  summary=; [ $flag = -dead ] && summary="-summary $W/$name.dl -program $name"
  timeout 300 $ANALYZE $flag $summary $flags $files > $W/$name.out 2>&1 &
done; wait; }
# (a unit not read, or the analyzer stopped: its program's 0 would say
# nothing)
failed='unbound (module|value|type)|not read|syntax error|Fatal error'
runs | while IFS='|' read -r name flags files; do
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
done
if [ $flag = -dead ]; then
  # (kept where every program that has the file, or another
  # implementation of its interface, says it: dead_all.dl's)
  # (its warnings, a relation with no fact, said only if it fails)
  $DATALOG analyzers/datalog/dead_all.dl $W/*.dl 2> $W/datalog.err > $W/dead_all ||
    { cat $W/datalog.err; exit 2; }
  dead_lines < $W/dead_all | sort -u > $out
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
