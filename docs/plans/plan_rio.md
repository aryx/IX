# Plan: mini-rio, a window system in OCaml on mini-9pi (`windows/`)

The author (2026-10-05): "let's start our work on mini-rio, in a
windows/ folder. But first, let's make it easy to build our own fs.img
instead of relying on principia's one."

mini-rio is ix's window system, in OCaml, running **on mini-9pi with
ix's own programs**: mini-rc in its windows, a disk ix makes, no binary
of principia's. Today mini-9pi ([`plan_9pi.md`](plan_9pi.md)) runs
principia's C programs (rc, dossrv, rio) from principia's SD card
(`~/principia/qemu-sd.img`), and ix's programs are Linux's. So most of
this plan is what comes before `windows/`: ix's programs on Plan 9,
threads, a disk.

Its references: principia's rio (`~/principia/windows`, C, libthread)
and the author's own in OCaml (`~/xix/windows`, 3,465 lines, OCaml's
`Thread` and `Event`).

## The survey (2026-10-05, checked)

- **ix's programs are Linux's.** `lib_core/libc/syscall/os/` has only
  `linux`; `lib_core/system/Unix.ml` is Linux's system calls by their
  numbers; a program is linked `-H7` (ELF). mini-9pi runs Plan 9's
  a.out and Plan 9's system calls.
- **What is already there for Plan 9**: `mini-ld -H2` writes Plan 9's
  a.out; goken's libc (`~/goken/lib_core/libc`, which `lib_core/libc`
  is copied from) has a `GOOS=plan9` for arm (`syscall/os/plan9/`,
  `os/plan9/`: about 1,400 lines); mini-5i runs a Plan 9 a.out on the
  host (`machine/Plan9.ml`), so a program is tested before a kernel
  runs it.
- **mini-9pi boots without a card** already: its bootdir is in the
  image (`conf/mkbootdir.py`; `tests/boot-b.rc` as `/boot/boot`), with
  principia's programs. On the Pi4 its processes are arm's (AArch32 at
  EL0): there is no arm64 process yet (`syscalls/arm64/` has `Ureg`
  only).
- **The build has three Python scripts** (`kernel/9pi/conf/`:
  `mkbootdir.py`, `kerndate.py`, `mkpixdata.py`).
- **The firmware.** The Pi1's is in principia (`MISC/pi/`:
  `bootcode.bin`, `start_cd.elf`, `fixup_cd.dat`, `config.txt`), on the
  card's FAT partition, the first. The Pi4's loader is in its EEPROM
  and reads `start4.elf`, `fixup4.dat`, `bcm2711-rpi-4-b.dtb` and
  `config.txt` from the same kind of partition (from memory: to check
  on the board). One `config.txt` serves both, by its `[pi1]` and
  `[pi4]` sections.
- **Threads.** principia's rio: 12 `threadcreate`, 14 `proccreate`, 25
  `chancreate`, 9 `alt`. xix's: 10 `Thread.create`, and `Event`'s
  `channel`, `send`, `receive`, `sync` (19), `select`, `wrap`. xix on
  Plan 9 runs ocaml-light's threads, whose scheduler waits by `select`,
  which APE emulates over Plan 9: layers kept for a library written for
  Unix. mini-ml has no threads.
- **A file system in the kernel**: `kernel/xv6/Fs.ml` reads and writes
  xv6's format in place, on a disk that is RAM. `tiny/TinyMkfs.ml`
  makes tiny-os's images (xv6's format less the log; a FAT of its own).

## Decisions (the author, 2026-10-05)

1. **The kernel is mini-9pi; ix's programs get a Plan 9 target.** A
   window system needs `/dev/draw`, `/dev/mouse`, mounts and a
   namespace a process: Plan 9's, not xv6's.
2. **Not an exact twin anymore** ("we don't have to be an exact twin"):
   mini-9pi may have what 9pi has not, where it teaches. First, a file
   system built in.
