#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The numbers behind docs/plans/plan_system_dos.md: MS-DOS as Microsoft
# released it (MIT: 1.25, 2.0, 4.0), FreeDOS's kernel (GPL 2: read
# here, nothing of it copied in ix), and a DOS game's own layer over
# DOS, the extender and the VGA: Heretic's I_IBM.C (GPL 2, DOOM's
# engine; DOOM's own release has only the Linux layer); and what of ix
# a mini-dos would stand on: the machine layer, the FAT, the card's
# and the keyboard's drivers, the screen, and what the two emulators
# answer of a framebuffer of 8 bits with a palette.
# usage: kernels/dos/survey.sh [dir]
#   dir: where the repositories are kept (cloned there when missing,
#   270 MB, 261 of them MS-DOS's; default: $TMPDIR/dos-refs)

cd "$(dirname "$0")"
R=${1:-${TMPDIR:-/tmp}/dos-refs}
get() { [ -d "$R/$1" ] || GIT_TERMINAL_PROMPT=0 git clone -q --depth 1 https://github.com/$2.git "$R/$1" || exit 1; }
get msdos microsoft/MS-DOS; get freedos FDOS/kernel; get heretic OpenSourcedGames/Heretic; get doom id-Software/DOOM
M=$R/msdos
total() { cat "$@" | wc -l; }
src() { find "$@" -type f \( -iname '*.asm' -o -iname '*.c' -o -iname '*.h' -o -iname '*.inc' \) -print0 | xargs -0 cat | wc -l; }

echo "== MS-DOS 1.25 ($(git -C $M log -1 --format='%h %ad' --date=short); $(sed -n 1p $M/LICENSE)): lines of 8086 assembly"
(cd $M/v1.25/source && wc -l MSDOS.ASM IO.ASM COMMAND.ASM STDDOS.ASM 2>/dev/null | sed 's/^/  /')
echo "  with its tools (ASM, TRANS, HEX2BIN): $(total $M/v1.25/source/*.ASM)"
echo "== MS-DOS 2.0: $(total $M/v2.0/source/*.ASM) lines in $(ls $M/v2.0/source/*.ASM | wc -l) files; the kernel's and the shell's largest"
(cd $M/v2.0/source && wc -l DISK.ASM EXEC.ASM DIR.ASM XENIX.ASM XENIX2.ASM SYSCALL.ASM ALLOC.ASM FAT.ASM SYSINIT.ASM COMMAND.ASM TCODE.ASM TCODE2.ASM TCODE3.ASM TCODE4.ASM TCODE5.ASM 2>/dev/null | sed 's/^/  /')
echo "== MS-DOS 4.0: $(src $M/v4.0/src) lines (assembly, C, their includes)"
for d in DOS BIOS CMD/COMMAND MEMM DEV/XMA2EMS DEV/XMAEM DEV/RAMDRIVE; do printf "%8d %s\n" $(src $M/v4.0/src/$d) $d; done
echo "== FreeDOS's kernel ($(sed -n 1p $R/freedos/COPYING | sed 's/^[ \t]*//'), $(sed -n 2p $R/freedos/COPYING | sed 's/^[ \t]*//')): $(src $R/freedos/kernel $R/freedos/hdr $R/freedos/drivers) lines in kernel/, hdr/ and drivers/"
echo "== a game's layer over DOS: Heretic's (DOOM's engine; $(sed -n 3p $R/heretic/README.txt))"
H="$R/heretic/Heretic Source"
(cd "$H" && wc -l I_IBM.C I_IBM_A.ASM I_SOUND.C | sed 's/^/  /')
echo "  calls of an interrupt from protected mode (int386, int386x): $(grep -c 'int386' "$H/I_IBM.C")"
echo "  of them the video's (0x10): $(grep -c 'int386 *(0x10' "$H/I_IBM.C"); the extender's (DPMI_INT, 0x31): $(grep -c 'int386x\? *( *\(DPMI_INT\|0x31\)' "$H/I_IBM.C")"
echo "  the mode: $(grep -m1 'regs.w.ax = 0x13' "$H/I_IBM.C" | tr -d '\t'); the screen: $(grep -m1 '0xa0000' "$H/I_IBM.C" | tr -d '\t')"
echo "  vectors taken (_dos_setvect): $(grep -c '_dos_setvect' "$H/I_IBM.C"); pages locked (_dpmi_lockregion): $(grep -c '_dpmi_lockregion' "$H/I_IBM.C")"
echo "  the VGA's ports named: $(grep -oE '0x3[cCdD][0-9a-fA-F]' "$H/I_IBM.C" | tr a-f A-F | sort -u | tr '\n' ' ')"
echo "  DOOM's release (linuxdoom-1.10): $(src $R/doom/linuxdoom-1.10) lines of C, its layer for Linux $(total $R/doom/linuxdoom-1.10/i_*.c)"

T=../..
echo "== ix: the machine layer (kernels/lib_machine), the Pi 1's"
(cd ../lib_machine && wc -l libc.c runtime.c machine.c usb.c Machine.ml Screen.ml Usbhost.ml Mmu.ml pi1/l.s pi1/l1.s pi1/l2.s pi1/machine.c pi1/Arch.ml | sed 's/^/  /')
echo "  where its kernels are linked: $(grep -m1 '^KERNBASE' ../lib_machine/pi1/kernel.ld); the MMU goes on in the start: $(grep -c 'MCR	15, 0, R0, SCTLR' ../lib_machine/pi1/l.s) writes of SCTLR in l.s"
echo "== ix: what a DOS needs that is written"
wc -l ../9pi/filesystems/lib_fat/Fat.ml ../9pi/devices/storage/arm/Emmc.ml ../9pi/devices/keyboard/Kbd.ml ../9pi/devices/audio/Devaudio.ml $T/tiny/TinyShell.ml $T/games/fps/TinyWolfenstein.ml | sed 's/^/  /'
echo "  Fat's operations: $(grep -o '^val [a-z_]*' ../9pi/filesystems/lib_fat/Fat.mli | sed 's/val //' | tr '\n' ' ')"
echo "  the FATs it names: $(grep -oiE 'fat ?(12|16|32)' ../9pi/filesystems/lib_fat/Fat.ml ../9pi/filesystems/lib_fat/Fat.mli | sed 's/.*://' | tr a-z A-Z | tr -d ' ' | sort | uniq -c | tr '\n' ' ')"
echo "  mini-xv6, a kernel of processes over the same layer: $(total ../xv6/*.ml) lines of OCaml"
echo "  the console's cell: $(grep -hE '^let (width|height|depth|cell_w|cell_h) = ' ../lib_machine/Screen.ml | sed 's/let //' | tr '\n' ' ')"
echo "== the framebuffer of 8 bits, its palette and its second page, in the emulators"
echo "  mini-qemu's mailbox (raspberry/boards/Devices.ml), the tags it answers: $(grep -oE '0x0004[0-9a-f]{4}' $T/raspberry/boards/Devices.ml | sort -u | tr '\n' ' ')"
echo "  the palette's (0x0004800b): $(grep -c '0x0004800b' $T/raspberry/boards/Devices.ml); the virtual offset's (0x00048009): $(grep -c '0x00048009' $T/raspberry/boards/Devices.ml)"
echo "  mini-qemu's depths shown (raspberry/video/Framebuffer.ml): $(grep -oE '\| (16|24|8|32) ->' $T/raspberry/video/Framebuffer.ml | tr -d '|>-' | tr -s ' \n' ' ')and the rest as 32"
Q=$(curl -sL -m 20 https://raw.githubusercontent.com/qemu/qemu/master/hw/misc/bcm2835_property.c)
echo "  QEMU's (hw/misc/bcm2835_property.c, master): $(echo "$Q" | grep -oE 'case RPI_FWREQ_FRAMEBUFFER_SET_(DEPTH|PALETTE|VIRTUAL_OFFSET)' | sed 's/case RPI_FWREQ_FRAMEBUFFER_//' | tr '\n' ' ')$([ -z "$Q" ] && echo '(not fetched)')"
echo "  QEMU here: $(qemu-system-arm --version 2>/dev/null | sed -n 1p)"
