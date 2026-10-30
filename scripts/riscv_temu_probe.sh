#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# What TinyEMU gives a kernel (plan_riscv.md, its section on TinyEMU):
# its sources built, and an image given as its "bios", entered in M
# mode: it says misa on HTIF's console, tries the time CSR and sstc's
# stimecmp, and powers off.
#
# usage: scripts/riscv_temu_probe.sh DIR [TARBALL]    (DIR: a new directory)

set -e
W=$1
TAR=${2:-$HOME/TESTS/tinyemu-2019-12-21.tar.gz}
[ -n "$W" ] && [ ! -e "$W" ] || { echo "usage: $0 NEWDIR [TARBALL]"; exit 1; }
mkdir -p "$W"
W=$(cd "$W" && pwd)
tar xf "$TAR" -C "$W"
cd "$W"/tinyemu-*
OFF='CONFIG_FS_NET|CONFIG_SDL|CONFIG_X86EMU|CONFIG_SLIRP|CONFIG_INT128'
sed -i -E "s/^($OFF)=y/#&/" Makefile
make -j8 temu > ../temu.log 2>&1
TEMU=$PWD/temu
cd "$W"
cat > probe.S <<'EOF'
.option norvc
.globl _start
_start:
  la t0, trap
  csrw mtvec, t0
  la s0, msg_misa
  call puts
  csrr s1, misa
  li s2, 60
1:srl a0, s1, s2
  andi a0, a0, 15
  la t1, hex
  add t1, t1, a0
  lbu a0, 0(t1)
  call putc
  addi s2, s2, -4
  bgez s2, 1b
  la s0, msg_time
  call puts
  la s0, yes
  csrr t0, time         # a trap replaces s0
  call puts
  la s0, msg_sstc
  call puts
  la s0, yes
  csrr t0, 0x14d        # stimecmp
  call puts
  li t0, 0x40008000     # HTIF's tohost = 1: power off
  li t1, 1
  sw t1, 0(t0)
  sw zero, 4(t0)
2:j 2b
.align 4
trap:
  la s0, no
  csrr t0, mepc
  addi t0, t0, 4
  csrw mepc, t0
  mret
puts:
  mv s3, ra
3:lbu a0, 0(s0)
  beqz a0, 4f
  call putc
  addi s0, s0, 1
  j 3b
4:mv ra, s3
  ret
putc:
  li t0, 0x40008000     # device 1, command 1: a character
  li t1, 0x01010000
  sw a0, 0(t0)
  sw t1, 4(t0)
  ret
.data
msg_misa: .asciz "M mode, misa="
msg_time: .asciz "\ntime CSR: "
msg_sstc: .asciz "stimecmp: "
yes: .asciz "yes\n"
no: .asciz "no (illegal instruction)\n"
hex: .ascii "0123456789abcdef"
EOF
riscv64-unknown-elf-gcc -march=rv64gc -mabi=lp64d -nostdlib -static \
  -Wl,-Ttext=0x80000000 -Wl,--no-relax -o probe.elf probe.S
riscv64-unknown-elf-objcopy -O binary probe.elf probe.bin
cat > probe.cfg <<'EOF'
{ version: 1, machine: "riscv64", memory_size: 64, bios: "probe.bin" }
EOF
timeout 10 "$TEMU" probe.cfg < /dev/null |
  grep -a -E 'misa|time CSR|stimecmp|Power off'
