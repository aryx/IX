# Plan: riscv64 in ix (the toolchain, the emulators, the kernels; the Orange Pi RV2)

Companions: [`plan_asm.md`](done/plan_asm.md), [`plan_cc.md`](done/plan_cc.md),
[`plan_ml.md`](done/plan_ml.md) (the toolchain, arm and arm64 today),
[`plan_arm.md`](done/plan_arm.md) and [`plan_pi.md`](done/plan_pi.md) (mini-5i
and mini-qemu), [`plan_kernel.md`](done/plan_kernel.md),
[`plan_9pi.md`](done/plan_9pi.md) and
[`plan_kernel_mini_ml.md`](done/plan_kernel_mini_ml.md) (the kernels, and
their build by ix's own tools). This plan adds a third architecture
to each of them; it changes none of their decisions.

The author (2026-10-07): "how much work it would be to add support
for riscv64 (and maybe riscv32), and being able to boot 9pi and co on
an orange pi RV2?"; then "yes maybe we can skip rv32"; then "let's
write a plan document then for riscv64 support in ix". And
(2026-10-30): "how much work would it be to support riscv64 (and
qemu-riscv, and tinyemu) in ix?"; then "actually recent ocaml have a
riscv backend I think. Let's update the plan document with this new
analysis".

**Status**: proposed (2026-10-07), updated 2026-10-30: TinyEMU a
target beside QEMU's `virt` (its section, decision 14, step 9), OCaml
4.14's riscv backend (decision 6, tried), the sizes counted again.
The author's first answers of 2026-10-07 are in the decisions (the
letter `j`; the boards in a directory of their own; the RV2 is his);
"no ocaml-light, mini-ml required" still holds, OCaml now optional
beside it. No ix code for riscv64 is written; what ran is
`scripts/riscv_ocaml_cross.sh` and `scripts/riscv_temu_probe.sh`.
The questions at the end are the author's to answer first.

In short, new lines of code, estimated: about 3,650 for the toolchain
under `qemu-riscv64`, 3,000 more for xv6's and 9pi's prompts on QEMU's
`virt`, 500 more for TinyEMU: about 7,000, the RV2's serial line and
SD card 1,000 beyond.

## Context

ix has two architectures, chosen before any toolchain code: arm (the
Pi 1, the teaching machine) and arm64 (this machine's own, the Pi 4).
Every layer has one module for each: `Arm` and `Arm64` in the linker,
in mini-cc's `compat/`, in mini-5i; `Pi1` and `Pi4` boards in
mini-qemu; `kernels/lib_machine/pi1` and `pi4` under the kernels.

Why a third, and why this one:

- **It is the architecture the references are written for.** mini-xv6
  has one semantics, xv6-riscv's (plan_kernel.md); `~/xv6/forks/riscv64`
  is its C twin (6,758 lines of kernel), run today on QEMU's `virt`.
  RISC-V's privileged specification is what plan_arm.md already points
  to as "the clean design of the same questions".
- **A third architecture checks the split.** Two can be an `if`; three
  must be an interface. `kernels/lib_machine/Arch.mli` says it abstracts the
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
  amd64, arm, arm64, i386, m68k, mips, power, sparc), **OCaml has one**:
  since 4.11, so in the switch's 4.14 (`asmcomp/riscv`, `runtime/riscv.S`:
  1,677 lines) and in 5.5. The second compiler of the arm boards can be
  OCaml's; but this machine is arm64, so it must be a cross compiler,
  which 4.14's `configure` does not make. See decision 6.
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

## TinyEMU, as its sources describe it

Fabrice Bellard's RISC-V emulator (`temu`), the 2019-12-21 version in
`~/TESTS`, built and tried by `scripts/riscv_temu_probe.sh`. Small
enough to read: 3,420 lines the CPU, 1,387 the floats, 1,053 the
machine, 2,650 virtio. It has its own machine, not QEMU's `virt`:

