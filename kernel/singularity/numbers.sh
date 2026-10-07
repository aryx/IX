#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The paper's table 1, here (docs/plans/plan_system_singularity.md,
# "What is checked"): what a call to the kernel, a yield, a message
# there and back and a process made and ended cost in mini-singularity,
# in the guest's instructions. programs/bench measures each in the
# board's microseconds; mini-qemu runs a fixed number of instructions a
# microsecond (its -ips, 30), so under it the microseconds are
# instructions, the same at every run.
# usage: kernel/singularity/numbers.sh      (the images built: mini-mk, mini-mk O=5)
cd "$(dirname "$0")"
M=../../_build/default/raspberry/Main.exe
IPS=30
run() {
  tests/session.py --until 'no process left.' --timeout 300 --out /dev/stdout -- "$@" -nographic 2> /dev/null | tr -d '\r' |
    awk -v ips=$IPS '$1 == "bench:" { printf " %12d", $4 * ips / $3 } END { print "" }'
}
printf "%-6s %12s %12s %12s %12s\n" board call yield message process
printf "%-6s" pi1; run $M -M raspi1ap -device loader,file=../../_mk/5/kernel/singularity/kernel.img,addr=0x8000,cpu-num=0,force-raw=on
printf "%-6s" pi4; run $M -cpu cortex-a72 -M raspi4b -m 2G -kernel ../../_mk/7/kernel/singularity/kernel8.img
