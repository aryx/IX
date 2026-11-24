#!/usr/bin/env bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-analyze FLAG on tiny/'s programs, each read as each system builds
# it: on tiny-kernel, by tiny-ml on TinyLibCore and tiny-kernel's
# TinyLibSystem (the Buildfile's programs); on the host, by OCaml on
# lib_core and the host's TinyLibSystem (tiny/dune's tools, the windows'
# programs of user/sdl/, tiny-machine...). A program is given by its
# build's manifest, made here: on tiny-kernel, tiny-ld's (-map's) of
# t-IX's build; on the host, Dune_manifest's of dune's link (dune
# describe and dune rules): its files as linked, its platform's among
# them, nothing told. Ten host runs are given by their main file and
# flags, the old way (the analyzer finds the units it names in the
# project, Unit_finder, lib_core's by itself, an -I's read and not
# reported on), their manifest's link being what the analyzer cannot
# read: the 8 SDL windows' programs (tsdl), tiny-machine (dune's OCaml 5
# links lib_core's Parallel on Domain), tiny-mkfs (its KRaw, host/, is
# the SDL windows' memory too, whose uses are not read: its -I keeps it
# a library, not reported on). -caps reads each on the host alone: the
# analyzer does not know tiny-kernel's calls' capabilities yet. Not here: the SDL library (tsdl, which mini-analyze
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
DUNE_MANIFEST=${DUNE_MANIFEST:-_build/default/analyzers/manifest/Main.exe}
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
# How a program given by its main file is read on the host: its
# platform, the one choice the analyzer cannot make from a main file
# (TinyLibSystem's implementations have the same names), as OCaml builds
# it, on lib_core and the host's TinyLibSystem (O). A manifest says it:
# TinyLibCore's members of stdlib.a and tiny-kernel's TinyLibSystem;
# lib_core and TinyLibSystem/unix in dune's link. (old, before the
# manifests: K="-L $T/TinyLibCore -own $T/TinyLibSystem/tinykernel" and
# each main file; the host's -I's, lib_crypto's, lib_networking's...)
O="-L lib_core -own $T/TinyLibSystem/unix"
# a program a line: its name; where it runs: k tiny-kernel alone (the
# Buildfile's windows' programs), h the host alone (tiny-machine...,
# mkfont, built by OCaml on lib_core), b both (the tools: tiny/dune's and
# the Buildfile's; and the windows' programs of user/sdl/dune, whose
# TinyLibSystem includes the host's, read here for it: the analyzer does
# not read tsdl); its name in the Buildfile (its manifest's); its main
# file; on the host, dune (dune's manifest of the main's .exe) or the
# flags beside O's of the old way, above
programs() {
  cat <<EOF
tiny-build|b|build|$T/TinyBuildSystem.ml|dune
tiny-shell|b|rc|$T/TinyShell.ml|dune
tiny-editor|b|ed|$T/TinyEditorLine.ml|dune
tiny-utils|b|utils|$T/TinyUtilities.ml|dune
tiny-cc|b|cc|$T/TinyC/TinyC.ml|dune
tiny-db|b|db|$T/TinyDatabase.ml|dune
tiny-vcs|b|vcs|$T/TinyVCS.ml|dune
tiny-as|b|as|$T/TinyAssembler.ml|dune
tiny-ld|b|ld|$T/TinyLinker.ml|dune
tiny-ar|b|ar|$T/TinyArchiver.ml|dune
tiny-cpu|h||$T/TinyCPU.ml|dune
tiny-prof|b|prof|$T/TinyProfiler.ml|dune
tiny-ml|b|ml|$T/TinyML/TinyML.ml|dune
tiny-machine|h||$T/TinyMachine/TinyMachine.ml|-I lib_core/parallel
tiny-machine-socket|h||$T/TinyMachine/TinyMachineSocket.ml|dune
tiny-machine-fetch|h||$T/TinyMachine/TinyMachineFetch.ml|dune
tiny-mkfat|h||$T/TinyKernel/steps/t6/TinyMkfat.ml|dune
tiny-mkfs|h||$T/TinyKernel/host/TinyMkfs.ml|-I $T/TinyKernel/host -I $T/TinyKernel
mkfont|h||$T/TinyKernel/fonts/Mkfont.ml|dune
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
    # (the host's: dune's manifest of its link, or the main file and O)
    if [ "$host" = dune ]; then
      hostrun="$name|-sources .|$W/dune/${main%.ml}.exe.manifest"
    else
      hostrun="$name|$O $host|$main"
    fi
    if [ $flag = -caps ]; then echo "$hostrun"; continue; fi
    # (tiny-kernel's: tiny-ld's manifest of the build below, its paths
    # read in tiny/, where the build's copy of tiny/ came from)
    if [ -n "$tix" ]; then
      d=$(dirname $tix); src=$T; [ $d = . ] || src=$T/$d
      tixrun="$name|-sources $src|$W/tix/src/$tix.manifest"
    fi
    case $sys in
      k) echo "$tixrun";;
      h) echo "$hostrun";;
      b) echo "$tixrun"; echo "${hostrun/#$name|/$name-host|}";;
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
# (the host's programs as dune links them: its modules' sources and each
# link, in a build directory of its own, not _build's, which another
# dune may hold; Dune_manifest makes their manifests, seconds)
exes=$(programs |
  awk -F'|' '$5 == "dune" { sub(/\.ml$/, ".exe", $4); print "./" $4 }')
{ dune describe workspace --build-dir $W/dune-build > $W/describe.sexp &&
  dune rules --build-dir $W/dune-build $exes > $W/rules.sexp &&
  $DUNE_MANIFEST $W/describe.sexp $W/rules.sexp $W/dune; } > $W/dune.log 2>&1 ||
  { tail -5 $W/dune.log; echo "tiny_check.sh: dune's manifests failed"; exit 2; }
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