3. **Two file systems, on one card**: a FAT partition first (the
   firmware wants it; the kernels are files in it), served by a
   **dossrv in OCaml**, a user program; then a partition in a format of
   ours (xv6's, the simple one), served by the **kernel** ("we can show
   both a builtin filesystem and a userspace filesystem; great teaching
   value").
4. **A kernel that boots alone** (`qemu -kernel`, no card): mini-rc and
   a few files in the image.
5. **No Python in the build** ("at some point we will want to build
   m-ix from inside m-ix itself"): the tools that make an image are
   OCaml, compiled by mini-ml. Python stays for tests.
6. **The Pi1 first; both boards in the end**, each with its own
   programs: arm on the Pi1, **arm64 on the Pi4** (not arm programs at
   EL0, as today).
7. **Threads thought again, not libthread ported**, and one program for
   OCaml 4.14 and mini-ml ("the simplest design that can get us a
   working mini-rio working both under OCaml and mini-ml under
   mini-9pi"): below.

Open: are the firmware's files committed (1 to 3 MB), or fetched by a
script at a version?

## Threads: the design

What a window system waits for is a handful of streams, known when it
starts: the mouse, the keyboard, the 9P requests, a timer, a child's
end. The rest is threads talking by channels. So no `select` on
descriptors, no descriptor that does not block, no process sharing
memory (mini-ml's collector moves blocks: two processes on one heap
would need a lock around everything).

Three pieces:

- `Thread`: `create`, and little else; OCaml's names.
- `Event`: `channel`, `send`, `receive`, `sync`, `select`, `wrap`
  (what xix's rio uses); OCaml's names.
- one module of ix's (`Source`, the name to settle):
  `reader : Unix.file_descr -> int -> bytes Event.channel`, and a
  timer: a descriptor's reads, as messages on a channel.

The rule: **a thread never reads a descriptor that may block; it
receives from a source's channel** (what rio's C does by hand with its
mouse and keyboard threads).

| | OCaml 4.14 | mini-ml |
|---|---|---|
| `Thread`, `Event` | OCaml's threads library | ix's, in `lib_core/`: cooperative, a switch only at `Event.sync` |
| `Source.reader` | a thread that reads and sends | a process with its own memory, that reads and writes each read, with its length and the source's number, to one pipe |
| the scheduler's wait | none of ours | when every thread waits: one read of that pipe |

mini-ml's side asks `fork` (`rfork`), `pipe`, `read`, `write` of the
system: the same code on Linux and on mini-9pi, nothing new in the
kernel, tested on the host first. A thread is a value stack (the
runtime switches them already, for a kernel's processes: `ml_stack`,
`ml_stack_switch`) and a machine stack (a few lines of assembly a
machine). No `Mutex`, no `Condition`: nothing runs between two `sync`.

The caveat: OCaml 4.14's threads are preemptive, so code that counts on
"nothing runs between two `sync`" may race there. The discipline: state
is shared by channels only. Where that costs too much, 4.14's build is
the one that checks types, mini-ml's the one that runs.

What it leaves open (the author: "hopefully it does not close doors to
further extensions and possible preemptive scheduling"): the names are
those of OCaml's library, which is preemptive, so what is under them
may change without a program changing. A preemptive scheduler for
mini-ml would be a timer's note that switches at a safe point (the
runtime already runs a signal's handler where a program waits);
`Mutex` and `Condition` would be added then, for the programs that
want them. The discipline above (state shared by channels only) is
what keeps a program right the day its threads are preempted: it is
checked today by the 4.14 build. `Source` hides how a read waits: a
process today, a kernel's wait or a thread of the system's tomorrow.

Not taken: libthread ported (C switching stacks under the runtime, and
`proccreate`'s shared memory); a `select` in mini-9pi (the shortest
library, but mini-rio would run on mini-9pi only, and it is not Plan
9's way: "Plan 9 has no select, a process waits for you" is the
lesson).

## The stages (each checked before the next)

- **1. A Plan 9 target, on arm.** `lib_core/libc`'s Plan 9 files
  (goken's), the runtime for Plan 9 (its heap sized for a Pi1; a
  channel's read), a build beside Linux's (`mini-mk O=5 OS=plan9`, the
  names to settle), linked `-H2`. Checked: hello in OCaml under mini-5i,
  then from mini-9pi's bootdir.
- **2. `Unix` on Plan 9, and mini-rc.** The functions mini-rc names
  (`fork`, `execve`, `wait`, `pipe`, `dup2`, `openfile`, `read`,
  `close`, `chdir`, `fstat`, `getpid`, `kill`, `environment`: about
  20), each a system call of Plan 9's, as `Unix.ml` is Linux's; the
  environment in `/env`, a child's status a string. Checked: mini-rc's
  differential tests under mini-5i; then **mini-rc as `/boot/boot`'s
  shell, no card**, and a few of ix's programs in the bootdir
  (decision 4), the bootdir made by an OCaml tool (decision 5).
- **3. The card.** A host tool in OCaml: an MBR, a FAT with the
  firmware, `config.txt` and the kernels, a second partition. Checked:
  QEMU and mini-qemu take it as the SD card; principia's dossrv reads
  its FAT; then the Pi1 boots from it.
- **4. Threads.** `Thread`, `Event`, `Source` for mini-ml, as above.
  Checked: the same test programs under OCaml 4.14 and mini-ml, on
  Linux, then on mini-9pi.
- **5. mini-dossrv.** A 9P server library (the kernel's `P9` and
  `P9_wire`, shared), and the FAT served: the first program with
  threads, and the library mini-rio needs. Checked: the stage-C session
  of mini-9pi with it in the place of principia's dossrv.
- **6. The file system in the kernel.** A device of mini-9pi's serving
  the card's second partition in xv6's format (`kernel/xv6/Fs.ml`'s
  code, over blocks of the card: a cache of blocks, or the partition
  read whole at the boot, to choose there); the root from it.
- **7. `windows/`: mini-rio.** After a survey of its own (rio's and
  xix's parts, libdraw's client side in OCaml, what `/dev/draw` of
  mini-9pi is asked): the plan's second half, written then.
- **8. The Pi4, arm64.** arm64 processes in mini-9pi (the a.out of 7l,
  the system call from AArch64's EL0, `Ureg`), the libc's Plan 9 files
  for arm64, the Pi4's firmware on the card.

## Status

2026-10-05: plan written, with the author.

2026-10-05, **stage 1 done**: a program of ix's, in OCaml, runs on
mini-9pi. `mini-mk O=5 OS=plan9` builds for Plan 9 on arm, under
`_mk/5-plan9`, beside Linux's (`mkfiles/mkconfig`'s `OS`; `mkprog`
links `-H2`). The pieces:

- `lib_core/libc`: goken's Plan 9 files, copied as they are (15 files,
  1,272 lines; its README), chosen by `lib_core/mkfile`; one new file
  of ix's, `ix/syscall6_plan9_arm.s` (a call of Plan 9's by its number,
  for stage 2's `Unix`).
- The runtime (`-Dplan9`, +95 lines): the libc's calls where Linux's
  were made by number; `Sys.command` by `/bin/rc` and `await`'s line
  (goken's `wait` asks `tokenize` and the runes: 550 lines, not
  taken); `exit n` is the status "n" (rc's `exit 3`); a heap of 64 MB a
  half and a value stack of 4 MB (a process of mini-9pi's has 512 MB
  of addresses). Left for stage 2, said in the code: notes (the
  signals), a read's interruption, `Sys.time`.
- mini-5i: the VFP on for a Plan 9 program (mini-ml's floats; 9pi
  gives it), a number's exit string its status.

Checked: `OS=plan9 languages/ml/tests/run.sh 5` runs tests/modern's
programs as Plan 9's a.out under mini-5i: 18 of 24 pass. The six:
`signals`, `unix_calls`, `unix_sockets` (stage 2: `Unix` is Linux's);
`files` (`Sys.command` wants a `/bin/rc` for Plan 9, the host's is
Linux's; `Sys.time`); `marshalled` (fails on arm Linux too);
`float_formats` (right as far as it gets: 5 minutes under mini-5i, an
interpreter, for the run's 20 seconds). And on the kernel:
`kernel/9pi`'s `make check-ix` puts `tests/hello` (OCaml: its
arguments, a float, `exit 3`) in stage B's bootdir and runs its
session under mini-qemu and QEMU on the Pi1, the console as
`tests/session-ix`. Not run again: mini-5i's own Plan 9 tests
(`machine/tests/plan9.py`, which wants goken's corpus); `make
test-lite` passes.

Next, stage 2: `Unix` on Plan 9, mini-rc.