| what | TinyEMU | QEMU's `virt` |
|---|---|---|
| CPU | RV64IMAFDC, S and U (misa, by the probe), Sv39 and Sv48; one hart | as many harts as asked |
| first code | the "bios" (required), M mode at 0x80000000, a0 the hart, a1 the device tree | OpenSBI, the kernel in S mode at 0x80200000 |
| SBI | none: the bios's (Linux's images bring `bbl`) | OpenSBI |
| timer | CLINT 0x02000000 in M mode; no `time` CSR, no `sstc` (both trap: the probe) | the SBI's |
| console | virtio-console; HTIF 0x40008000 for output only | ns16550 at 0x10000000 |
| interrupts | PLIC at 0x40100000 | PLIC at 0x0c000000 |
| virtio | MMIO at 0x40010000, version 2 only | MMIO at 0x10001000, legacy unless `-global virtio-mmio.force-legacy=false` |
| devices | block, net, 9p, input; a simple framebuffer at 0x41000000 | those, and more |

What it means here:

- A kernel of `virt` runs nowhere else without changes: another UART
  (none), other addresses, no SBI. xv6's riscv64 fork, which has its
  own M-mode start, does not print there as it is.
- It is the easiest screen of the three machines: a framebuffer at a
  fixed address and virtio-input, where the RV2's screen is unknown.
  mini-rio's way there is short (decision 12).
- It also has virtio-9p, a host's directory served as a file system:
  mini-9pi speaks 9P already. Not needed for a first boot; noted.
- The kernel is given after the bios, at the next 2 MB: 0x80200000
  when the bios is small, as on QEMU.

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
6. **The kernels on riscv64 are built by ix's tools, OCaml 4.14
   optional beside them.** The `mkfile`s of plan_kernel_mini_ml.md
   (mini-mk, mini-ml, mini-cc, mini-asm, mini-ld), one `l.s` in Plan
   9's syntax for a board, are what is required, what `make test` runs
   and what self-hosts. No RISC-V backend for ocaml-light (the author:
   "yes, it's fine to require mini-ml"). But the second compiler's
   opinion on a new board, written off here on 2026-10-07, is not lost
   after all: `make BOARD=virt COMPILER=ocaml`, as `BOARD=pi4
   COMPILER=ocaml` is today (`kernel.mk`, `kernels/ocaml.sh`), in
   `test-all` and not in the gate.

   Tried (`scripts/riscv_ocaml_cross.sh`, 2 minutes from nothing):
   4.14.2's `configure` makes a native compiler only, but the host's
   ocamlc and ocamlrun build an ocamlopt whose `Config` says riscv, as
   `ocaml-light.sh`'s `-target-arch` does; stdlib and `libasmrun.a`
   follow, `HAS_STACK_OVERFLOW_DETECTION` taken out of `s.h`. Its
   program ran under `qemu-riscv64`: the GC, exceptions, `Printf`.

   What it costs: a `kernels/ocaml-riscv.sh` from that script (~40
   lines), `kernel.mk`'s conditions, and the board's boot in GNU's
   syntax (`start.s`, 366 lines on the Pi 4, and `kernel.ld`): about
   400 lines, OCaml's objects being GNU's as's, which mini-ld does not
   read. What it buys, besides the board's second opinion:
   - mini-ml's riscv64 output has a differential test at user level:
     the same `.ml` by both, under `qemu-riscv64`, the same output. Its
     tests' programs need no kernel for that.
   - a kernel can boot on `virt` before mini-ml has `-m j`: steps 5 to
     7 no longer wait for step 4, and a fault on a new board is known
     to be the kernel's or the compiler's.
   - ix's own programs built by OCaml are a corpus for mini-5i (step
     0), with gcc's compressed instructions in their runtime.

   Fused floats: OCaml's riscv selects `fmadd.d` (2 in the script's
   assembly), as its arm64 does and mini-ml does not:
   the two compilers' whole-number-arithmetic rule already applies.

   OCaml 5.5 also has the backend, and makes cross compilers itself
   (5.4's "simplify the build of cross compilers", 5.5's freestanding
   targets; read in its `Changes`, not tried). The kernels' runtime is
   4.14's, so it is not the one here; it is the one to try for
   domains, on the RV2's eight cores.
