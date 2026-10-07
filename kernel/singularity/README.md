# kernel/singularity/

mini-singularity: Microsoft Research's Singularity (2003-2010) as its
papers tell it, written in OCaml, running on the bare Raspberry Pi 1
and Pi 4: **an operating system whose processes are isolated by the
language, not by the hardware**. Beside mini-xv6 and mini-9pi, which
isolate theirs by the MMU, on the same boards with the same compiler.
Its plan, with what was decided and what each stage found, is
[`docs/plans/plan_system_singularity.md`](../../docs/plans/plan_system_singularity.md).

It is not a twin, and nothing of Singularity's kit is here (its
licence is for non-commercial academic use: read, never copied). What
is kept is the approach, the system's three ideas:

- **Software-isolated processes.** Every process is in the kernel's
  address space and at its privilege: no page table is made or
  switched, a call of the kernel is a call. Each has its own heap,
  collector and run-time system.
- **Channels with contracts.** The only way two processes talk. A
  contract says the messages and, as a state machine, when each may be
  sent. Data moves by a block's owner changing, not by a copy.
- **Manifests**: a program is given what it needs and no more. Not
  here yet.

**What is lost, not to be hidden**: Sing# checks contracts and
ownership when a program is compiled. OCaml cannot, and here they are
checked when it runs: a message its contract does not allow ends its
sender, a block used after it was sent raises. And the isolation
itself is by convention today: mini-ml's safe mode (no `external`, no
`Obj`) is stage 5, not written.

## Running it

    ./mini-pi mini-singularity      the Pi 1, its console in this terminal
    ./mini-pi mini-singularity4     the Pi 4 (arm64)

from ix's root (`-q`: QEMU in mini-qemu's place; `-n`: no build). Or
here, by hand:

    mini-mk              _mk/7/kernel/singularity/kernel8.img (the Pi 4)
    mini-mk O=5          _mk/5/kernel/singularity/kernel.img (the Pi 1)
    mini-mk run          under mini-qemu (Ctrl-A x quits)
    mini-mk check        its lines, under mini-qemu and QEMU (O=5: the Pi 1's)
    ./numbers.sh         what a call, a yield, a message and a process cost

It is built by ix's own tools only (mini-mk, mini-ml, mini-cc,
mini-asm, mini-ld: `PATH=../../bin:$PATH`), which want the standard
library built first (`mini-mk` in `lib_core/`; `mini-pi` does it).

There is no shell yet: the kernel starts `init`, which starts the
other programs and waits for them, and the machine stops when no
process is left.

## A program

A process's program is an OCaml program as any other; what it asks of
the kernel beyond `print_string` and `exit` is `Sip`. pong, whole
(`programs/pong/Main.ml`), the server of the Pong contract:

    let () =
      let e = Pong.Exp.of_endpoint (Sip.given 0) in
      Pong.Exp.ready e;
      let rec serve () =
        (match Pong.Exp.receive e with
         | Ping n -> Pong.Exp.pong e (n + 1)
         | Text (b, n) -> say (...(Sip.sub b 0 n)); Sip.free b; Pong.Exp.thanks e
         | Lend b -> Pong.Exp.return e b);
        serve ()
      in
      try serve () with Sip.Closed -> say "pong: the channel is closed\n"; exit 0

`Pong.Exp.ping` does not exist and `Pong.Exp.pong e "x"` has no type:
a message's direction and arguments are OCaml's to check. Two pongs in
a row compile, and the kernel ends the program that sends them.

## What is in this directory

Everything mini-singularity is made of: its own files, and under
`machine/` and `tests/` the ones it shares with ix's other kernels,
each a symbolic link (`ls -l machine` says from where). Only the
language is outside: mini-ml's runtime and the standard library. The
mkfile says in full what the image is made of.

The kernel:

| file | lines | what |
|---|---:|---|
| `Process` | 190 | the processes: a program's copy put at its address and called; the handles; create, start, join, yield, exit; the scheduler, cooperative |
| `Abi` | 150 | the 16 functions a process may call, numbered |
| `Channel` | 112 | endpoints, messages, the contract checked at each send |
| `Exchange` | 61 | the exchange heap: blocks with one owner |
| `Main` | 12 | the boot: init started, then the scheduler |
| `cross.c`, `cross_arm.s`, `cross_arm64.s` | 280 | the crossing between two programs: the registers and stacks it keeps |

(Lines of the `.ml`, 2026-10-07; each has a `.mli` that says what it
is.)

`lib/`: what a program is linked with. `Sip` (the kernel's calls, for
a program), `Contract` (a contract as a value: the kernel's too),
`sip.c` (the system under the C library and the run-time system, and
the table of the blocks a process owns), `malloc.c`, the start in
assembly.

`contracts/`: `Pong` and `Intro`, each written by hand over `Sip` and
`Contract`: an end's own type, an operation a message. What a
declaration is to become.

`programs/`: a directory a program. `init`; `hello`; `tick` and
`tock`, which run in turn; `ping` and `pong`, a client and a server;
`rogue`, a client that breaks the contract; `bench` and `nothing`, for
the numbers.

`machine/` (links): `Machine`, the boards' C and assembly, mini-xv6's
slots for a process's kernel stack.

## How it differs from Singularity

- **Checked when the program runs**, as said above.
- **The image is built whole from sources**: its programs are known
  when it is made, each linked at its own address, and kept in the
  kernel's image as a pristine copy. No loader, no program from a
  disk, one process of a program at a time.
- **Cooperative**: a process runs until it calls the kernel. One that
  loops holds the processor.
- **One thread a process.**
- **A block's bytes are reached through `Sip`** (`get`, `set`, `sub`,
  `write`), in place and with no call of the kernel: the block's
  address is known to the process's trusted library only.
- **A message is a tag, one integer, and maybe a block or an
  endpoint.**

## The check

`mini-mk check` boots the image under mini-qemu and under QEMU and
compares the serial line with `tests/boot.expected` (34 lines:
processes started and waited for, a second process of a running
program refused, a block that changed hands, a message refused by its
contract). `bench`'s lines are times, not compared. It is in none of
ix's suites: run it here, by hand, for each board. Never run on the
boards themselves.

## The numbers

`./numbers.sh`, the guest's instructions under mini-qemu (2026-10-07;
nothing was made fast):

| | a call | a yield | a message there and back | the same with a block of 1 MB | a byte read and one written | a process made and ended |
|---|---:|---:|---:|---:|---:|---:|
| the Pi 1 | 520 | 16,257 | 27,406 | 30,744 | 708 | 11,064,525 |
| the Pi 4 | 602 | 7,918 | 19,207 | 22,518 | 695 | 11,929,293 |
