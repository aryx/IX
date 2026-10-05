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

8. **The firmware's files in the repository** (they are small),
   under `kernel/firmware/`, "with a clear README.md stating the origin
   of the files".
9. **`Sys.os_type`** is how a program of ix's knows it runs on Plan 9,
   for the few lines that differ there.

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

2026-10-05, **stage 2, mini-rc on mini-9pi** (the bootdir's tool in
OCaml is left: below). mini-rc and mini-ed build for Plan 9 with no
line of theirs changed, and mini-rc is mini-9pi's boot shell.

- `lib_core/system/plan9/Unix.ml` (300 lines, its interface 93; Linux's
  is 523 and 187): OCaml's names, each a system call of Plan 9's by
  its number, as Linux's `Unix.ml` is. An interface of its own, the
  part a shell and an editor ask: what is not there (sockets, `select`,
  the terminal's settings) a program does not compile with for Plan 9.
  `mkfiles/mkconfig`'s `UNIXDIR` chooses it.
- Where Plan 9 is not Unix, and what was done (`Unix.mli` says it):
  an error is the kernel's string (kept for `error_message`, and
  mapped to the errno a program matches); a process's last words are a
  string (a number, or one at its end, is `WEXITED n`; a note's name
  `WSIGNALED`); the environment is `/env` (read as plan9port's rc has
  it on Unix; written by `execve`); `fork` is Plan 9's (one
  environment for a shell and its children: with a copy, RFENVG, a
  child's write to `/env/y` by a redirection was lost); close-on-exec
  is the open file's in Plan 9, a descriptor's in Unix (a redirection
  opened so, then `dup2` to 1, was closed at exec: `echo > '#c/swap'`
  failed), so `Unix` keeps the descriptors itself and closes them at
  exec.
- The runtime (+35): notes. One handler (`notify`) notes interrupt,
  hangup and alarm as signals, for the stdlib to run their handlers
  where a program waits, as on Linux; a read a note interrupts says so.
- `libc/ix/syscall6_plan9_arm.s`'s frame was one word short (it wrote
  over its caller's return address: stage 1's hello made no call
  through it).