7. **The kernel runs in S mode over the SBI**, as on the board, where
   OpenSBI is there before U-Boot. QEMU's `virt` gives the same
   (`-bios default`). The first console and the timer are the SBI's
   calls (`sbi_console_putchar`, `sbi_set_timer`), the same on every
   board: one image's first lines need no board's address. The
   UART's own driver comes with the interrupts (input). TinyEMU has
   no SBI: decision 14 brings it one.
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
10. **One `Arch.mli`, a third implementation**: `kernels/lib_machine/virt/` and
    `kernels/lib_machine/rv2/` (`Arch.ml`, `machine.c`, `l.s`, `board.h`),
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
    reached, with its size known then. The first screen to try is
    TinyEMU's: virtio-input and a framebuffer at a fixed address,
    about 400 lines, usable on QEMU too with virtio-input and `ramfb`
    or virtio-gpu (to size then).
13. **tiny/ is not concerned**: its real architecture is arm64
    (plan_tiny_arm64.md).
14. **TinyEMU is a third machine, after `virt`, with a small SBI of
    ours.** `kernels/lib_machine/temu/`, sharing the CPU's part with
    `virt` as `rv2` does (decision 10). An ix `sbi.s` of about 150
    lines is its bios, in M mode, given as TinyEMU's `bios` with the
    kernel as its `kernel`: it delegates the traps, answers
    `sbi_set_timer` and `sbi_console_putchar` (CLINT, HTIF), gives S
    mode the timer's interrupt, emulates the `time` CSR's trap, and
    enters the kernel at 0x80200000. So the kernels above speak the
    SBI on all three machines, and decision 7 stands. Not `bbl`: the
    tarball has none, and it would be one more outside binary.
    Input needs virtio-console, there being no UART (about 200 lines,
    over the virtio of step 8). One hart, whatever a kernel asks.
    TinyEMU is **a machine to boot on, not a twin to write**: mini-qemu
    has `virt`, with QEMU to compare with; a `temu` board in it, on the
    same CPU, about 300 lines more, only if the author asks.

## Sizes

Estimates, from the arm64 counterparts (`wc -l`, 2026-10-30; the
estimates of 2026-10-07 changed where the tree did: mini-cc and
mini-ml have grown an SSA backend beside the simple one, so 400 and
300 became 600 and 700):

| piece | arm64 today | riscv64, estimated |
|---|---:|---:|
| mini-asm: the arch, its registers and names | (shared) | 150 |
| mini-ld: `Riscv64` | `Arm64` 867 | 800 |
| mini-cc: `compat/Riscv64`, the hooks in `Regs` and `Cgen`, the emitters of `simple` and `ssa` | `Arm64` 240; 54 lines naming a machine in `ssa`, `simple`, `opti`, `Emit` | 600 |
| mini-ml: `ssa/Emit`'s and `simple/Gen`'s cases, the runtime's | 64 + 22 lines naming a machine, many a two-way match; no flags on RISC-V: not `CMP` then `B%s` | 700 |
| libc: `rt0`, the call, the numbers, `stat` | 330 | 300 (Linux's table is arm64's: the generic one) |
| mini-5i: `Riscv64`, its `_isa`, `Show_riscv64`, `Linux`'s cases | 1,007 + 194 + 280 | 1,100 |
| **the toolchain and the user emulator** | | **about 3,650** |
| mini-qemu: the privileged state, Sv39, PLIC, the SBI, ns16550, `virt` | `Pi4` 455, `Gic` 167, `Mmu64` 80 | 900 |
| the kernels' machine: `kernels/lib_machine/virt` | `pi4/` 811 (without `start.s`, GNU's twin of `l.s`) | 800 |
| a virtio disk, kernel and mini-qemu | | 400 |
| mini-9pi's part: `syscalls/riscv64`, the 64-bit Plan 9 target (the riskiest: no ix program has run on a 64-bit Plan 9) | `syscalls/arm64` 36 + arm's | 600 to 1,000 |
| **the kernels on `virt`** | | **about 3,000** |
| TinyEMU: `lib_machine/temu`, `sbi.s`, virtio-console | | 500 |
| its screen and keyboard: the framebuffer, virtio-input | | 400 (optional) |
| OCaml beside mini-ml: the cross script, `start.s`, `kernel.ld` (decision 6) | `start.s` 366 | 400 (optional) |
| mini-dotnet's JIT (it has come since this plan; the interpreter runs without) | `Jit` 944 for both | 500 (optional) |
| the other kernels (oberon, singularity, squeak), each after `lib_machine/virt` | their machine directories | not sized |
| `kernels/lib_machine/rv2`, mini-qemu's `rv2`, the UART, the SD card | | 1,000 |
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
   and 3 for real. And OCaml's corpus: `kernels/ocaml-riscv.sh`, from
   `scripts/riscv_ocaml_cross.sh` (decision 6), ix's small programs
   and mini-ml's tests by it, their outputs under `qemu-riscv64`.
