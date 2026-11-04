#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-analyze -caps on tiny/'s host programs, those OCaml builds and
# checks (tiny/dune's executables: Cap.main or TinyLibSystem.main), each
# with the modules of its tiny libraries, lib_core's found by itself, the
# other ix libraries by -I. Not here: the SDL programs (tsdl, which
# mini-analyze does not read: tiny-machine-window, tiny/sdl/'s apps) and
# what runs on tiny-kernel (its system is tiny's kernel, TinyCalls).
# Each function reported once, sorted: caps_tiny.txt. Seconds. -check
# (make test's): the answer against caps_tiny.txt, its one line
# TinyBuildSystem.start's (analyzers/datalog/README.md).
# usage: analyzers/datalog/tests/tiny_caps.sh out-file | -check
#   (dune build first)
# ANALYZE: the program, if not dune's.
cd "$(dirname "$0")/../../.."
ANALYZE=${ANALYZE:-_build/default/analyzers/Main.exe}
export LC_ALL=C
out=$1; check=
if [ "$1" = -check ]; then check=1; out=$(mktemp); fi
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
programs | while IFS='|' read -r name flags files; do
  [ "$flags" = - ] && flags=
  timeout 300 $ANALYZE -caps $flags $files > $W/$name.out 2>&1
  n=$(grep -cE ': (no capability|has <)' $W/$name.out)
  # (a unit not read: its program's 0 would say nothing)
  unread=$(grep -cE 'unbound module|not read' $W/$name.out)
  printf '%-20s %3d%s\n' $name $n "$([ $unread -gt 0 ] && echo "  NOT READ: $(grep -m1 -E 'unbound module|not read' $W/$name.out)")"
  grep -E ': (no capability|has <)' $W/$name.out >> $W/all
done
sort -u $W/all > $out 2> /dev/null || : > $out
if [ -z "$check" ]; then echo "$(wc -l < $out) functions: $out"; exit 0; fi
expected=analyzers/datalog/tests/caps_tiny.txt
# (without the line numbers: an edit above a function moves it)
bare() { sed -E 's/^([^:]*):[0-9]+:/\1:/' $1 | sort; }
if cmp -s <(bare $out) <(bare $expected); then
  echo "ok tiny's host programs: -caps as recorded ($(wc -l < $out) function)"
  rm -f $out
else
  echo "FAIL tiny's host programs: -caps not as recorded (< recorded, > now)"
  diff <(bare $expected) <(bare $out) | head -10; rm -f $out; exit 1
fi
