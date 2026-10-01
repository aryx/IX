# Plan: one real architecture in tiny, arm64

The tiny programs have two real architectures today, and no program
of one runs on a machine of the other:

| program | what it targets or runs |
|---|---|
| tiny-assembler, tiny-c, tiny-ml | arm64 (Linux's ELF), and tiny-cpu with `-tm` |
| tiny-arm, tiny-pi | arm32, the Pi1 |
| tiny-cpu, tiny-machine | our own machine |

So tiny-arm carries an assembler of its own (nothing else in tiny makes
arm32 code) and an ELF writer, under a name that says "an ARM CPU".
The author, reading the README's table: "I don't fully understand why
we need an ELF writer for tiny-arm?"; then: "I think it would be
better to choose one, or to have the two everywhere but not arm32 for
a few of the tiny-xxx and arm64 for some other tiny-xxx"; and: "I
think I would go for arm64 consistently then, espeically because
medium term we want mini-9pi to also work on the pi4".

tiny-cpu and tiny-machine are not in question ("for sure we want the
tiny-machine and tiny-cpu 'ideal' machine, and target them"): they
stay the tiny stack's own target, closed and consistent (tiny-c and
tiny-ml `-tm`, tiny-os, tiny-kernel). This plan is about the real
architecture beside it.

## Decisions

### 1. arm64, not arm32

- It is what people have: every Pi since the Pi 3, a Mac, this
  machine. The programs run natively, so the real CPU is the oracle.
- It is what the tiny toolchain already targets (tiny-assembler,
  tiny-c, tiny-ml: 3,600 lines), and why: a divide instruction,
  floating point always there, 64-bit integers (tiny-ml's output is
  ocaml-light's). Moving those to arm32 reworks the central programs;
  moving to arm64 reworks tiny-arm and tiny-pi.
- mini-9pi is to run on the Pi 4 too.

What is lost, to say in the code where it goes: arm32's 1985 choices
(a condition on every instruction, the rotated immediate, the literal
pool) were what TinyLibArm taught against tiny-cpu, "a machine
inherited" against "a machine designed". arm64 is itself a redesign
with hindsight, so the two roads are closer. The mini programs keep
arm32 in full (mini-5i, mini-asm, mini-ld, mini-cc, mini-qemu's Pi1).

### 2. tiny-arm runs executables: no assembler, no ELF writer

tiny-arm loads the ELF tiny-assembler writes (one segment) and runs
it, as mini-5i does for any toolchain's. Its own assembler, its ELF
writer and its listing go; the pipeline is tiny-c or tiny-ml, then
tiny-assembler, then tiny-arm. What goes with the assembler: GNU as's
syntax and the checks against GNU as's bytes and objdump's text, and
the laws tying one instruction type to its parser, encoder, decoder
and printer (tiny-assembler encodes its own way, a word per closure).
The check that stays is the stronger one: the same program, the same
output and status, on the real CPU, under mini-5i and under tiny-arm.

### 3. The subset is what the tiny toolchain's programs execute

Measured 2026-10-01 with `mini-5i -t` on the test programs, each
linked with all of goken's libc (7c's code):

- tiny-c's 11 programs (TinyC_tests): 1,049,646 instructions, 49
  mnemonics; hello alone, 33.
- tiny-ml's 17 programs (TinyML_test.sh's, two cut at 120 s): 46
  mnemonics, three of them new (`br`, `ldurb`, `stur`).
- 52 in all, in about ten encoding groups: add, sub and cmp (immediate
  and register); the logical ones (and, orr, eor, mvn; the bitmask
  immediate); the moves (mov, movk); the bitfields (lsl, lsr, asr,
  sxtb, sxtw, ubfx); mul, msub, udiv, sdiv, neg; the loads and stores
  of each size, signed or not, scaled or unscaled (ldur, stur); adrp;
  the branches (b, bl, br, blr, ret, b.cond, cbz, cbnz); svc. No
  floating point executed by these tests.
- The system calls: write (64), exit (93), getpid (172).

A word outside the subset stops the emulator with its address, as
mini-5i does.

### 4. tiny-pi is the Pi 4

TinyMachinePi keeps its subject (what a kernel sees) on the Pi 4's
terms, each already modelled in mini-qemu (Pi4, Gic) to check against:

- two exception levels (EL1, EL0), the vector at VBAR_EL1, svc, an
  undefined instruction, an interrupt, eret; the system registers
  those need, through mrs and msr;
- the generic timer (CNTP or CNTV, PPI 30 or 27) and the GIC-400's
  distributor and CPU interface (enable, acknowledge, end), instead of
  the Pi1's system timer and interrupt controller;
- the PL011 at 0xfe201000;
- a raw image loaded where the firmware loads kernel8.img.

Its page of kernel (today tick.s, in GNU syntax: user mode, system
calls, an undefined instruction, five timer interrupts) is rewritten
in Plan 9's syntax, for tiny-assembler, and runs the same under
tiny-pi, mini-qemu's Pi 4 and QEMU's raspi4b.

To settle when written, by reading Pi4 and QEMU: the level a raw
image is entered at (the page drops to EL1 itself if it is EL2), and
which of the two timers.

### 5. tiny-assembler gains what a kernel's page needs

A raw image output (the text alone, at a given address), and mrs,
msr, eret and wfi. It stays the one assembler of tiny.

### 6. The names: tiny-arm and tiny-pi kept (to confirm)

The author: "maybe need to rename tiny-arm64 and tiny-pi4 ?".
Recommended: no. A suffix names a sibling, and there is none: tiny has
one real architecture after this plan, as tiny-assembler and tiny-c
are not tiny-assembler64. The README's row says arm64 and Pi 4. The
files keep their names too (TinyCPUArm, TinyLibArm, TinyMachinePi), so
the code map's links and the documents' stand. The other choice costs
a rename in about 25 files and nothing else.

## Lines, before and after

Before, measured (2026-10-01, `scripts/stats/loc.py`: all lines, and
lines of code):

| file | lines | code | what |
|---|---:|---:|---|
| TinyLibArm.ml | 733 | 512 | arm32: the instruction type 53, encode and decode 74, the printer 54, the machine 129, the assembler 323, the header 100 |
| TinyCPUArm.ml | 112 | 72 | Linux's three calls, the stack, the ELF writer, the command line |
| TinyMachinePi.ml | 412 | 245 | the Pi1: modes, exceptions, PL011, timer, interrupt controller |
| TinyAssembler.ml | 680 | 480 | arm64 assembler and linker |
| **total** | **1,937** | **1,309** | |

After, estimated (to replace by the measure when done):

| file | lines | why |
|---|---:|---|
| TinyLibArm.ml | 350 to 400 | no assembler (323), no printer (54); an arm64 decoder and interpreter for decision 3's groups, more forms than arm32's subset (mini-5i's Arm64 is 1,465 against Arm32's 1,000) |
| TinyCPUArm.ml | about 100 | an ELF loader for the writer |
| TinyMachinePi.ml | 400 to 450 | the GIC and the system registers for the Pi1's simpler ones |
| TinyAssembler.ml | 720 to 740 | the raw image, mrs, msr, eret, wfi |
| **total** | **about 1,600 to 1,700** | 250 to 350 fewer |

## Phases

1. **tiny-arm on arm64**: the decoder, the interpreter, the loader,
   the three calls. Done when every program of TinyC_tests and of
   TinyML_test.sh gives the same output and status natively, under
   mini-5i and under tiny-arm (both test scripts run it).
2. **tiny-assembler**: the raw image; mrs, msr, eret, wfi; each
   checked against 7a's words.
3. **tiny-pi on the Pi 4**: decision 4, and the page of kernel, the
   same under tiny-pi, mini-qemu and QEMU.
4. **The arm32 tiny code removed** (its tests' `.s` too), and the
   documents: the README's tiny table and "Tiny (and mini), not Toy",
   tiny/README.md, projects.md, plan_arm.md's and plan_pi.md's "Outside"
   sections, the tutorials, the `.codemapconfig` lines; the lines
   measured, in the table above.

The arm32 files stay until phase 3 passes: the new code is written
beside them, then takes their names.

## Status

- **2026-10-01, the decision and the measures**: the author's words
  above; decision 3's census and the "before" lines.

- **2026-10-01, phases 1 to 3 DONE, beside the arm32 files** (the
  author: "ok let's go, let's keep the name"). The new code was
  written in files of its own (TinyLibArm64, TinyCPUArm64,
  TinyMachinePi4), for phase 4 to give them the arm32 files' names.
  - **Phase 1, tiny-arm.** TinyC_test.sh and TinyML_test.sh run each
    program under it too: the same output and status as on the real
    CPU for TinyC's 11 programs (and 7c's builds of them), TinyML's 17
    (gc, 700 million instructions, takes 41 s against mini-5i's 30: the
    script leaves it out), 100 random C programs (TinyC_fuzz.py --32)
    and 100 random ML ones (TinyML_fuzz.py). No word outside the subset
    met. Each group was written whole where its other forms cost a
    line (stp and ldp, tbz, csel, the literal's load), which the
    census had not asked for. The system calls: the three measured,
    and read.
  - **Phase 2, tiny-assembler**: `-raw address`; MRS, MSR, ERET, WFI,
    and WORD (a raw word: the page's undefined instruction); the system
    registers by name (7a's nine, and HCR_EL2, VBAR_EL1, ESR_EL1,
    CNTFRQ_EL0, CNTV_TVAL_EL0, CNTV_CTL_EL0) or SPR(n) as 7a. The
    fifteen words of a test file are 7a and 7l's, and GNU objdump names
    each register as written.
  - **Phase 3, tiny-pi.** Decision 4's two open points, settled by
    running a probe under QEMU's raspi4b (11.1, the author's build;
    Ubuntu's 8.2 has no raspi4b): a raw `-kernel` is entered at EL2
    with the four masks set, as the firmware does (an ELF, or `-device
    loader`, at EL3: QEMU's own); the timer is the virtual one (CNTV,
    line 27), which needs nothing from EL2. The three programs
    (hello.s, tick.s, echo.s, in Plan 9's syntax) print the same under
    tiny-pi, mini-qemu and QEMU; tick halts 50 ms after its timer
    starts at 10, 30 and 100 instructions a microsecond. The vectors
    need no alignment directive: the page writes a branch at each one
    it takes (0x60280, 0x60400), as the Pi1's page copied its own to 0.
  - **mini-qemu's Pi 4 boots a raw image** (`Pi4.load_raw`, 14 lines:
    at 0x80000, EL2), plan_pi.md's decision 7, until now ELF only; xv6's
    ELF still boots.
  - **A bug of the arm32 tiny-arm** found on the way: argv was built
    in reverse order (its tests passed one argument at most).
  - Lines, measured (`loc.py`: all, and code): TinyLibArm 354 (221),
    TinyCPUArm 101 (59), TinyMachinePi 373 (201), TinyAssembler 706
    (502): **1,534 (983)**, against 1,937 (1,309) before: 403 lines
    fewer, 326 of code.
  - mini-ml's parser takes the new files (parse_ix.sh's check).

- **2026-10-01, phase 4 DONE: the arm32 tiny code removed** (the
  author: "ok let's delete the arm32"). Its last commit is 7dd6b82:
  TinyLibArm, TinyCPUArm and TinyMachinePi there are arm32 and the
  Pi1, with their tests in GNU as's syntax.
  - The arm64 files have their names; tiny-arm and tiny-pi are the
    installed programs, as before.
  - TinyCPUArm_test.sh is new, and needs nothing but ix: four
    programs in TinyCPUArm_tests/ (hello, args, reverse, and outside,
    a word of floating point), each assembled by tiny-assembler, the
    same on the real CPU, under mini-5i and under tiny-arm; outside
    stops tiny-arm at its word. TinyMachinePi_test.sh is decision 4's.
    Both are in `make test`, as their arm32 ones were.
  - What mini-qemu loses: the arm32 pages ran under its Pi1 too
    (raspi1ap); nothing of tiny runs there now. xv6 and 9pi still do.
  - `./tiny-pi` assembles with tiny-assembler and runs the Pi 4
    (`-m` mini-qemu's, `-q` QEMU's).
  - The documents: the README's tiny table (tiny-arm 460 lines,
    tiny-pi 370, tiny-assembler 710; the tiny programs 9,500 in all,
    from 9,900), tiny/README.md, projects.md, the code map's entries,
    mini-5i's help (its first example was tiny-arm's ELF), a note at
    the head of plan_arm.md's and plan_pi.md's "Outside" sections.