1. **mini-asm and mini-ld, `-m j`.** A hello in Plan 9's assembly, an
   ELF for Linux; `linker/tests/golden.sh` with goken's `ja` and
   `jl`: the same bytes. Runs under `qemu-riscv64`.
2. **mini-cc `-m j`, the libc.** The corpus of step 0 by ix:
   the same output, the text's bytes compared.
3. **mini-5i runs them.** `machine/Riscv64`: decode, execute, show;
   Linux's calls (arm64's table). Every word of the census decoded as
   objdump does (`decode_check.py`); a failing program found by its
   first diverging instruction against `qemu-riscv64 -d cpu`.
4. **mini-ml `-m j`**, its tests, each with OCaml's output of step 0
   to compare; then **ix built by ix**:
   `mini-mk O=j`, the eleven programs run under mini-5i and
   `qemu-riscv64`, the fixed point as on arm64 (plan_mkfiles.md).
5. **The bare machine.** `kernels/steps/step0` and `step1` for `virt`: a
   line by assembly, by C, by OCaml, through the SBI's console, under
   QEMU's `virt`. mini-asm and mini-ld gain the system instructions
   (`CSRRW` and its family, `SRET`, `WFI`, `ECALL`, `SFENCE.VMA`),
   goken's bytes.
6. **mini-qemu's `virt`**: S and U modes, the CSRs, the traps, Sv39,
   the PLIC, the SBI's calls, the ns16550; step 5's images, then
   xv6's riscv64 fork in C (`./mini-rv xv6`), its session
   QEMU's.
7. **mini-xv6 on `virt`**: `kernels/lib_machine/virt`; `usertests`; the
   session the C fork's. Its disk is in the image, as on the Pis.
8. **mini-9pi on `virt`**: the Plan 9 target (decision 11), ix's
   programs in the image, to rc's prompt on the serial line; then a
   virtio disk for ix's card.
9. **TinyEMU** (decision 14): `sbi.s` and a line through HTIF, the
   probe's way; then `kernels/lib_machine/temu`, mini-xv6 and mini-9pi
   to their prompts on virtio-console, with the disk of step 8 set to
   virtio's version 2 on QEMU first. Then, if wanted, the framebuffer
   and virtio-input, mini-rio on them. TinyEMU has no second opinion:
   a difference from `virt`'s session is looked at under QEMU.
10. **The RV2, a serial line** (the author has the board).
    `kernels/lib_machine/rv2`; first what the board says of itself, kept in the
    plan: U-Boot's log and `bdinfo` on the serial header (where the
    memory is, how an image is loaded and entered), and whether it
    leaves a framebuffer (the screen is in reach or not). Then the
    image loaded by U-Boot from the SD card; mini-xv6 then mini-9pi to their prompts,
    the board's log kept and compared with mini-qemu's `rv2`.
11. **The RV2's SD card** (SDHCI): ix's card mounted.
12. **Then, each on its own decision**: xHCI, the screen, the network,
    the eight cores.

