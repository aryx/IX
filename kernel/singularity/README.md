# kernel/singularity/

mini-singularity: Microsoft Research's Singularity (2003-2010) as its
papers tell it, written in OCaml, running on the bare Raspberry Pi 1
and Pi 4: **an operating system whose processes are isolated by the
language, not by the hardware**. Beside mini-xv6 and mini-9pi, which
isolate theirs by the MMU, on the same boards with the same compiler.
Its plan, with what was decided and what each stage found, is
[`docs/plans/done/plan_system_singularity.md`](../../docs/plans/done/plan_system_singularity.md),
which also lists what is left to do.
**[`tutorial.md`](tutorial.md)** walks through it by its own files.

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
- **Manifests**: a program says what it needs of the machine and is
  given that and no more. A driver is a process as the others.

**What is lost, not to be hidden**: Sing# checks contracts and
ownership when a program is compiled. OCaml cannot, and here they are
checked when it runs: a message its contract does not allow ends its
sender, a block used after it was sent raises. And what keeps a
program from another's memory is a look at its source when the image
is built (`mini-singml -safe`: no `external`, no `Obj`, a list of
modules), where Singularity verified the compiled code: mini-ml's type
checker and the libraries a program is linked with are trusted.

## Running it

    ./mini-pi mini-singularity      the Pi 1, its console in this terminal
    ./mini-pi mini-singularity4     the Pi 4 (arm64)

from ix's root (`-q`: QEMU in mini-qemu's place; `-n`: no build). Or
here, by hand:

    mini-mk              _mk/7/kernel/singularity/kernel8.img (the Pi 4)
    mini-mk O=5          _mk/5/kernel/singularity/kernel.img (the Pi 1)
    mini-mk run          under mini-qemu (Ctrl-A x quits)
    mini-mk check        a session at its shell, under mini-qemu and QEMU (O=5: the Pi 1's)
    ./numbers.sh         what a call, a yield, a message and a process cost

It is built by ix's own tools only (mini-mk, mini-ml, mini-cc,
mini-asm, mini-ld, and its own mini-singml: `PATH=../../bin:$PATH`),
which want the standard library built first (`mini-mk` in `lib_core/`;
`mini-pi` does it).

