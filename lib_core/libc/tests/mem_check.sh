#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mem_check.c on arm and arm64: the C library as lib_core's mkfile builds
# it (memmove and memset: the machine's assembly, LIBC_MEM5 and
# LIBC_MEM7), the test by mini-cc, linked by mini-ld, run under
# qemu-arm and qemu-aarch64 (a machine without one: skipped).
#
#   usage: mem_check.sh
set -u
D=$(cd "$(dirname "$0")" && pwd)
IX=$(cd $D/../../.. && pwd)
W=$(mktemp -d); trap 'rm -rf $W' EXIT
status=0
for o in 5 7; do
  arch=arm; qemu=qemu-arm; [ $o = 7 ] && { arch=arm64; qemu=qemu-aarch64; }
  command -v $qemu > /dev/null || { echo "skip mem_check $arch (no $qemu)"; continue; }
  (cd $IX/lib_core && MKSHELL=mini-rc PATH=$IX/bin:$PATH mini-mk O=$o > /dev/null) || { echo "FAIL mem_check $arch: lib_core"; status=1; continue; }
  I=$IX/lib_core/libc/include
  if $IX/bin/mini-cc -m $o -I$I -I$I/utf -I$I/arch/$arch -D$arch -Dlinux -o $W/t.$o $D/mem_check.c &&
     $IX/bin/mini-ld -m $o -o $W/t$o $W/t.$o $IX/_mk/$o/lib_core/libc.a && $qemu $W/t$o; then
    echo "ok mem_check $arch: memmove and memset against a byte's loop"
  else echo "FAIL mem_check $arch"; status=1; fi
done
exit $status