Steps 0 to 4 need no decision but this plan's. Steps 5 to 9 stand on
plan_kernel_mini_ml.md's build; with OCaml (decision 6) step 5 need
not wait for step 4. Steps 10 to 12 need the board.

## Verification

- Steps 1, 2, 4: `linker/tests/golden.sh`, `libc.sh`, mini-ml's tests,
  with `j` beside `5` and `7`; `tests/` run for the three. Step 4 too:
  each mini-ml test's output, OCaml's by `qemu-riscv64`.
- Steps 3, 6: QEMU's trace for the first divergence
  (`-d cpu,in_asm`), objdump for the decoder.
- Steps 6 to 8: a kernel's `mini-mk check` boots its image under
  mini-qemu and QEMU's `virt` and compares the session with the
  recorded one, as on the Pis.
- Step 9: the same session under `temu`, by hand or in `test-all`: it
  needs TinyEMU's sources, so not in `make test`.
- The cross OCaml, like QEMU's system emulator with a kernel: not in
  the gate, in `test-all`.
- Steps 10, 11: the board's serial log.

## Questions for the author

Answered (2026-10-07): the letter is `j`; the boards go in a separate
directory; no ocaml-light build; the RV2 is here. Left:

1. **Decision 11's order**: the 64-bit Plan 9 target first on the
   Pi 4 (arm64 programs under mini-9pi4), before riscv64 needs it?
2. **How far before stopping**: steps 0 to 4 alone give a third
   architecture to the toolchain and its emulator; is that a first
   plan to finish and review, the kernels a second?
3. **The directory's name** (decision 9): `riscv/` and `mini-rv`?
4. **OCaml beside mini-ml** (decision 6): written with this plan's
   kernels, about 400 lines, or only its user-level use (the ~40-line
   script, no `start.s`)? The second is enough for mini-ml's check.
5. **A `temu` board in mini-qemu** (decision 14): not planned; wanted?

## How the numbers were counted

- goken: `wc -l ~/goken/assemblers/ia/*.[chy] compilers/ic/*.[ch]
  linkers/il/*.[ch]`, the generated `y.tab.*` left out.
- ix: `wc -l` of the modules named in the table; `kernels/lib_machine/pi4/*`
  for the board; `lib_core/libc/arch/arm64`,
  `syscall/os/linux/*arm64*` and `os/linux/stat_arm64.c` for the libc.
- xv6: `wc -l ~/xv6/forks/riscv64/kernel/*.[chS]`.
- ocaml-light: `wc -l ~/github/ocaml-light/asmcomp/arm64/*
  asmrun/arm64*`.
- The RV2: Linux's `k1.dtsi` and `k1-orangepi-rv2.dts` (master,
  2026-10-07); QEMU: `qemu-system-riscv64 -M help`.
- TinyEMU: `~/TESTS/tinyemu-2019-12-21.tar.gz`, `riscv_machine.c`'s
  addresses and `copy_bios`, `wc -l` of `riscv_cpu.c`,
  `riscv_cpu_template.h`, `riscv_cpu_fp_template.h` (the CPU),
  `softfp*` (the floats), `riscv_machine.c`, `virtio.c`; misa, the
  `time` CSR and `stimecmp` by `scripts/riscv_temu_probe.sh DIR`.
  `virt`'s virtio address and `force-legacy`: xv6's riscv64 fork
  (`kernel/memlayout.h`, its `Makefile`).
- OCaml: `scripts/riscv_ocaml_cross.sh DIR`, on 4.14.2 (2 minutes 10,
  with 8 jobs; its `fmadd.d` count); `asmcomp/riscv/*`,
  `runtime/riscv.S` in its sources; 4.11's backend from the release
  notes (ocaml.org/releases/4.11.0, #9441); 5.4's and 5.5's cross
  compilers from `Changes` in the 5.5.1 switch's sources.
- Lines naming a machine: `git grep` of `Arm64`, `arm64`, `\barm\b`
  in the files named, the ones in `Emit` and `Gen` by `Arm64|Arm\b`.
- The estimates are scaled from arm64's modules, by judgment: only
  the probe and the OCaml program have run on riscv64.