Checked: `languages/ml/tests/plan9/unix_calls.ml` under mini-5i (a
note to oneself and its handler, a pipe and a child, its status, an
error's words; `OS=plan9 run.sh 5`). A session of mini-rc's under
mini-5i with principia's programs on its path (pipes, redirections,
`` `{} ``, `&` and `wait`, `exit 4`). And on the kernel, `kernel/9pi`'s
`make check-ix`, the Pi1, under mini-qemu and QEMU: mini-rc as the
bootdir's `rc` (it runs `/boot/boot`, then the prompt), mini-ed as
`ed`, hello; **stage B's whole session (`tests/session-b.cmds`) gives
the C rc's console** but two files of ours in `/boot` and three names
of `/env` (`tests/session-ix-b`); `make test-lite` passes. Not checked:
a note from the keyboard (Delete at the prompt) on the kernel.

2026-10-05, **stage 2 done** (the author: "Sys.os_type looks fine to
me; let's port mkbootdir.py to OCaml for now; we can always refine
later"; the firmware "under kernel/firmware/, with a clear README.md
stating the origin of the files"):

- **`Sys.os_type`** is "Plan9" for a program built for Plan 9, and
  OCaml's "Unix" on Linux (the runtime said "Plan9" on both; nothing
  read it). **`Sys_plan9`** (`lib_core/commons/`, its interface; two
  files, as `Unix`: Plan 9's in `system/plan9/`, and one that has
  nothing to say for every other system, dune's builds too): what
  OCaml's Unix has no name for. Today `last_words`, a child's last
  words as the kernel gives them; mount, bind and rfork's flags will
  come here, for mini-dossrv and mini-rio.
- mini-rc's two lines for Plan 9: `$status` is the child's words
  ("hello 17: 3", as Plan 9's rc), and no `$PATH` beside `$path`.
  Stage B's session now differs from the C rc's by `/boot/ed`,
  `/boot/hello`, and three names of `/env` the C rc writes and mini-rc
  does not (`*`, `cflag`, `fn#sigexit`).
- **mini-mkbootdir** (`kernel/tools/`, 45 lines of OCaml, built by dune
  and by ix's tools) in the place of `conf/mkbootdir.py`, for the
  Makefile and the mkfile. The format is still Devroot's lines and
  bytes; it need not stay (the author: "does not have to match what
  was done by the python program; what matters is it implements the
  goal it was assigned to, which is to help prepare a kernel with
  embedded programs in it"). Not a marshalled list for now: Devroot
  serves the files where they are in the image, and the kernel's
  runtime has no Marshal. Two Python scripts are left in the build,
  both about principia: `kerndate.py` (9pi's date, for the consoles to
  match) and `mkpixdata.py` (its colour map and font).
- `Sys.time` on Plan 9: `/dev/cputime` (0 under mini-5i, which has no
  such file).
- **`kernel/firmware/`**: the Pi1's three files (616 KB), from
  principia, with a README (their origin, Broadcom's license, their
  sums). The Pi4's are to add.

Still so, of mini-rc on Plan 9: `/env` is written whole at each exec,
by the child (`Unix.execve`), and a variable set after the start and
unset since stays there; Plan 9's rc keeps `/env` itself and writes
what changed, before it forks. And the bootdir's other programs are
principia's (echo, ls, bind, mount...).

2026-10-05, **the bootdir is ix's own** (the author: "let's replace
the rest of the bootdir with OCaml versions; we can start a utilities/
folder like in principia and xix, with similar subfolders"; "add an
entry in mini-pi to boot this kernel with just mini-rc embedded, and
rename the existing one with a -principia suffix"):

- **`utilities/`**: `files/` (mini-ls, mini-cat), `misc/` (mini-echo),
  `namespace/` (mini-bind, mini-mount), each one file, twins of
  principia's C (`utilities/files/ls.c`, `cat.c`, `shells/misc/echo.c`,
  `kernel/files/user/bind.c`, `mount.c`), built by dune and by ix's
  tools. `utilities/tests/differential.sh`: each against principia's
  own arm binary, both under mini-5i, 51 cases, the same output,
  errors and status. Not copied: `ls -t` with equal times (ls.c's
  qsort is not stable), ls's local time (`/env/timezone`), mount's
  authentication (always its `-n`).
- **Capabilities** (the author: "Cat.ml should require Cap.open_in!",
  "Ls.ml should require a Cap.readdir"): each program's `caps` says
  what it does, and each access is by a function that takes the
  capability: `FS.open_in_fd`, `Sys_plan9.bind` (`Cap.bind`), `mount`
  (`Cap.mount`), `dirstat` and `dirread` (`Cap.readdir`),
  `Console.stdout_fd`.
- **`Sys_plan9`** has what they ask: `exits`, `bind`, `mount`, a
  directory's entry as 9P has it (`dir`, `dirstat`, `dirread`); off
  Plan 9, an entry is what Unix's stat can fill, and bind and mount
  fail. Plan 9's `Unix` has `time` (`/dev/bintime`) and `gmtime`.
- **xix's `Exception`, `Exit`, `Fpath_`, `Chan`, `Cmd`, `FS`** in
  `lib_core/commons/` (its README: what was changed, two files). A
  program's `main` gives an `Exit.t`: `Err "usage"` is Plan 9's
  `exits("usage")`.
- mini-rc has Plan 9's rcmain inside, for Plan 9 (`'#d/0'` for the
  standard input): `rc` runs without `-m /boot/rcmain`.
- **`kernel/9pi`'s `make ix`**: `kernel-pi1-ix.img`, the bootdir
  mini-rc, mini-ed, the five utilities, hello, and `conf/boot.rc`
  (ix's: the devices bound, then rc); nothing of principia's in it (its
  date is `KERNDATE_IX`; the pixels' tables still come from principia,
  `conf/mkpixdata.py`). `make check-ix`: hello's session and stage B's
  (`tests/session-ix-b.cmds`), under mini-qemu and QEMU. Stage B's
  console differs from the C programs' by the names in `/boot`, three
  names of `/env`, and the date. 5.7 MB: each program is 570 to 740 KB,
  the whole stdlib linked in each (to trim: a program's own units).
- **`mini-pi mini-9pi`** (and `mini-9pi4`) boots it;
  `mini-9pi-principia` and `mini-9pi4-principia` are the former
  entries.
- **The Pi4**: its kernel did not turn the VFP on for an AArch32
  process (mini-rc died at its first float: principia's C programs
  have none at their start). `FPEXC32_EL2`'s EN, in `lib/pi4/start.s`
  and `l.s`; mini-qemu's Pi4 has the register, and gives an AArch32
  process the VFP by it. `make BOARD=pi4 ix` then gives the Pi1's
  console for hello's session under mini-qemu, and boots under QEMU.

2026-10-05, **stage 3, the card, as far as an emulator says**:
**mini-mkcard** (`kernel/tools/Mkcard.ml`, 158 lines, built by dune and
by ix's tools: the same card from both) writes an SD card's image: an
MBR; at 1 MB a FAT16 partition (32 of the card's 64 MB by default;
clusters of 2 KB; files at the root, in consecutive clusters, names of
8.3 characters: no long names) with the files given; then a second
partition to the card's end, zeros or an image given (`-fs`), of type
0xda ("data"): stage 6's place. `kernel/9pi`'s `make card` puts there
the Pi1's firmware (`kernel/firmware/pi1/`), `conf/config.txt` and the
image of `make ix` (as `mini9pi1.img`): `build/card.img`.

Checked (`make check-card`): by the host's tools (sfdisk: the two
partitions; fsck.vfat: the FAT; mcopy: the kernel read back, the same
bytes); and by **principia's fdisk and dossrv** on mini-9pi
(`tests/boot-card.rc` as `/boot/boot`, `tests/session-card.cmds`),
under mini-qemu and QEMU: fdisk finds `part dos 2048 67584` and `part
other 67584 131072` in the MBR, dossrv serves the FAT (its five files,
their lengths and dates), `config.txt` is read, a file is written and
read back. `mini-pi mini-9pi` gives the kernel this card (nothing of
ix's reads it yet: stage 5's mini-dossrv).

**Not checked: a real Pi1 booting from it** (`dd if=build/card.img
of=/dev/sdX bs=1M`: the author's boards). What may matter there: the
FAT is a FAT16 (type 0x0e; principia's card is a FAT32, 0x0b);
`config.txt` names the kernel in a last `kernel=` line under no
`[pi1]` (this firmware is 2015's); mini-9pi itself was only run under
emulators. And not done: the Pi4 (its firmware's files, to fetch; its
kernel as a raw image, where QEMU takes the ELF), then `[pi4]` in
`config.txt`.

2026-10-05, **stage 4 done: threads, channels and sources, the same
program with OCaml's and with mini-ml's**.

- **The runtime** (+83 lines) has three primitives: `thread_new` (a
  thread's two stacks in one piece of memory, 256 KB for the machine's
  and 32,768 values; the function it starts with is the first value of
  its stack, a root as the rest), `thread_switch`, `thread_free`. The
  value stacks are the kernels' (`ml_stack`, `ml_stack_switch`: the
  collector scans them all); 64 threads at once, a finished one's
  number used again.
- **The switch** is 9 instructions an architecture, in the start object
  (`Gen.startup`'s `ml_swtch`, +11 lines): the machine's stack pointer,
  the return address and the value stack's register saved in the
  thread's context, another's put back. Nothing else: a switch is a
  call, and 5c's and 7c's C keeps no register across a call.
- **`lib_core/concurrency/`** (for mini-ml; dune's builds take OCaml's
  threads library): `Thread` (86 lines: the scheduler, in OCaml: a
  queue of those that can run, `sleep` and `wakeup`, `join`, `exit`),
  and **xix's `Mutex`, `Condition` and `Event`, ocaml-light's, as they
  are** (written with `Thread.sleep`, `wakeup` and `critical_section`:
  `Thread` has them, beside OCaml's names). So decision 7's "no
  `Mutex`, no `Condition`" is not kept: they cost nothing, and
  `Event` is written with them.
- **`Source`** (`lib_core/commons/Source.mli`: `reader`, `timer`): for
  OCaml's threads (`commons/Source.ml`, 18 lines, the dune library
  `ix_threads`), a thread reads and sends; for mini-ml's
  (`concurrency/Source.ml`, 97 lines), a process a source, frames on
  one pipe, read by the scheduler when no thread can run
  (`Thread.idle`), a pump thread a source to send on its channel. The
  processes are ended with the program (`at_exit`).

Checked: `languages/ml/tests/modern/threads.ml` (a rendezvous, twenty
threads on a channel, `select`, `wrap`, `poll`, a mutex and a
condition, 200 threads made and ended) prints the same with OCaml 4.14
and with mini-ml on arm64 and arm (with `ML_HEAP=64` too: collections
while threads wait) and as a Plan 9 program under mini-5i.
`lib_core/commons/tests/sources.sh` (a pipe's reads as messages, its
end, two sources chosen between, a timer): the same lines with OCaml's
threads, mini-ml's on arm64, and on Plan 9 under mini-5i. Both
programs are in mini-9pi's bootdir and run on the kernel (`make
check-ix`, the Pi1, mini-qemu and QEMU): threads, and sources whose
processes are rfork's.

What is so, to know: a program whose threads never all wait reads no
source (the pipe is read when the scheduler is idle); a thread that
waits in a system call stops the others; a thread's stacks have no
guard (a deep recursion in one writes past them); `Thread.delay` is
not there (a timer source is). The 64 threads at once are the
runtime's `STACKS`: rio makes a thread a window.

2026-10-05, **stage 5, mini-dossrv reads**: the card's FAT is files
on mini-9pi with ix's own programs only.

- **`lib_9p/`**: `P9` (9P2000's messages, as the kernel's `P9` and
  xix's `Protocol_9P`: a tag and a request or a response, variants; a
  file's entry is `Sys_plan9.dir`), `P9_wire` (their bytes, both ways,
  167 lines), `P9_server` (a server's loop, 137 lines: the fids, a
  directory's reads in whole entries, the walk's rule; a file system
  is a record of functions on its own files, `'f fs`; `post`, a pipe's
  end in `/srv`). One request at a time: no thread yet (a server that
  waits, rio, will want them).
- **`kernel/9pi/filesystems/user/dossrv/`** (principia's place for it;
  the author: not "another toplevel directory filesystems/"): `Fat` (FAT12, FAT16, FAT32, VFAT's long
  names, read: 148 lines) and `Dossrv` (mini-dossrv, 75 lines: `dossrv
  [-f device] [name]`, `/srv/dos`, a mount's spec the device's file).
  Reading only: a file opened to be written is refused ("read only
  file system").
- A name's case (the author: "if the filename was using some uppercase
  letters, then display them", and not otherwise): a name of 8.3
  characters is shown as it was written, by Windows NT's two bits
  ("the name was in small letters", "its extension was"); Plan 9's
  dossrv shows capitals always. mini-mkcard sets the bits from the
  names it is given (each part in one case).

Checked: on principia's own card (a FAT32 of 512 MB, long names),
mini-dossrv and principia's dossrv give the same 284 lines for the same
session (the root and two directories listed long, `/arch/arm/bin`'s
names, a file read, a name in the other case) but the names' case.
`make check-card` has a session of mini-dossrv's on ix's card
(`tests/session-card-ix.cmds`: the partition said by hand, there is no
fdisk of ix's; dossrv, mount, `ls -l`, `cat`, a name not there, a
write refused), under mini-qemu and QEMU. Found on the way: mini-ls
did not flush what it listed before an error was said (ls.c's Bflush).

2026-10-05, **the card mounted at the boot**: **mini-fdisk**
(`kernel/9pi/devices/storage/user/fdisk/`, 70 lines: fdisk's `-p`
only, the MBR's four entries as `part name start end` lines, a write
each, for the disk's ctl file; the same lines as principia's fdisk for
ix's card and for principia's). `conf/boot.rc`: when there is a card,
`fdisk -p /dev/sdM0/data > /dev/sdM0/ctl`, and when it has a FAT,
dossrv and `mount -c /srv/dos /root /dev/sdM0/dos`. `mini-pi mini-9pi`
boots to rc with the card's files in `/root`; with no card, as before.
`make check-card`'s session of ix's programs no longer says the
partition by hand.

To do in stage 5: writing (create, write, remove, wstat: the FAT's
clusters allocated). And **the
kernel's `P9` and `P9_wire` (147 lines, the client's half) are
`lib_9p`'s twice** (the author: "should we factorize?"): one format,
two halves; for the kernel to take `lib_9p`'s, its messages and bytes
must ask nothing of `Unix` (the descriptor's read moved out; a
file's entry a type of `P9`'s own, or the kernel's), and pass
ocaml-light's build.

## Stage 7, `windows/`: the survey (2026-10-05, checked)

What there is to start from:

| | lines | what |
|---|---:|---|
| principia's rio (`~/principia/windows/rio/`) | 8,170 of C | the reference: its fileserver (9p.c, fsys.c), its threads (mouse, keyboard, a window's), the terminal, scrolling, snarf; over libdraw, libframe, libcomplete, libplumb, libthread |
| xix's orio (`~/xix/windows/`) | 3,465 of OCaml | the author's rio in OCaml, literate (syncweb's markers in the code, `docs/Intro.nw`): `Terminal` 639, `Threads_fileserver` 390, `Window` 304, `Cursors` 301, `Wm` 275, `Threads_window` 262, `Thread_mouse` 211... Its limits, by its own header: no unicode, one ASCII font, a simple terminal |
| xix's `lib_graphics/` | 2,850 of OCaml | the client's side of `/dev/draw`: `draw/` 2,112 (`Display`, `Image`, `Draw`, `Font`, `Text`, `Layer`, `Draw_marshal`, `Draw_rio`...; 609 are a font's data), `input/` 329 (`Mouse`, `Keyboard`, `Cursor`), `ui/` 249 (menus), `geometry/` 160 |
| ix today | | the kernel's side: `Devdraw` and the pixels in OCaml (1,759 lines); `lib_9p`; `Thread`, `Event`, `Source`; `Sys_plan9` (bind, mount) |

What orio asks of the system: `Event` (`sync` 22, `send` 15, `receive`
13, `wrap`, `select`), `Thread.create` 12, and 3 `critical_section`, 2
`sleep`, 2 `wakeup`; `Unix.openfile` 9, `read`, `write`, `dup2`,
`set_nonblock`; **`ThreadUnix`'s `read`, `write` and `pipe`** (a
thread's read that lets the others run: here a `Source`'s channel);
`Plan9` (qids, permissions, `mount`: here `Sys_plan9` and `lib_9p`'s
`P9`) and `Protocol_9P` (here `lib_9p`); `Cap.draw`, `mouse`,
`keyboard`, `fork`, `exec`, `chdir`, `open_in`, `mount`, `bind`; `Exit`,
`Common`, `Logs`.

Decided (the author, 2026-10-05, after "I'm fine with the import, but
maybe you could write better code than what I wrote? ... use even less
code?"; my answer: of orio's 3,378 lines 1,762 are code, its
`lib_graphics` 1,160 more, and what would go is what ix has already
(`Protocol_9P`, `Plan9`, the generic half of the file server, the
`ThreadUnix` glue), not the window system's own logic): **written
from scratch**, as the rest of ix ("since you wrote most of the code
in this repo, often inspired by principia and xix, we should do the
same here"), each file saying what it takes from xix or from Plan 9.
In steps, each checked on mini-9pi by its screen
(`kernel/9pi/tests/screenshot.py`):

- 7a. `lib_graphics/` (geometry, the display's connection, images,
  drawing, a font): a program that opens the display and draws
  rectangles, a line and text on mini-9pi.
- 7b. the mouse and the keyboard as `Source`s; a menu.
- 7c. `windows/`: the window system; its files by `lib_9p` (a request
  answered later, by another thread: to add to `P9_server`); a window
  with mini-rc in it.

To settle on the way: 64 threads at once (a window is a thread or two).

2026-10-05, **stage 7a done: `lib_graphics/`, written anew** (xix's
`lib_graphics/draw` and Plan 9's libdraw the models; each file says
so): `Point`, `Rectangle`; `Display` (the connection: `/dev/draw/new`
read, its data file; images by their numbers, a colour an image of one
pixel repeated; the messages kept and sent at `flush`; `alloc` 'b',
`free` 'f', `load` 'y'); `Draw` (`draw` 'd', Plan 9's one operation,
`fill`, `border`, `line` 'L'); `Font` (Plan 9's default font,
`Font_default`'s bytes: generated once from principia's `defont.c` by
`tools/defont.py`, in the repository; a string is drawn a character at
a time, the font's image the mask of a colour: not libdraw's cache of
characters in the kernel, which is for fonts of many subfonts). 300
lines with their interfaces, and 194 of font data.

Checked: **hellodraw** (`lib_graphics/tests/`: the author's
`hellodraw.c` and `hellodraw.ml` with ix's library: a magenta screen, a
thick line, "Hello Graphical World") in mini-9pi's bootdir; `kernel/9pi`'s
`make check-draw` compares the screen with `tests/hellodraw.ppm.gz`
under mini-qemu and QEMU: the same pixels. `conf/boot.rc` binds the
draw device (`#i`). Found: **the kernel panicked on a thick line**
("panic: sqrt": its C library's square root was a stub that the draw
device's `Memshape` calls; principia's rio never drew one in the
checks): `kernel/lib/libc.c` has one now. Not compared with the C
hellodraw's pixels: principia has no arm build of it.

Where programs go (the author: "an applications/ directory at the
toplevel? where we could put paint, colors, and other ported Plan 9
programs"): `applications/` when the first one is written (colors,
after 7b: it waits for the mouse); hellodraw stays a test of the
library (`lib_graphics/tests/`, as in principia and xix), hellorio will
be `windows/tests/`'s.

2026-10-05, **stage 7b done: the mouse, the keyboard, a menu**.
`lib_graphics/`'s `Mouse` (`/dev/mouse`'s reads, a `Source`; `receive`
an event of its place and buttons), `Keyboard` (`/dev/cons` raw, by
`/dev/consctl`'s "rawon"; a `Source`), `Menu` (`hit`: Plan 9's menuhit,
its colours; what it covers kept in an image and put back): 119 lines
with their interfaces. A program chooses between the mouse and the
keyboard by `Event.select`, in one thread.

Checked: **hellomenu** (`lib_graphics/tests/`) on mini-9pi's bare
screen; `kernel/9pi`'s `make check-menu` drives it with QEMU's USB
keyboard and mouse (`tests/graphics.py --steps tests/menu.steps`: the
right button's menu, an item shown as the mouse moves, a colour
chosen, a key typed, "exit") and compares its 8 screens
(`tests/menu.md5`): the same under mini-qemu and QEMU. So threads,
sources (two processes that read devices), the draw device and the
menu work together on the kernel.

**The USB keyboard and mouse** are a program's work in Plan 9 (usbd,
which writes what it reads of them to the kernel's `#m/mousein` and
`kbin`), and ix has none: `make ix-usb` is `make ix`'s image with
principia's usbd in its bootdir (`conf/boot.rc` starts it when it is
there), for the checks that need a mouse; `make ix` stays ix's own
programs. The author: "ultimately we may want usb mouse and keyboard
support directly in the kernel (and also a version in userspace, again
as a teaching tool to explain even a device driver can be in
userspace); to get there it's also ok to reuse some of principia's
binary if needed, in the mean time". Two things to write, then: the
kernel's (as mini-xv6's `Usbhost`), and usbd in OCaml.

2026-10-05, **stage 7c, a first mini-rio: a window with mini-rc in
it**. `windows/` (written anew; principia's rio and xix's orio the
models), 328 lines with their interfaces:

- `Terminal` (a window's text: lines in a rectangle, in one font; what
  is written goes at the end, the lines move up when it is full),
  `Window` (the image, its border, the process; the keys typed are a
  line at Enter, the lines wait for the console's reads), `Fileserver`
  (a window's files, `cons` and `consctl`, as a `P9_server.fs`), `Rio`
  (the desktop, the right button's menu: New, then a rectangle swept
  out; Delete, then a window pointed at; Exit; the left button gives a
  window the keyboard).
- **One loop, no thread of its own**: it chooses (`Event.select`)
  between the mouse, the keyboard and the windows' 9P requests, each a
  `Source`. A console's read is answered later, when its line is typed.
- What it asked of the libraries: `P9_server.make` and `request` (a
  server given the requests' bytes by a program's own loop) and
  `Later` (a read answered later); `Sys_plan9.rfork` and its flags (a
  window's process has its own namespace, note group and environment);
  `Display.desktop`, `window`, `top` (the kernel's layers: windows that
  cover one another are the kernel's work).
- A window's process: `rfork`, then **rio's files mounted before
  `/dev`** (the pipe's other end, the window's number the spec), its
  console the three descriptors, `rc -i`. mini-rc reads and writes
  `/dev/cons` as on the bare machine.

Checked: `kernel/9pi`'s `make check-rio`, **the steps of the C rio's
check** (`tests/graphics.py`'s own: rio started at the console, its
menu, New, a window swept out, `echo hello from rio` typed in it): the
window shows mini-rc's prompt, the command, "hello from rio" and a
prompt again; the 11 screens as recorded (`tests/rio-ix.md5`), the
same under mini-qemu and QEMU. The other checks pass (`check-card`,
`check-ix`, `check-draw`, `check-menu`, `make test-lite`).

Not there yet, of rio: a window's own `/dev/mouse`, `/dev/winname`,
`/dev/draw` (a graphical program in a window: hellorio, colors);
moving, resizing, hiding a window; scrolling back, selecting, snarf;
the rectangle shown while it is swept; an interrupt (Delete) to a
window's processes; a 9P flush of a read that waits; UTF-8. And the
USB keyboard and mouse are still principia's usbd (`make ix-usb`).

2026-10-05, **a program that draws in a window; the sweep shown**.

- A window's files have `winname` (its image's name: the window's
  image is given one, `Display.name`, and a program takes it by
  `Display.named`), `mouse` (the mouse while it is in the front window
  and its program has the file open: a read answered at the next
  change), and `consctl`'s `rawon` (the keys as they are typed). When
  the program closes them the window's text is drawn again.
  `Display.screen` is now where a program draws: its window, inside
  the border, or all the screen (`Display.whole`: a window system's).
- **hellorio** (`windows/tests/`: the author's `hellorio.c` and
  `hellorio.ml` with ix's libraries): it opens `/dev/draw`,
  `/dev/mouse`, `/dev/cons`, and knows nothing of windows; in one, it
  fills it magenta, writes "Hello Rio" at the mouse and the keys
  typed. The same program runs on the bare screen.
- New and Delete as rio's (the author: "when clicking New you usually
  get a cursor that changes shape and you can then draw a square and
  see the size of the window"): `lib_graphics/Cursor` (`/dev/cursor`),
  `windows/Cursors` (rio's cross and sight, their bits); the rectangle
  swept is shown as it grows, a pale window with a red border made
  anew at each move.
- `mini-pi -g mini-9pi` takes the image with the USB driver (`make
  ix-usb`): type rio in its window.

Checked: `make check-rio` with steps of its own
(`tests/rio-ix.steps`): rio, its menu, New (the cross), the sweep seen
half-way, a command in the window, hellorio in it (the mouse moved, a
key), q, rc again: 13 screens, the same under mini-qemu and QEMU. The
other checks and `make test-lite` pass. `windows/` is 456 lines with
its interfaces, hellorio 36, `Cursor` 22.

2026-10-05, **a thread a window** (the author: "I would really love
to have each window be a thread; I thought this was a very nice design
from Rob Pike"; my answer: yes: one loop over windows that are records
with queues is a state machine written by hand, the shortest today but
each thing to come is one more queue and one more function to serve
it; a window that is a thread is one loop whose state is its
variables, and ix has the threads for it). `windows/` again, 476 lines
with its interfaces (456 before):

- `Window`: its thread (`run`) receives messages on one channel, the
  window's (`Keys`, `Moved`, `Read`, `Wrote`, `Raw`, `Mouse_file`,
  `Mouse_read`, `Front`, `Quit`), and is the only one to touch the
  window's text and state; a console's read that finds no line is a
  reply the thread keeps.
- The file server is a thread too (`Rio.serve`): each request is a
  message to its window's thread (`Fileserver`).
- The window system's thread keeps the mouse, the keyboard, the menu
  and the order of the windows. A menu held open, or a rectangle being
  swept, no longer stops the windows: their threads and the file
  server's go on.
- Not rio's thread a 9P request (its xfids): the reply's function
  goes with the message.
- One thing is shared without a channel: `wants_mouse`, a window's
  field its thread sets and the window system reads (who gets the
  mouse in that window).

The runtime's threads at once: 256 (`STACKS`; they were 64).
`Thread.create` past them raises Failure "too many threads" (the
author: "we should at least warn"): said in `Thread.mli`, checked by
`languages/ml/tests/plan9/thread_limit.ml` (256, then Failure; a
thread that ended leaves its place), and rio then says "no new window"
and goes on.

Checked: `make check-rio`'s 13 screens, the same as before the change,
under mini-qemu and QEMU; `make test-lite`.

2026-10-05, **ix's own colours** (the author: "maybe we can use
slightly different colors so we know we're running ix's rio instead of
plan9's rio; same for the menu"): blues where Plan 9 has greens and
grey. The desktop a grey blue (0x667788; rio's is 0x777777), the front
window's border a blue (0x336699), the others' pale (0xb8cce0), the
menu pale blue with a blue item (`lib_graphics/Menu`: hellomenu's too).
The swept rectangle keeps rio's red. `Window`'s two types are said
once, in its interface (`type t = [%mli]`, mlpp's: the author allowed
it in `windows/`): 462 lines. `make check-card` no longer compares the
size of the kernel's image on the card (it changes with every
program). All the checks pass with the screens recorded again
(`tests/menu.md5`, `tests/rio-ix.md5`).

Next: `applications/`, colors the first; then what rio has more
(moving, resizing, hiding a window; scrolling back, selecting; an
interrupt to a window's processes).

