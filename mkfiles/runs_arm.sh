#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# Does this machine run an arm (32-bit) program as any program? An
# arm64 processor may (most do, not all: GitHub's runners are of both
# kinds), and any machine does with qemu-arm registered (binfmt_misc).
# Asked by trying: a program of three instructions that exits 42, made
# here by mini-asm and mini-ld. Its status says: 0 for yes.
# usage: mkfiles/runs_arm.sh     (after dune build)
ROOT=$(cd "$(dirname "$0")/.." && pwd)
W=$(mktemp -d); trap 'rm -rf $W' EXIT
$ROOT/bin/mini-asm -m 5 -o $W/exit.5 $ROOT/linker/tests/golden/exit_linux_arm.s &&
  $ROOT/bin/mini-ld -m 5 -H7 -E _start -o $W/exit $W/exit.5 || exit 2
$W/exit 2> /dev/null
[ $? = 42 ]
