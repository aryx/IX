#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The numbers behind docs/plans/plan_system_xen.md: Xen (GPL 2: read
# here, nothing of it copied in ix) and two small hypervisors for ARM,
# Bao (Apache 2) and raspvisor (MIT, on the Pi 3), their parts and
# their lines; and what of ix a mini-xen would stand on: the guests
# (mini-xv6's and mini-9pi's images for the Pi 4, what they touch of
# the board), mini-qemu's models of the Pi 4's devices, and how much of
# EL2 mini-qemu's processor has.
# usage: kernel/xen/survey.sh [dir]
#   dir: where the three repositories are kept (cloned there when
#   missing, 52 MB; default: $TMPDIR/xen-refs)

cd "$(dirname "$0")"
R=${1:-${TMPDIR:-/tmp}/xen-refs}
get() { [ -d "$R/$1" ] || GIT_TERMINAL_PROMPT=0 git clone -q --depth 1 https://github.com/$2.git "$R/$1" || exit 1; }
get xen xen-project/xen; get bao bao-project/bao-hypervisor; get raspvisor matsud224/raspvisor
X=$R/xen
lines() { find "$@" -type f \( -name '*.c' -o -name '*.h' -o -name '*.S' \) -print0 | xargs -0 cat | wc -l; }
row() { b=$1; shift; for d in "$@"; do printf "%8d %s\n" $(lines "$b/$d") "$d"; done; }

echo "== Xen ($(sed -n 's/^export XEN_VERSION *= *//p' $X/xen/Makefile).$(sed -n 's/^export XEN_SUBVERSION *= *//p' $X/xen/Makefile)-unstable, $(git -C $X log -1 --format='%h %ad' --date=short)): lines of C and assembly"
row $X xen xen/common xen/common/sched xen/drivers xen/arch/x86 xen/arch/arm xen/arch/riscv tools tools/xl
echo "  hypercalls (include/public/xen.h): $(grep -c 'define __HYPERVISOR_' $X/xen/include/public/xen.h)"
echo "== in xen/arch/arm, what a guest that is not changed needs"
(cd $X/xen/arch/arm && wc -l traps.c arm64/entry.S mmu/p2m.c p2m.c io.c decode.c vgic.c vgic-v2.c gic-v2.c gic-vgic.c vtimer.c vpl011.c vuart.c domain.c domain_build.c dom0less-build.c | sed 's/^/  /')
echo "== Bao (a static partitioning hypervisor)"
row $R/bao src src/core src/arch/armv8 src/arch/riscv
echo "== raspvisor (the Pi 3: stage 2, the board's devices emulated, virtual IRQs)"
row $R/raspvisor src include
wc -l $R/raspvisor/src/*.c $R/raspvisor/src/*.S | sort -rn | sed 1d | head -12 | sed "s|$R/raspvisor/src/||;s/^/  /"
echo "== the licences"
echo "  Xen: $(grep -o 'only valid version of the GPL' $X/COPYING), $(grep -o '\*only\* v2' $X/COPYING | tr -d '*')"
echo "  Bao: $(sed -n 1p $R/bao/LICENSE | sed 's/^ *//'); raspvisor: $(sed -n 1p $R/raspvisor/LICENSE)"
echo "== the Orange Pi RV2's processor (the SpacemiT K1, in Linux's device tree): the hypervisor extension is the letter h"
I=$(curl -sL -m 20 https://raw.githubusercontent.com/torvalds/linux/master/arch/riscv/boot/dts/spacemit/k1.dtsi | grep -m1 'riscv,isa = ' | sed 's/.*= "//;s/";//')
echo "  $I"
case "${I%%_*}" in rv64*h*) echo "  h: there";; rv64*) echo "  h: not there";; *) echo "  (not fetched)";; esac

echo "== ix: the guests (the Pi 4's images, by ix's tools)"
T=../..
ls -l $T/_mk/7/kernel/xv6/kernel8.img $T/_mk/7/kernel/9pi/kernel8.img 2>/dev/null | awk '{ printf "  %9d %s\n", $5, $9 }'
echo "  entered at EL2 or EL1, they go to EL1 themselves (kernel/lib/pi4/l.s): $(grep -c 'MRS	CurrentEL' ../lib/pi4/l.s) reads of CurrentEL"
echo "  system registers of EL2 they write on the way: $(grep -o 'MSR	R[0-9]*, [A-Z0-9_]*_EL2' ../lib/pi4/l.s | sed 's/.*, //' | sort -u | tr '\n' ' ')"
echo "  their timer: $(grep -o 'CNT[A-Z]*_[A-Z]*_EL0' ../lib/pi4/l.s | sort -u | tr '\n' ' ')"
echo "  the board's addresses in kernel/lib and kernel/9pi: $(grep -rhoE '0xF[EF][0-9A-Fa-f]{6}|IO_BASE \+ 0x[0-9A-Fa-f]+' ../lib/pi4/*.c ../lib/pi4/*.h ../lib/usb.c ../9pi --include=*.c --include=*.h --include=*.ml 2>/dev/null | sort -u | tr '\n' ' ')"
echo "  io_get16's offsets in mini-9pi's drivers: $(grep -rl 'io_get16\|io_set32' ../9pi --include=*.ml | grep -v /build/ | sed 's|../9pi/||' | tr '\n' ' ')"
echo "  the screens asked: mini-xv6 $(grep -hE '^let (width|height|depth) = ' ../lib/Screen.ml | sed 's/let //' | tr '\n' ' '); mini-9pi $(grep -hE '^let (wid|ht|depth) = ' ../9pi/devices/screen/Swconsole.ml | sed 's/let //' | tr '\n' ' ')"
echo "  the pages a guest gives its processes: $(grep -h '^let pages' ../lib/pi4/Arch.ml)"
echo "== ix: mini-qemu's Pi 4, a device a module (raspberry/)"
(cd $T/raspberry && wc -l Gic.ml Pl011.ml Devices.ml Framebuffer.ml Dwc2.ml Usb.ml Sdhost.ml Dma.ml Pi4.ml | sed 's/^/  /')
echo "  they name of the host: $(grep -lE 'Unix\.|Sdl|Tsdl' $T/raspberry/{Gic,Pl011,Devices,Framebuffer,Dwc2,Usb,Sdhost,Dma}.ml 2>/dev/null | tr '\n' ' ')(nothing, if empty)"
echo "== ix: EL2 in mini-qemu's processor (machine/Arm64.ml)"
echo "  registers of EL2 it knows: $(grep -o '"[a-z0-9_]*_el2"' $T/machine/Arm64.ml | sort -u | tr -d '"' | tr '\n' ' ')"
echo "  an exception's target: $(grep -o 'let target = max[^i]*' $T/machine/Arm64.ml)"
echo "  translation: $(grep -o 'if st.mmu && st.el < 2 then' $T/machine/Arm64.ml) (one stage, none at EL2)"
echo "  stage 2's registers (vttbr, vtcr, hpfar): $(grep -c 'vttbr\|vtcr\|hpfar' $T/machine/Arm64.ml) lines"
echo "== ix: what the hypervisor's own drivers would be"
wc -l ../xv6/Usbhost.ml ../lib/usb.c ../lib/Screen.ml | sed 's/^/  /'
