#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The numbers behind docs/plans/plan_system_l4.md: the two references
# of a mini-l4, seL4 (its kernel under the GPL 2: read here, nothing of
# it copied in ix) and L4Ka::Pistachio (an L4 of the older kind, BSD),
# their parts and their lines, seL4's system calls, objects, methods,
# manual and tutorials; and what of ix a mini-l4 would stand on.
# usage: kernel/l4/survey.sh [dir]
#   dir: where the three repositories are kept (cloned there when
#   missing, 65 MB; default: $TMPDIR/l4-refs)

cd "$(dirname "$0")"
R=${1:-${TMPDIR:-/tmp}/l4-refs}
get() { [ -d "$R/$1" ] || GIT_TERMINAL_PROMPT=0 git clone -q --depth 1 https://github.com/$2.git "$R/$1" || exit 1; }
get sel4 seL4/seL4; get pistachio l4ka/pistachio; get tutorials seL4/sel4-tutorials
S=$R/sel4
P=$R/pistachio/kernel
lines() { find "$@" -type f \( -name '*.c' -o -name '*.cc' -o -name '*.h' -o -name '*.S' -o -name '*.bf' \) -print0 | xargs -0 cat | wc -l; }
row() { b=$1; shift; for d in "$@"; do printf "%8d %s\n" $(lines "$b/$d") "$d"; done; }
count() { grep -o 'method id="[A-Za-z]*"' "$@" | sed 's/.*id="//;s/"//' | sort -u; }

echo "== seL4 ($(cat $S/VERSION), $(git -C $S log -1 --format='%h %ad' --date=short)): lines of C, assembly and bitfield declarations"
row $S src include libsel4
echo "== its kernel, the part that is no machine's"
row $S src/object src/kernel src/api src/fastpath src/model
echo "  the files of that part:"
wc -l $S/src/object/*.c $S/src/kernel/*.c $S/src/api/*.c $S/src/fastpath/*.c | sort -rn | sed 1d | sed "s|$S/src/||;s/^/  /"
echo "== its machines"
row $S src/arch/arm src/arch/arm/32 src/arch/arm/64 src/arch/riscv src/arch/x86 src/plat src/drivers
echo "== the system calls (libsel4/include/api/syscall.xml, the first configuration)"
echo "  $(sed -n '/<api-master>/,/<\/api-master>/p' $S/libsel4/include/api/syscall.xml | grep -o 'name="[A-Za-z]*"' | sed 's/name=//;s/"//g' | tr '\n' ' ')"
echo "== the objects (libsel4/include/sel4/objecttype.h; the machine's are pages and tables)"
echo "  $(grep -o 'seL4_[A-Za-z]*Object,' $S/libsel4/include/sel4/objecttype.h | tr -d ',' | tr '\n' ' ')"
echo "== the methods (libsel4's interfaces): a capability invoked"
G=$(count $S/libsel4/include/interfaces/object-api.xml)
A=$(count $S/libsel4/arch_include/arm/interfaces/object-api-arch.xml $S/libsel4/sel4_arch_include/aarch64/interfaces/object-api-sel4-arch.xml)
echo "  any machine's: $(echo "$G" | wc -l); by object: $(echo "$G" | sed 's/^\(Untyped\|TCB\|CNode\|IRQ\|Domain\|SchedControl\|SchedContext\).*/\1/' | uniq -c | awk '{ printf "%s %d  ", $2, $1 }')"
echo "  arm's and arm64's: $(echo "$A" | wc -l)"
echo "  a message: $(grep -o 'seL4_MsgMaxLength = [0-9]*' $S/libsel4/include/sel4/constants.h) words, $(grep -o 'seL4_FastMessageRegisters [0-9]*' $S/libsel4/sel4_arch_include/aarch64/sel4/sel4_arch/constants.h | sed 's/.* //') of them in registers"
echo "== the manual (manual/parts: LaTeX) and the tutorials"
wc -l $S/manual/parts/*.tex | sed "s|$S/manual/parts/||;s/^/  /"
echo "  tutorials: $(ls $R/tutorials/tutorials | grep -v 'camkes\|libraries\|mcs' | tr '\n' ' ')"
echo "== the licences"
echo "  seL4: $(grep -rho 'SPDX-License-Identifier: [A-Za-z0-9.-]*' $S/src | sort | uniq -c | sort -rn | awk '{ printf "src %s %d  ", $3, $1 }')$(grep -rho 'SPDX-License-Identifier: [A-Za-z0-9.-]*' $S/libsel4 | sort | uniq -c | sort -rn | head -1 | awk '{ printf "libsel4 %s %d", $3, $1 }')"
echo "  the manual: $(grep -ho 'SPDX-License-Identifier: [A-Za-z0-9.-]*' $S/manual/parts/*.tex | sort | uniq -c | awk '{ printf "%s %d  ", $3, $1 }')"
echo "  the tutorials: $(grep -ho 'SPDX-License-Identifier: [A-Za-z0-9.-]*' $R/tutorials/tutorials/*/*.md | sort | uniq -c | awk '{ printf "%s %d  ", $3, $1 }')"
echo "  Pistachio: $(grep -l 'Redistribution and use in source and binary forms' -r $P/src/api | wc -l) of $(find $P/src/api -type f | wc -l) files of src/api say the BSD's words"
echo "== L4Ka::Pistachio's kernel (lines of C++ and assembly)"
row $P src src/api/v4 src/generic src/glue src/arch src/platform kdb
wc -l $P/src/api/v4/*.cc | sort -rn | sed 1d | sed "s|$P/src/api/v4/||;s/^/  /"
echo "== seL4's own measure (sel4.systems/performance.html: cycles, and their deviation)"
curl -sL -m 20 https://sel4.systems/performance.html | python3 -I -c '
import re, sys, html
for tr in re.findall(r"<tr.*?</tr>", sys.stdin.read(), re.S)[:6]:
    print("  " + " | ".join(html.unescape(re.sub(r"<[^>]*>|\s+", " ", x)).strip() for x in re.findall(r"<t[dh].*?</t[dh]>", tr, re.S)))'
echo "== ix: what a mini-l4 would stand on"
T=../..
wl() { cat "$@" | wc -l; }
printf "%8d %s\n" $(wl ../lib_machine/*.ml ../lib_machine/*.mli ../lib_machine/pi1/Arch.ml ../lib_machine/pi4/Arch.ml) "kernel/lib_machine's OCaml (Machine, Arch, Mmu, Page, Screen)" \
  $(wl ../lib_machine/*.c ../lib_machine/pi1/machine.c ../lib_machine/pi4/machine.c) "its C (the run-time system's side, the boards)" \
  $(wl ../lib_machine/pi1/l.s ../lib_machine/pi4/l.s) "its assembly (the boot, the traps, the switch)" \
  $(wl ../xv6/Proc.ml ../xv6/Syscall.ml ../xv6/Exec.ml) "mini-xv6's Proc, Syscall, Exec (what a microkernel keeps a part of)" \
  $(wl ../xv6/Fs.ml ../xv6/File.ml) "mini-xv6's Fs, File (what it puts out)" \
  $(wl ../lib_machine/Usbhost.ml ../lib_machine/Screen.ml) "kernel/lib_machine's Usbhost, Screen (drivers)" \
  $(wl ../singularity/Process.ml ../singularity/Channel.ml ../singularity/Exchange.ml ../singularity/Abi.ml) "mini-singularity's Process, Channel, Exchange, Abi"
echo "  Fs names of the kernel: $(grep -o 'Machine\.[A-Za-z_]*\|Mmu\.[a-z_]*\|Proc\.[a-z_]*' ../xv6/Fs.ml | sort -u | tr '\n' ' ')"
echo "  a process of mini-singularity is built as for Linux, its system one file: lib/sip.c, $(wl ../singularity/lib/sip.c) lines"