The kernel starts `init`, which starts the console's driver and the
shell. At `sing> `: `help`, `ps`, `exit`, or a program's name
(`hello`, `selftest`, `crash`, `bench`...). The machine stops when no
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
| `Process` | 238 | the processes: a program's copy put at its address and called; the handles, what a manifest grants; create, start, join, yield, exit, stop; the scheduler, cooperative |
| `Abi` | 179 | the 21 functions a process may call, numbered |
| `Channel` | 113 | endpoints, messages, the contract checked at each send |
| `Exchange` | 61 | the exchange heap: blocks with one owner |
| `Main` | 12 | the boot: init started, then the scheduler |
| `cross.c`, `cross_arm.s`, `cross_arm64.s` | 280 | the crossing between two programs: the registers and stacks it keeps |
| `singml/` | 699 | mini-singml: `Description` (a declaration read), `Output` (its module written), `Safe` (a program's source looked at), `Manifest` (a manifest read, the module Given), `CLI` |

(Lines of the `.ml`, 2026-10-07; each has a `.mli` that says what it
is.)

`lib/`: what a program is linked with. `Sip` (the kernel's calls, for
a program), `Contract` (a contract as a value: the kernel's too),
`sip.c` (the system under the C library and the run-time system, and
the table of the blocks a process owns), `malloc.c`, the start in
assembly.

`contracts/`: the contracts, each a module over `Sip` and `Contract`:
an end's own type, an operation a message. `Pong.ml` and `Pong.mli`
are **written by hand, and kept so, to be read**: they are what a
contract's module is. The others are declarations (`Intro.contract`,
`Console.contract`), made into such a module by mini-singml when the
image is built.

`singml/`: mini-singml, what this system asks of the language beyond
mini-ml, as a program of its own over mini-ml's parser: nothing of it
is in `languages/ml`. A contract's declaration made its module, and a
program's source refused if it is not safe (both below).

`programs/`: a directory a program, its `Main.ml` and, if it needs
something of the machine, its `Main.manifest`. `init` (the system's
wiring); `console` (the serial line's driver); `shell`; `hello`;
`tick` and `tock`, which run in turn; `ping` and `pong`, a client and
a server; `rogue`, a client that breaks the contract; `selftest`,
which tries the kernel with those; `crash`, which fails; `bench` and
`nothing`, for the numbers.

`machine/` (links): `Machine`, the boards' C and assembly, mini-xv6's
slots for a process's kernel stack.

## A contract's declaration

In OCaml's syntax, read by mini-ml's own parser. The messages are the
constructors of its variant types; the states are its `let rec`, the
first the start, each said from the exporting end (the server's), as
Sing#'s. Pong's (`singml/tests/Pong.contract`; in Sing#'s way,
`contracts/Pong.mli`'s header):

    type request = Ping of int | Text of Sip.block * int | Lend of Sip.block
    type reply = Ready | Pong of int | Thanks | Return of Sip.block

    let rec start = send Ready; serve
    and serve = function
      | Ping _ -> send Pong; serve
      | Text _ -> send Thanks; serve
      | Lend _ -> send Return; serve

`function | M _ -> s` is a message received (sent by the client),
`send M; s` one sent, `s1 || s2` one or the other sent, `()` nothing
more. `mini-singml -o dir Name.contract` writes `Name.ml` and
`Name.mli` (`mini-singml -h`). It refuses a state where both ends may
send, a message no state names, an argument that is not an int, a
`Sip.block` or another contract's end.

    singml/tests/check.sh    the made Pong against the hand-written one
                             (its states, its interface; the programs
                             compile with it), and what is refused

## A safe program

A process is in the kernel's address space: its own code must be
nothing that makes an address, or looks at a value as what it is not.
The mkfile runs `mini-singml -safe` on each program of `programs/`
before mini-ml compiles it, and the image is not made if one is
refused:

    programs/tick/Main.ml:13: module Obj is not one a process may name

Refused: `external`; a module that is not one of the standard
library's that only compute (`List`, `String`, `Printf`, `Hashtbl`...:
`singml/Safe.ml`'s list), `Sip`, `Contract`, a contract, or one the
program defines (so `Obj`, `Marshal`, `Unix`); a name that starts with
`unsafe_`; `input_value`; an extension (`[%...]`). `lib/` and the
contracts are not looked at: they are the trusted part a program is
linked with, as mini-ml's runtime is.

**What this does not prove**: that mini-ml's type checker is sound,
and that each function of the allowed modules is safe for any
argument. Neither was audited.

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
- **No name service**: a process is given its endpoints by its
  parent. A driver that ends is not started again.
- **What a program prints goes by the kernel's debug line**, not
  through the console's driver, which serves the shell.

## The check

`mini-mk check` boots the image under mini-qemu and under QEMU, types
a session at the shell on the serial line (`tests/session.cmds`:
`help`, `ps`, `hello`, `crash`, a name that is none, `selftest`,
`exit`) and compares what the console shows with
`tests/session.expected` (66 lines). `selftest` is a program that
tries the kernel: processes started and waited for, a second process
of a running program refused, a block that changed hands, a message
refused by its contract. It is in none of ix's suites: run it here, by
hand, for each board. Never run on the boards themselves.

## The numbers

`./numbers.sh`, the guest's instructions under mini-qemu (2026-10-07;
nothing was made fast):

| | a call | a yield | a message there and back | the same with a block of 1 MB | a byte read and one written | a process made and ended |
|---|---:|---:|---:|---:|---:|---:|
| the Pi 1 | 544 | 16,297 | 27,541 | 30,879 | 712 | 11,212,389 |
| the Pi 4 | 642 | 7,999 | 19,489 | 22,803 | 695 | 12,084,840 |
