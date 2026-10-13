#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# What "The Pi 2" of docs/plans/plan_system_xen.md stands on: where
# QEMU's boards start a raw image and what their processors say of a
# second level (images of a few instructions, written here as words:
# no assembler asked), and what of ix a hypervisor on a Pi 2 would
# meet. A Pi 2B V1.2 is a BCM2837, the Pi 3's chip: QEMU's raspi3b.
# A V1.1 is a BCM2836: QEMU's raspi2b.
# usage: kernels/xen/pi2.sh
#   $QEMU64: a qemu-system-aarch64 that has raspi4b (QEMU 9 or later)

cd "$(dirname "$0")"
T=../..
D=$(mktemp -d); trap 'rm -rf $D' EXIT
Q64=${QEMU64:-/media/pad/extradrive1/pad/work/TOOLCHAINS/qemu/build/qemu-system-aarch64}
[ -x $Q64 ] || Q64=$(command -v qemu-system-aarch64)
# the words of an image, little-endian
w() { for x; do printf "\\x${x:6:2}\\x${x:4:2}\\x${x:2:2}\\x${x:0:2}"; done; }
# what the image prints on the PL011 in three seconds
run() { q=$1; shift; rm -f $D/out; (timeout 3 $q "$@" -display none -serial file:$D/out -monitor none > /dev/null 2>&1; true); cat $D/out 2> /dev/null; }

# 64 bits: CurrentEL, then ID_AA64PFR0_EL1's fields for EL1 and EL2
# (2: that level runs 32-bit code too), as three digits
el() { w d5384240 d342fc00 9100c000 18000161 b9000020 d5380400 d3441c02 9100c042 b9000022 d5380400 d3482c02 9100c042 b9000022 14000000 $1; }
# 32 bits: the mode (S: SVC, Z: HYP), then ID_PFR1's field for the
# virtualization extensions
mode() { w e10f0000 e200001f e2800040 e59f1018 e5810000 ee100f31 e1a00620 e200000f e2800030 e5810000 eafffffe $1; }
# 32 bits: a, then SCR's low digit, which only the secure side may read
scr() { w e59f1018 e3a00061 e5810000 ee110f11 e200000f e2800030 e5810000 eafffffe $1; }
# 32 bits, from the secure side: the firmware's own way to HYP (a
# monitor call that sets SCR's NS and HCE and returns there), then the mode
hyp() { w ea000006 eafffffe ea000008 eafffffe eafffffe eafffffe eafffffe eafffffe \
          e3a00902 ee0c0f30 e1600070 ea000004 \
          e3001131 ee011f11 e30001da e16ff000 e1b0f00e \
          e10f0000 e200001f e2800040 e59f1004 e5810000 eafffffe $1; }
el 3f201000 > $D/el3.img; el fe201000 > $D/el4.img
mode 3f201000 > $D/mode2.img; mode 20201000 > $D/mode1.img
scr 3f201000 > $D/scr.img; hyp 3f201000 > $D/hyp.img

echo "== QEMU, 64 bits ($($Q64 --version | sed -n '1s/QEMU emulator version //p')): the level a raw image starts at, 32-bit code at EL1, at EL2"
echo "  raspi3b (the BCM2837, a Pi 2B V1.2's chip): '$(run $Q64 -M raspi3b -kernel $D/el3.img)'"
echo "  raspi4b:                                    '$(run $Q64 -M raspi4b -kernel $D/el4.img)'"
echo "== QEMU, 32 bits ($(qemu-system-arm --version | sed -n '1s/QEMU emulator version //p')): the mode, and the virtualization extensions"
echo "  raspi1ap -kernel: '$(run qemu-system-arm -M raspi1ap -kernel $D/mode1.img)'"
echo "  raspi2b -kernel (the BCM2836, a V1.1's): '$(run qemu-system-arm -M raspi2b -kernel $D/mode2.img)'"
echo "  raspi2b -kernel, SCR read: '$(run qemu-system-arm -M raspi2b -kernel $D/scr.img)' (a alone: not secure)"
echo "  raspi2b -bios, SCR read:   '$(run qemu-system-arm -M raspi2b -bios $D/scr.img)' (a0 from each of the four cores, mixed)"
echo "  raspi2b -bios, the firmware's way up: '$(run qemu-system-arm -M raspi2b -bios $D/hyp.img)'"

echo "== ix: the author's board"
grep -m1 -o 'by the author.s word a V1.2: a BCM2837' $T/docs/plans/plan_pi2.md | sed 's/^/  plan_pi2.md: /'
echo "== ix: a 32-bit hypervisor's costs"
echo "  lines of machine/Arm32.ml, Mmu32.ml and raspberry/boards/Board.ml that name the hypervisor's mode: $(cat $T/machine/Arm32.ml $T/machine/Mmu32.ml $T/raspberry/boards/Board.ml | grep -ciE 'hyp|hvc|eret')"
echo "  a word in a model is an int: $(sed -n '1,2p' $T/machine/Bits.mli | tr -d '(*' | tr -s ' \n' ' ' | sed 's/^ //;s/ plan_arm.*//') (an arm32 kernel's int has 31)"
echo "  the Pi 2's kernel leaves that mode at its start: $(grep -c 'elr_hyp\|eret' ../lib_machine/pi1/start.s) lines of kernels/lib_machine/pi1/start.s"
echo "== ix: the Pi 2's devices as mini-qemu has them"
(cd $T/raspberry && wc -l interrupts/Intc.ml timer/Systimer.ml serial/Miniuart.ml serial/Pl011.ml boards/Devices.ml video/Framebuffer.ml usb/Dwc2.ml usb/Usb.ml storage/Sdhost.ml storage/Dma.ml | sed 's/^/  /')
echo "  the cores' controller (the BCM2836's): in Board.ml, $(grep -c 'timer_ctl\|mail_ctl' $T/raspberry/boards/Board.ml) lines that name its registers"
echo "  the Pi 2's kernel's clocks: the system timer ($(grep -c 'TIMER\[' ../lib_machine/pi1/machine.c) lines of pi1/machine.c), and a core's own, $(grep -o 'CNTV_[A-Z]*' ../lib_machine/pi1/machine.c | sort -u | tr '\n' ' ')"
echo "== ix: what a 64-bit hypervisor's board layer names of the Pi 4"
echo "  kernels/lib_machine/pi4: $(cat ../lib_machine/pi4/board.h ../lib_machine/pi4/machine.c | grep -c '0xF[EF][0-9A-Fa-f]\{6\}') lines with an address of the board, $(grep -ci gic ../lib_machine/pi4/machine.c) with the GIC, of $(cat ../lib_machine/pi4/* | wc -l)"
echo "  the Pi 2's images there are: $(ls ../9pi/kernel-pi2-ix.img 2> /dev/null) (mini-xv6's boards: $(sed -n 's/^BOARD=.*echo \(pi[0-9]\);;.*echo \(pi[0-9]\);;.*/\1 \2/p' ../xv6/mkfile))"
