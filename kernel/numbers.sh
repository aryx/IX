#!/bin/bash
# Claude Code
#
# Copyright (C) 2026 Yoann Padioleau
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Library General Public License
# (LGPL) as published by the Free Software Foundation; either version
# 2 of the License, or (at your option) any later version.
#
# The numbers of a mini-xv6 image on the Pi 4, for the two builds to
# compare (plan_kernel_mini_ml.md, step 7) and for the optimizations to
# move (docs/plans/plan_mini_toolchain_optimization.md): its size, and under mini-qemu
# the seconds to sh's prompt and an ls, and those of the check's
# session (ls, cat, mkdir, ln, wc, rm, grep, forktest). mini-qemu runs
# a fixed number of instructions a second, so the seconds are the
# guest's instructions.
# usage: kernel/numbers.sh [name=image]...
#   (default: gcc=xv6/kernel-pi4.elf ix=../_mk/7/kernel/xv6/kernel8.img)
cd "$(dirname "$0")"
M=../_build/default/raspberry/Main.exe
[ $# = 0 ] && set -- gcc=xv6/kernel-pi4.elf ix=../_mk/7/kernel/xv6/kernel8.img
printf "%-12s %10s %8s %9s\n" build bytes "to ls" session
for a in "$@"; do
  name=${a%%=*}; image=${a#*=}
  boot="$M -cpu cortex-a72 -M raspi4b -kernel $image -m 2G -nographic"
  t0=$(date +%s.%N)
  lib/session.py --timeout 300 --out /dev/null ls -- $boot > /dev/null
  t1=$(date +%s.%N)
  lib/session.py --timeout 600 --out /dev/null ls "cat README" "echo hello world" "mkdir d" "ls d" "ln README d/r" "ls d" "wc d/r" "rm d/r" "grep xv6 README" forktest "cat nosuch" "sh -c" -- $boot > /dev/null
  t2=$(date +%s.%N)
  printf "%-12s %10d %8.1f %9.1f\n" $name $(stat -c %s $image) $(echo "$t1 - $t0" | bc) $(echo "$t2 - $t1" | bc)
done
