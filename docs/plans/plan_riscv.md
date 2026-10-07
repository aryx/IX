# Plan: riscv64 in ix (the toolchain, the emulators, the kernels; the Orange Pi RV2)

Companions: [`plan_asm.md`](plan_asm.md), [`plan_cc.md`](plan_cc.md),
[`plan_ml.md`](plan_ml.md) (the toolchain, arm and arm64 today),
[`plan_arm.md`](plan_arm.md) and [`plan_pi.md`](plan_pi.md) (mini-5i
and mini-qemu), [`plan_kernel.md`](plan_kernel.md),
[`plan_9pi.md`](plan_9pi.md) and
[`plan_kernel_mini_ml.md`](plan_kernel_mini_ml.md) (the kernels, and
their build by ix's own tools). This plan adds a third architecture
to each of them; it changes none of their decisions.

The author (2026-10-07): "how much work it would be to add support
for riscv64 (and maybe riscv32), and being able to boot 9pi and co on
an orange pi RV2?"; then "yes maybe we can skip rv32"; then "let's
write a plan document then for riscv64 support in ix".

**Status**: proposed (2026-10-07); the author's first answers the
same day are in the decisions (the letter `j`; the boards in a
directory of their own; mini-ml alone for the kernels; the RV2 is
his). Two questions are left, at the end. Nothing is written.
The questions at the end are the author's to answer first.

## Context

ix has two architectures, chosen before any toolchain code: arm (the
Pi 1, the teaching machine) and arm64 (this machine's own, the Pi 4).
Every layer has one module for each: `Arm` and `Arm64` in the linker,
in mini-cc's `compat/`, in mini-5i; `Pi1` and `Pi4` boards in
mini-qemu; `kernel/lib_machine/pi1` and `pi4` under the kernels.

Why a third, and why this one:

- **It is the architecture the references are written for.** mini-xv6
  has one semantics, xv6-riscv's (plan_kernel.md); `~/xv6/forks/riscv64`
  is its C twin (6,758 lines of kernel), run today on QEMU's `virt`.
  RISC-V's privileged specification is what plan_arm.md already points
  to as "the clean design of the same questions".
- **A third architecture checks the split.** Two can be an `if`; three
  must be an interface. `kernel/lib_machine/Arch.mli` says it abstracts the
  machine (the table's levels, the trap frame, the ELF's class): Sv39
  is a fair test of it. The same for the linker's per-arch record
  (`decode`, `prepare`, `layout`, `encode`...) and mini-ml's `Gen`.
- **A real board, cheap, with eight cores**: the Orange Pi RV2.
- **The oracle exists.** goken has `ia`, `ic`, `il` and their 64-bit
  names `ja`, `jc`, `jl` (one source for both widths, the letter
  chosen at run time), brought up for real in July 2026
  (`~/goken/docs/claude_notes/notes_arch_riscv.txt`), with a libc for
  riscv64 (`lib_core/libc/arch/riscv64`, `syscall/os/linux/*riscv64*`).
  Its regression programs run under `qemu-riscv64` here (checked,
  2026-10-07: `tests/c/regressions/riscv64_sraiw.exe`,
  `riscv64_ptr_width.exe`, status 0).

What is different from arm64, to keep in mind through the plan:

- **The hardware is not the oracle.** This machine runs arm64 natively
  and arm32 at user level; a riscv64 program runs under `qemu-riscv64`
  only (QEMU 8.2.2 here, with `qemu-system-riscv64` and
  `riscv64-linux-gnu-gcc`). plan_arm.md's three references become two:
  QEMU for behaviour and for state, objdump for the decoder.
- **ocaml-light has no RISC-V backend** (its `asmcomp/` has alpha,
  amd64, arm, arm64, i386, m68k, mips, power, sparc). The kernels' first
  build (the Makefiles: ocaml-light, gcc, GNU's as and ld) has no
  riscv64 twin, unless one is written (arm64's: 1,943 lines with
  `arm64.S`). See decision 6.
- **QEMU has no machine for the RV2's chip** (none in 8.2.2's
  `-M help`; none found upstream). The everyday machine and the real
  board are two boards, where the Pi 4 and QEMU's `raspi4b` are one.
- **There is no AArch32 to fall back on.** mini-9pi on the Pi 4 runs
  the arm programs of the Pi 1 in AArch32 (`mini-pi`'s header;
  `mkfiles/mkconfig`: Plan 9's target is "arm only today"). On riscv64
  the programs must be riscv64's: a Plan 9 target for a 64-bit
  machine, which ix does not have yet.

## The Orange Pi RV2, as Linux describes it

From mainline Linux's device trees (6.19 and later:
`arch/riscv/boot/dts/spacemit/k1.dtsi`, `k1-orangepi-rv2.dts`; read
2026-10-07). The board's chip is sold as the Ky X1; its device tree
is the SpacemiT K1's (`compatible = "xunlong,orangepi-rv2",
"spacemit,k1"`).

| what | on the RV2 | on the Pi 4 (what ix has) |
|---|---|---|
| CPU | 8 cores, RV64GCVB (the X60), Sv39 | 4 cores, ARMv8, 4 KB granule |
| console | `uart0` at 0xd4017000, `intel,xscale-uart` (a 16550 with words 4 bytes apart and one more enable bit) | PL011, mini UART |
| interrupts | PLIC at 0xe0000000 (159 sources), CLINT at 0xe4000000 | GIC-400 |
| timer | the SBI's call, or `sstc` if the cores have it (to check) | the generic timer |
| SD card | `sdhci0` at 0xd4280000, an SDHCI | EMMC (Arasan, SDHCI-like), SDHOST |
| USB | a DWC3 at 0xc0a00000, in host mode: xHCI | DWC2 (`Usbdwc`, 261 lines) |
| network | two `spacemit,k1-emac` at 0xcac80000, 0xcac81000 (RGMII) | a USB adapter (`Etherusb`) |
| screen | HDMI: no node in mainline's device tree | the firmware's framebuffer (the mailbox) |
| boot | the first-stage loader, OpenSBI (M mode), U-Boot, then the kernel in S mode: a0 the hart, a1 the device tree | the firmware's `kernel8.img`, EL2 |

So: the console, the timer and the interrupts are standard RISC-V
and cheap; the SD card is probably close to what `Emmc` does; the
keyboard, the network and the screen are each a new driver, and the
screen has no public description to write it from (Linux's own does
not drive it yet; U-Boot may leave a framebuffer: to find out on the
board).

## Decisions

1. **riscv64 only, letter `j`.** Plan 9's letters: `i` is riscv32,
   `j` riscv64. `-m j` for mini-asm, mini-cc, mini-ml, mini-ld;
   objects `.j`; `O=j` in `mkfiles/mkconfig`, what is made under
   `_mk/j`. riscv32 is left out: no board that runs a kernel with an
   MMU has it (microcontrollers do), and tiny-os's model, the xv6
   riscv32 fork, is read and not compiled for. goken's sources serve
   both widths from one tree; ix's module is `Riscv64` and says in
   its header what a `Riscv32` would change, no more.
2. **The twin is goken's `ja`, `jc`, `jl`; the contract is the
   executable** (plan_asm.md, unchanged): the same output and status
   always, the same bytes of text where cheap. The sizes to twin:
   `ia` 1,338 lines, `ic` 6,777 (with `cck`'s shared front end beside
   it), `il` 5,218. goken may be modified to ease the comparison, as
   before. A bug found in goken's young riscv64 goes in
   `docs/plans/bugs/goken.md` with its reproduction.
3. **The encoding in the linker**, as arm and arm64: the assembler
   parses to instruction lists, `linker/Riscv64` selects and encodes
   when the addresses are known. RISC-V makes the case again: a
   constant is 1, 2 or up to 8 instructions (`lui`+`addi`, then
   shifts), an address is `auipc`+`addi` or SB-relative, a branch
   reaches 4 KB and a jump 1 MB.
4. **The compressed instructions: read, not written at first.** `il`
   has `compress.c` (270 lines). mini-ld writes 4-byte instructions
   only unless `jl` compresses by default (step 1 checks; the bytes
   decide). mini-5i and mini-qemu decode the compressed set from the
   start: gcc's programs and the C kernels (xv6's fork, the SBI's
   callers) are full of them, and it is a table of some 35 forms onto
   the same variants.
5. **Floats are the D extension's**, always there on a board that
   runs Linux, as on arm64: no arm-like FPA/VFP split. The vector and
   bit-manipulation extensions (V, B) are not used and not emulated.
6. **The kernels on riscv64 are built by ix's tools only**: the
   `mkfile`s of plan_kernel_mini_ml.md (mini-mk, mini-ml, mini-cc,
   mini-asm, mini-ld), one `l.s` in Plan 9's syntax for a board, no
   Makefile, no `start.s` in GNU's syntax, no ocaml-light. What is
   lost is the second compiler's opinion on a new board; what guards
   instead: the portable code is the Pi 4's, checked there by both
   builds, and the sessions are compared with the C kernels' on the
   same machine (xv6's riscv64 fork on `virt`). No RISC-V backend for
   ocaml-light (the author: "yes, it's fine to require mini-ml").
7. **The kernel runs in S mode over the SBI**, as on the board, where
   OpenSBI is there before U-Boot. QEMU's `virt` gives the same
   (`-bios default`). The first console and the timer are the SBI's
   calls (`sbi_console_putchar`, `sbi_set_timer`), the same on both
   boards: one image's first lines need no board's address. The
   UART's own driver comes with the interrupts (input).
8. **mini-qemu implements the SBI, not M mode.** It starts the kernel
   in S mode with a0 and a1 set, and an `ecall` from S mode is
   answered by OCaml (the timer, the console, a hart's start, the
   reset): about ten calls. Running OpenSBI's binary would need M
   mode, PMP and its devices emulated to print a banner. The price:
   mini-qemu cannot boot the real board's whole chain; said in
   `notes_pi.md` where the Pi's firmware is.
9. **Two boards, in a directory of their own** (the author: "they
   would be in a separate dir probably"): not in `raspberry/`, which
   stays the Pis'. `riscv/` here, its name and its launcher's
   (`mini-rv`, beside `mini-pi`) the author's to choose. The CPU is
   `machine/`'s, as the Pis' is; what of `raspberry/` is no Pi's (the
   display, the storage, QMP, the user network, the status line) is
   used from there, or moved where both find it when the first one is
   needed: counted then, not copied.
   ("mini-qemu" in this plan is that program too: QEMU's twin for
   these boards, as `raspberry/`'s is for the Pis.)
   **`virt` every day, `rv2` the target.** `virt` is
   QEMU's own (an ns16550 at 0x10000000, PLIC at 0x0c000000, virtio
   disks), so every step has QEMU beside mini-qemu, as today. `rv2`
   in mini-qemu is the same CPU with the RV2's map and devices as the
   kernels use them, with no QEMU to compare with: its reference is
   the board's serial log (plan_pi.md's phase D, the same method).
   plan_pi.md dropped `virt` for ARM ("we don't want to emulate every
   arch"): here it is the only machine QEMU and the kernels share.
10. **One `Arch.mli`, a third implementation**: `kernel/lib_machine/virt/` and
    `kernel/lib_machine/rv2/` (`Arch.ml`, `machine.c`, `l.s`, `board.h`),
    sharing what is the CPU's and not the board's (the traps, the
    switch, Sv39: three levels of 9 bits, entries of 8 bytes) in one
    place both include. What `Arch.mli` cannot say for RISC-V is
    changed there, for the three.
11. **A Plan 9 target for riscv64**, for mini-9pi's programs:
    `mini-mk O=j OS=plan9`. The executable's header (what `jl -H`
    writes for Plan 9, if anything: to check; else ix's own choice,
    said in `Exe`), the system calls' convention, `lib_core/system/plan9`
    with words of 8 bytes, and in the kernel `syscalls/riscv64`
    (`Ureg`, `Syscall`) and `Exec` for that header. It is the first
    64-bit Plan 9 target of ix: the Pi 4 gains from it too (its
    programs in arm64 and not AArch32), which may be done first there,
    where the Makefile's build still checks the kernel.
12. **The devices in the order a session needs them**: the console,
    the timer, then a disk, then the keyboard and the screen, then
    the network; each of the last three its own decision when
    reached, with its size known then.
13. **tiny/ is not concerned**: its real architecture is arm64
    (plan_tiny_arm64.md).

## Sizes

Estimates, from the arm64 counterparts (`wc -l`, 2026-10-07):

| piece | arm64 today | riscv64, estimated |
|---|---:|---:|
| mini-asm: the arch, its registers and names | (shared) | 150 |
| mini-ld: `Riscv64` | `Arm64` 822 | 800 |
| mini-cc: `compat/Riscv64`, the hooks in `Regs` and `Cgen`, the simple variant's emitter | `Arm64` 239 | 400 |
| mini-ml: `Gen`'s and `Emit`'s cases, the runtime's | 28 places in `Gen` | 300 |
| libc: `rt0`, the call, the numbers, `stat` | 736 | 300 (Linux's table is arm64's: the generic one) |
| mini-5i: `Riscv64`, its `_isa`, `Show_riscv64`, `Linux`'s cases | 1,006 + 193 + 279 | 1,100 |
| **the toolchain and the user emulator** | | **about 3,000** |
| mini-qemu: the privileged state, Sv39, PLIC, the SBI, ns16550, `virt` | `Pi4` 453, `Gic` 167, `Mmu64` 79 | 900 |
| the kernels' machine: `kernel/lib_machine/virt` | `pi4/` 799 (without `start.s`, GNU's twin of `l.s`) | 800 |
| a virtio disk, kernel and mini-qemu | | 400 |
| mini-9pi's part: `syscalls/riscv64`, the 64-bit Plan 9 target | `syscalls/arm64` 17 + arm's 139 | 600 |
| **the kernels on `virt`** | | **about 3,000** |
| `kernel/lib_machine/rv2`, mini-qemu's `rv2`, the UART, the SD card | | 1,000 |
| xHCI (keyboard, mouse) | DWC2: `Usbdwc` 261 | 1,000 or more |
| the network's MAC | | 500 |
| the screen | | unknown |

The real numbers replace these as each step is done.

## Steps

Each ends with something that runs and is left for review before the
next; each leaves arm's and arm64's checks passing.

0. **The corpus.** goken's `tests/c/hello_libc` built for riscv64
   (none is today: its `.exe` there are other architectures') and run
   under `qemu-riscv64`: the programs, their expected output, the
   bugs. `machine/tests/census.py` for riscv64: the mnemonics and
   forms the corpus runs (`census_riscv64.txt`), which sizes steps 1
   and 3 for real.
1. **mini-asm and mini-ld, `-m j`.** A hello in Plan 9's assembly, an
   ELF for Linux; `linker/tests/golden.sh` with goken's `ja` and
   `jl`: the same bytes. Runs under `qemu-riscv64`.
2. **mini-cc `-m j`, the libc.** The corpus of step 0 by ix:
   the same output, the text's bytes compared.
3. **mini-5i runs them.** `machine/Riscv64`: decode, execute, show;
   Linux's calls (arm64's table). Every word of the census decoded as
   objdump does (`decode_check.py`); a failing program found by its
   first diverging instruction against `qemu-riscv64 -d cpu`.
4. **mini-ml `-m j`**, its tests; then **ix built by ix**:
   `mini-mk O=j`, the eleven programs run under mini-5i and
   `qemu-riscv64`, the fixed point as on arm64 (plan_mkfiles.md).
5. **The bare machine.** `kernel/steps/step0` and `step1` for `virt`: a
   line by assembly, by C, by OCaml, through the SBI's console, under
   QEMU's `virt`. mini-asm and mini-ld gain the system instructions
   (`CSRRW` and its family, `SRET`, `WFI`, `ECALL`, `SFENCE.VMA`),
   goken's bytes.
6. **mini-qemu's `virt`**: S and U modes, the CSRs, the traps, Sv39,
   the PLIC, the SBI's calls, the ns16550; step 5's images, then
   xv6's riscv64 fork in C (`./mini-rv xv6`), its session
   QEMU's.
7. **mini-xv6 on `virt`**: `kernel/lib_machine/virt`; `usertests`; the
   session the C fork's. Its disk is in the image, as on the Pis.
8. **mini-9pi on `virt`**: the Plan 9 target (decision 11), ix's
   programs in the image, to rc's prompt on the serial line; then a
   virtio disk for ix's card.
9. **The RV2, a serial line** (the author has the board).
   `kernel/lib_machine/rv2`; first what the board says of itself, kept in the
   plan: U-Boot's log and `bdinfo` on the serial header (where the
   memory is, how an image is loaded and entered), and whether it
   leaves a framebuffer (the screen is in reach or not). Then the
   image loaded by U-Boot from the SD card; mini-xv6 then mini-9pi to their prompts,
   the board's log kept and compared with mini-qemu's `rv2`.
10. **The RV2's SD card** (SDHCI): ix's card mounted.
11. **Then, each on its own decision**: xHCI, the screen, the network,
    the eight cores.

Steps 0 to 4 need no decision but this plan's. Steps 5 to 8 stand on
plan_kernel_mini_ml.md's build. Steps 9 to 11 need the board.

## Verification

- Steps 1, 2, 4: `linker/tests/golden.sh`, `libc.sh`, mini-ml's tests,
  with `j` beside `5` and `7`; `tests/` run for the three.
- Steps 3, 6: QEMU's trace for the first divergence
  (`-d cpu,in_asm`), objdump for the decoder.
- Steps 6 to 8: a kernel's `mini-mk check` boots its image under
  mini-qemu and QEMU's `virt` and compares the session with the
  recorded one, as on the Pis.
- Steps 9, 10: the board's serial log.

## Questions for the author

Answered (2026-10-07): the letter is `j`; the boards go in a separate
directory; no ocaml-light build; the RV2 is here. Left:

1. **Decision 11's order**: the 64-bit Plan 9 target first on the
   Pi 4 (arm64 programs under mini-9pi4), before riscv64 needs it?
2. **How far before stopping**: steps 0 to 4 alone give a third
   architecture to the toolchain and its emulator; is that a first
   plan to finish and review, the kernels a second?
3. **The directory's name** (decision 9): `riscv/` and `mini-rv`?

## How the numbers were counted

- goken: `wc -l ~/goken/assemblers/ia/*.[chy] compilers/ic/*.[ch]
  linkers/il/*.[ch]`, the generated `y.tab.*` left out.
- ix: `wc -l` of the modules named in the table; `kernel/lib_machine/pi4/*`
  for the board; `lib_core/libc/arch/arm64`,
  `syscall/os/linux/*arm64*` and `os/linux/stat_arm64.c` for the libc.
- xv6: `wc -l ~/xv6/forks/riscv64/kernel/*.[chS]`.
- ocaml-light: `wc -l ~/github/ocaml-light/asmcomp/arm64/*
  asmrun/arm64*`.
- The RV2: Linux's `k1.dtsi` and `k1-orangepi-rv2.dts` (master,
  2026-10-07); QEMU: `qemu-system-riscv64 -M help`.
