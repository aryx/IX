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
- **The build has three Python scripts** (`kernels/9pi/conf/`:
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
- **A file system in the kernel**: `kernels/xv6/Fs.ml` reads and writes
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
   under `kernels/firmware/`, "with a clear README.md stating the origin
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
  the card's second partition in xv6's format (`kernels/xv6/Fs.ml`'s
  code, over blocks of the card: a cache of blocks, or the partition
  read whole at the boot, to choose there); the root from it.
- **7. `windows/`: mini-rio.** After a survey of its own (rio's and
  xix's parts, libdraw's client side in OCaml, what `/dev/draw` of
  mini-9pi is asked): the plan's second half, written then.
- **8. The Pi4, arm64.** arm64 processes in mini-9pi (the a.out of 7l,
  the system call from AArch64's EL0, `Ureg`), the libc's Plan 9 files
  for arm64, the Pi4's firmware on the card.

## What is left of rio (2026-10-08)

**To do.** What principia's rio has and mini-rio has not, by reading
rio's files (`dat.h`'s list, `wctl.c`, `terminal.c`) beside
`windows/`; the Status below says what is done. In the order I would
take them:

1. **`/dev/label`**: a window's name is its program's to say (a hidden
   window is "rc 3" in the menu whatever runs in it).
2. **A double click in the text**: a word, a line, what is between two
   brackets selected (the entry of 2026-10-06 on selecting says it too).
3. **The middle menu's other items**: `cut`, `scroll` and `noscroll`
   (a window that does not follow its output), `plumb` (which asks a
   plumber: none in ix).
4. **Hold mode** (Escape: the lines typed are kept until Escape again).
5. **A window's own `/dev/cursor`**: a program's cursor while the mouse
   is in its window.
6. **`/dev/wctl` and `/dev/wsys`** (551 lines of C in rio): a program
   that makes, moves, hides and deletes windows, and the `window`
   command; `wsys` is every window's files by its number.
7. **A window read as a file**: `/dev/text` (its text), `/dev/window`
   and `/dev/screen` (its pixels and the screen's), `/dev/winid`,
   `/dev/wdir` (its directory), `/dev/kbdin` (keys written to it).
8. **The border as rio's to the end** (the entry of 2026-10-08): the
   mouse put on the corner at the press; a second button cancels.

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
`kernels/9pi`'s `make check-ix` puts `tests/hello` (OCaml: its
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
`` `{} ``, `&` and `wait`, `exit 4`). And on the kernel, `kernels/9pi`'s
`make check-ix`, the Pi1, under mini-qemu and QEMU: mini-rc as the
bootdir's `rc` (it runs `/boot/boot`, then the prompt), mini-ed as
`ed`, hello; **stage B's whole session (`tests/session-b.cmds`) gives
the C rc's console** but two files of ours in `/boot` and three names
of `/env` (`tests/session-ix-b`); `make test-lite` passes. Not checked:
a note from the keyboard (Delete at the prompt) on the kernel.

2026-10-05, **stage 2 done** (the author: "Sys.os_type looks fine to
me; let's port mkbootdir.py to OCaml for now; we can always refine
later"; the firmware "under kernels/firmware/, with a clear README.md
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
- **mini-mkbootdir** (`kernels/tools/`, 45 lines of OCaml, built by dune
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
- **`kernels/firmware/`**: the Pi1's three files (616 KB), from
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
- **`kernels/9pi`'s `make ix`**: `kernel-pi1-ix.img`, the bootdir
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
**mini-mkcard** (`kernels/tools/Mkcard.ml`, 158 lines, built by dune and
by ix's tools: the same card from both) writes an SD card's image: an
MBR; at 1 MB a FAT16 partition (32 of the card's 64 MB by default;
clusters of 2 KB; files at the root, in consecutive clusters, names of
8.3 characters: no long names) with the files given; then a second
partition to the card's end, zeros or an image given (`-fs`), of type
0xda ("data"): stage 6's place. `kernels/9pi`'s `make card` puts there
the Pi1's firmware (`kernels/firmware/pi1/`), `conf/config.txt` and the
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

- **`lib_networking/9p/`**: `P9` (9P2000's messages, as the kernel's `P9` and
  xix's `Protocol_9P`: a tag and a request or a response, variants; a
  file's entry is `Sys_plan9.dir`), `P9_wire` (their bytes, both ways,
  167 lines), `P9_server` (a server's loop, 137 lines: the fids, a
  directory's reads in whole entries, the walk's rule; a file system
  is a record of functions on its own files, `'f fs`; `post`, a pipe's
  end in `/srv`). One request at a time: no thread yet (a server that
  waits, rio, will want them).
- **`kernels/9pi/filesystems/user/dossrv/`** (principia's place for it;
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
(`kernels/9pi/devices/storage/user/fdisk/`, 70 lines: fdisk's `-p`
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
`lib_networking/9p`'s twice** (the author: "should we factorize?"): one format,
two halves; for the kernel to take `lib_networking/9p`'s, its messages and bytes
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
| ix today | | the kernel's side: `Devdraw` and the pixels in OCaml (1,759 lines); `lib_networking/9p`; `Thread`, `Event`, `Source`; `Sys_plan9` (bind, mount) |

What orio asks of the system: `Event` (`sync` 22, `send` 15, `receive`
13, `wrap`, `select`), `Thread.create` 12, and 3 `critical_section`, 2
`sleep`, 2 `wakeup`; `Unix.openfile` 9, `read`, `write`, `dup2`,
`set_nonblock`; **`ThreadUnix`'s `read`, `write` and `pipe`** (a
thread's read that lets the others run: here a `Source`'s channel);
`Plan9` (qids, permissions, `mount`: here `Sys_plan9` and `lib_networking/9p`'s
`P9`) and `Protocol_9P` (here `lib_networking/9p`); `Cap.draw`, `mouse`,
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
(`kernels/9pi/tests/screenshot.py`):

- 7a. `lib_graphics/` (geometry, the display's connection, images,
  drawing, a font): a program that opens the display and draws
  rectangles, a line and text on mini-9pi.
- 7b. the mouse and the keyboard as `Source`s; a menu.
- 7c. `windows/`: the window system; its files by `lib_networking/9p` (a request
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
thick line, "Hello Graphical World") in mini-9pi's bootdir; `kernels/9pi`'s
`make check-draw` compares the screen with `tests/hellodraw.ppm.gz`
under mini-qemu and QEMU: the same pixels. `conf/boot.rc` binds the
draw device (`#i`). Found: **the kernel panicked on a thick line**
("panic: sqrt": its C library's square root was a stub that the draw
device's `Memshape` calls; principia's rio never drew one in the
checks): `kernels/lib_machine/libc.c` has one now. Not compared with the C
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
screen; `kernels/9pi`'s `make check-menu` drives it with QEMU's USB
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

Checked: `kernels/9pi`'s `make check-rio`, **the steps of the C rio's
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

2026-10-05, **`applications/`, mini-colors the first**
(`applications/misc/Colors.ml`, 71 lines: principia's
`applications/misc/colors.c`, 199): Plan 9's 256 colours (its colour
map's formula, `cmap2rgb`), a square each; the left button on one says
its number and its red, green and blue; the right button's menu has
exit; `-r` a ramp of greys, `-x` hexadecimal. It draws where
`Display.screen` says: `kernels/9pi`'s `make check-colors` runs it on
the bare screen, then in a window of mini-rio's, the same program: 16
screens, the same under mini-qemu and QEMU.

Next: what rio has more (moving, resizing, hiding a window; scrolling
back, selecting; an interrupt to a window's processes); other
applications (the author: paint...).

2026-10-05, **rio's other window operations**. The right button's
menu is rio's: New, Resize, Move, Delete, Hide, then the hidden
windows by their names ("rc 3"), and Exit (ix's).

- **Move**: a window dragged with the right button, its outline shown
  (as the sweep's); it is then the same image elsewhere
  (`Display.origin`, the draw device's 'o': the kernel moves its
  pixels). **Resize**: a window pointed at, its new rectangle swept:
  another image, the text in it again (`Terminal.reshape`: the last
  lines that fit). **Hide**: the window's place on the screen far away
  (the same 'o'), its name in the menu, which brings it back.
- All three are messages to the window's thread (`Reshape`, `Hide`),
  which changes its own image; the window system reads `image` and
  `hidden` (as `wants_mouse`: fields the thread writes).
- **Delete typed in a window** interrupts its processes: "interrupt"
  written to their note group (`/proc/pid/notepg`).

Checked: `make check-rio`'s steps go on (`tests/rio-ix.steps`): Move
(the window is 60 by 40 further), a command typed, Hide (the desktop
alone), the name chosen (the window back), Resize (250 by 250 at
another place, its text kept), a command typed: 28 screens. Not
checked by a script: the Delete key's interrupt. Not done: a program
that draws is not told its window changed (the mouse file's "r"
message and a new `winname`: hellorio and colors after a Resize draw
in an image that is no more); scrolling back and selecting; UTF-8.

2026-10-05, **a program that draws is told its window changed**. When
a window is moved or made another size, its thread makes the next read
of its mouse file start with `r` (Plan 9's), for a program that has
the file open. `Mouse.state` has `resized`; the program then asks
`Display.screen` again (the window's image has another name when it is
another image; the one it had is let go there: without that the window
system's old image stayed on the screen, kept by the program's hold on
it) and draws again. hellorio and mini-colors do.

Checked: `make check-colors`'s steps go on (`tests/colors.steps`):
colors in its window, the window moved (the squares with it), then
made another size (the squares again, to the new size; the old window
gone): 26 screens. Found while writing the steps: a menu opened near
the screen's bottom is moved up to fit, and the item under the mouse
is then not the last choice (rio's does the same).

2026-10-05, **scrolling back**. A window's text keeps the lines that
left (1,000 of them); the up and down arrows show them, half of the
window at a time (rio's), and any other key typed goes back to the
end; while one reads above, what is written does not move what is
shown. A bar on the left (rio's scroll bar: grey, white where the
lines shown are among all) says where. `Terminal`: `back`, `scroll`,
`half`, the bar; a window moved or made another size keeps all its
lines.

The keyboard gives whole characters now: a read of the console may
end inside one (an arrow is three bytes, Plan 9's rune 0xF00E as
UTF-8, and they came one read each: typed in the window as three
strange letters), so `Keyboard.receive` keeps a character's start for
the next read and gives a list of characters, each its bytes;
`Keyboard.up`, `down`. A character of several bytes is not shown yet
(no UTF-8 in `Font`).

Checked: `make check-rio`'s steps go on: 24 lines written, the up
arrow twice (lines 2 to 13 shown, the bar's white part higher), the
down one, a command typed (the end again): 33 screens. `tests/graphics.py`
has a step for a key by its name (`("key", "up")`). Not done: the
mouse in the scroll bar (rio's three buttons there); selecting text;
each line written draws the window's text again (simple; slow for a
long output).

2026-10-05, **the graphical checks in 3 minutes** (the author: "why
does it take so much time?": a session is driven as a person would,
through QEMU's USB keyboard and mouse: half a second a key, two a
button's change, and each of its screens waited for until it is the
recorded one twice; 33 screens for mini-rio's, 26 for colors', each
under two emulators, one check after the other: 20 minutes).

- `kernels/9pi`'s **`make check-windows`**: the four checks' eight
  sessions side by side (`run-*-mini`, `run-*-qemu`, then `cmp-*`):
  198 seconds, twice. Each `check-*` runs its two side by side.
- **Shorter pauses** (`tests/graphics.py --pause 0.2,1`, the Makefile's
  `GFX_PAUSE`): mini-rio's session under mini-qemu takes 195 seconds
  for 281, the same 33 screens; 0.15 and 0.6 give 183 (what is left is
  the waiting for each screen).
- Found by running them at once: every session went wrong from its
  first screen. `graphics.py` took a screen that had not changed for 9
  seconds as the one to go on from, and under load the boot stands
  still for longer than that before its prompt: the steps were typed
  too early (the one check that failed once, on 2026-10-05, was this).
  With a screen expected, another one is now waited on for a minute.
  The options are read in any order.

2026-10-06, **the scroll bar's buttons** (the author: "the scrollbars
do not react to click on them"): rio's. A button pressed in a window's
scroll bar is the window's: the left one goes back and the right one
forward, by as many lines as the mouse is below the bar's top; the
middle one shows what is at that place among all the lines. Once a
press (the window system keeps the buttons of the event before), and
the window comes in front. As rio (the author: "I'm not sure rio or
xix's rio had this Bar of int * Point.t; shouldn't this be in the
Terminal.ml code instead?"): no message of the scroll bar's own (there
was one, `Bar`, a day): the window is sent the mouse (`Moved`, the one
message for it), its thread gives it to the program that reads the
mouse or else to its text, and `Terminal.pressed` says what a press
means there (rio's terminal.c asks if the mouse is in the window's
scroll rectangle and calls scrl.c's wscroll; libframe has no scroll
bar; xix's Terminal has the rectangle, its use is to do). The window
system only asks if a press is in a window's scroll bar
(`Window.in_bar`), to know it is not for its own menu: rio's mouse
thread asks the same. Selecting text will come the same way. Checked by eye
(the screens of a short session: 6 lines back, twice, 6 forward, then
the middle button's jump) and in `make check-rio`'s steps, which have
the three clicks.

2026-10-06, **the graphical checks in two minutes** (the author: "this
is too long and we need to further shorten the time"). What made a run
long that day: a session under QEMU lost a key at its first step (the
pause after a key, 0.2 seconds, too short once), and each of its 40
screens was then waited on for a minute.

- **A session stops at the first screen that is not the one
  recorded** (`graphics.py`): a minute, not a minute a screen.
- **Short sessions, side by side**: the two long ones are five
  (`tests/win-new`, `win-ops`, `win-scroll`, `colors-bare`,
  `colors-win`.steps and .md5: the first window; the window's operations; scrolling; colors
  on the bare screen; colors in a window), each starting from the
  boot. With menu and draw: 14 emulators at once. **`make
  check-windows`: 113 and 112 seconds** (198 the day before, 20
  minutes one after the other); what one waits for is the longest
  session. `make expected-windows` records them all side by side (319
  seconds). The Makefile has them by pattern rules (`run-NAME-mini`,
  `cmp-NAME`, `expected-NAME`).
- The screen is looked at every 0.4 seconds (1); a key's pause is 0.3.


2026-10-06, **text selected, snarf, paste and send** (the plan's item
3 after scrolling). In a window's text the left button selects, from
where it goes down to where the mouse is until it comes up: the
characters selected are drawn on a mark (a pale blue). The middle
button's menu is rio's: snarf keeps the text selected (one kept for
all the windows), paste types what is kept in the window, send types
it and a newline (a word of rc's output selected, snarf, send: rc
runs it).

- **Who does what** (the author: "should the Selection be part of
  Window.mli?", "I want good separation of concerns, like in
  principia's rio and orio, so that Window.ml is mostly about the
  windows, and Terminal.ml about the terminal, and Rio about the
  windowing system"). A first version had a message
  `Selection of (string -> unit)` for the window's thread, and the
  menu and the text kept in `Rio`. Neither rio nor xix has such a
  message: rio's mouse thread calls `button2menu(winput)`, which is in
  terminal.c and reads the window's text itself (`wsnarf`); xix's
  orio has no snarf yet ("less: snarf"). So, as rio:
  - `Terminal` has all of the text's: the lines' numbers (a selection
    stays on its text when the text scrolls), `Terminal.mouse` (the
    scroll bar's three buttons, selecting), `Terminal.menu` (the
    menu, the text kept); it gives back what is to be typed, since
    the line being typed is the window's.
  - `Window` has one field more, `text`, and no message more: its
    thread alone changes the text, the window system hands it to
    `Terminal.menu`.
  - `Rio` gives the mouse to a window from a press there (in its bar,
    or the left button in its text) until the buttons are up, and
    calls the menu on the middle button.
- A bug of the first version, found by `win-scroll`: the window was
  not sent the button's release after a press in its bar, so its
  second press was not a new one for `Terminal.mouse`.
- Not done: a `/dev/snarf` file for the programs; selecting by words
  (a double click); the text selected past the window's edge by
  scrolling while the button is held.
- Checked: `tests/win-select` (12 screens: a word swept, the menu,
  snarf, send), with the others in `make check-windows`: 16 sessions,
  109 seconds on a quiet machine. That day another program used all
  the processors at times (load 42): two sessions then failed at one
  screen, and passed run again alone; the checks depend on the
  machine being free. `compile_ix.sh` did not find `lib_graphics` for
  `windows/` (5 files failed there, unnoticed): it is now among the
  libraries shared, 322 of 322 compile.

2026-10-06, **characters that are not ASCII's** (the plan's item 4). A
text is its bytes, UTF-8, everywhere (the console's files, the lines
kept, what is selected and typed); what draws or counts columns goes
by characters.

- `Utf8` (lib_core/commons; Plan 9's runes, libc's chartorune,
  runetochar and utflen): all of ix's UTF-8 in one place (the author:
  "ocaml also has an uchar.ml module", "let's move Utf8.ml in
  lib_core/commons/ so we can add new functions not in the stdlib,
  and maybe add wrappers ... to centralize a bit all UTF8 related
  things"). The decoding and the encoding are the standard library's
  (`String.get_utf_8_uchar`, `Buffer.add_utf_8_uchar`, `Uchar`),
  under two short names, `decode` and `add`, with numbers for
  characters; and what the library has not: a string's characters
  each its bytes (`chars`: `Keyboard`'s splitting of a read), how
  many, a part of it by characters. A first version decoded by hand,
  in lib_graphics. mini-ed (`Input`, `Out`, `Command`, `Address`),
  `Regex`, `Json` (its own encoder gone) and mini-git's `Diff` now
  call it: no other file of ix's names the library's UTF-8 functions
  (but the test of the stdlib itself).
- `Font` draws a character by its number: the default font has 256
  (Latin-1), and a character it has not is drawn as its first one (a
  mark, of a character's width: the columns stay right), as libdraw
  does.
- `Terminal`: columns, wrapping, the mark of what is selected, the
  place under the mouse and Backspace go by characters; a write that
  ends inside a character keeps its first bytes for the next.
- `Window`: a key is a character of any length (before, only one
  byte's were typed), Backspace and Ctrl-U take whole characters
  back; the keyboard's own keys (Plan 9's runes 0xF000 to 0xF8FF) are
  not typed. `Rio` types what is pasted by characters.
- Not done: typing such a character from the keyboard (Plan 9's
  compose key, Alt and two keys: the kernel's `Kbd` has no table of
  them yet), other fonts (the Greek of the check is 6 marks), bytes
  that are not UTF-8 (each is shown as the font's mark, U+FFFD's
  place).
- Checked: `tests/win-utf8` (15 screens): `cat /boot/words`
  (tests/words.txt, in the boot directory: "naïve café" and a Greek
  word), "café" swept and marked on its four columns, snarf, paste,
  Backspace twice ("ca" is left), `t /boot/words` typed after it.
  `make check-windows`: 18 sessions, 110 seconds; check-ix,
  check-card, test-lite and compile_ix.sh pass.

2026-10-06, **`/dev/snarf`**: the text kept by the windows' menu is a
file of each window's directory (rio's Qsnarf), for the programs:
read, it gives the text; opened to be written, it is emptied and
takes what is written (`echo ... > /dev/snarf`). `Fileserver` has it
(one more file, `Terminal.snarf` behind it: no message to a window,
the text is all the windows'). And send adds its newline only to a
text that does not end with one (rio's). Checked in `win-select`, now
16 screens: after the word snarfed, `cat /dev/snarf` shows it; `echo
echo by a file > /dev/snarf`, then send: rc runs it. The checks: as
above, all pass.

What the checks cost (the author: "why this is so slow again?"): a
change of 16 lines was followed by the whole suite, some 8 minutes:
the session recorded (`make expected-win-select` took 3 minutes
earlier that day), check-windows (2), check-ix, check-card and
test-lite. For a change in `windows/` alone: the session it touches
while working, check-windows once before a commit; the others when
lib_core or the kernel changed. (Recording is the slow one by its
nature: with no screen expected, each step waits for the screen to
stand still; a check goes on as soon as the screen is the one
recorded.)

2026-10-06, **the compose key** (Plan 9's: Alt, then two or three
keys, make a character): "é" can be typed, not only pasted. The
kernel's `Kbd` had the state for it (Alt starts a sequence) and no
table: the keys after Alt were given as they were.

- `Latin1` (kernels/9pi/devices/keyboard; principia's latin1.c and its
  table, latin1.h, 100 rows as they are there, the characters as
  UTF-8 in the source): the character of the keys typed after Alt, or
  that more are needed, or that they make none (then they are given
  as typed). Alt ' e is é, Alt , c is ç, Alt * a is α, Alt X and 4
  hexadecimal digits a character by its number (x: 8 digits). It
  decodes its table by hand: the kernel is compiled by ocaml-light's
  ocamlopt, which has no `String.get_utf_8_uchar` (so not `Utf8`).
- `Dev.utf8` writes the characters from 0x10000 too (4 bytes).
- Checked: `win-utf8`, 21 screens: Alt ' e and Alt , c typed in a
  window, é and ç shown on the line. Not checked: Alt * a (QEMU's key
  named asterisk did not reach the kernel from the USB keyboard: the
  keypad's, which principia's usbd may not map; the sequence was
  changed, the cause not looked for).

## ix's own USB keyboard and mouse (2026-10-06)

The last of principia's programs mini-rio needs is `usbd`: the image
of `make ix-usb` has it, and without it `mini-pi -g mini-9pi` has no
keyboard nor mouse. The author: "ultimately we may want usb mouse and
keyboard support directly in the kernel (and also a version in
userspace, again as a teaching tool to explain even device driver can
be in userspace)".

What is there. mini-9pi's kernel has principia's split: `Devusb` and
`Usbdwc` (the controller, its endpoints as files, `#u/usb/epN.M/data`
and `ctl`; a root hub that is a toy: a port's status, reset, enable),
and nothing that knows a device: finding the devices, giving them
addresses, reading their descriptors and driving them is a program's.
principia's is usbd with its library and its kb driver: 4,400 lines
of C (usbd 1,200; lib 2,200, half of it a file server for the other
drivers; kb 1,000).

The stages:

1. **mini-usbd, a program** (kernels/9pi/buses/user/usbd, as
   principia's kernel/buses/user/usb): written anew, for what ix
   has: hubs (the root's and real ones: QEMU puts one before two
   devices, the Pi1 B has one), a keyboard and a mouse by HID's boot
   protocol. Three modules: `Usbdev` (a device's files, its control
   requests, its descriptors), `Hid` (a keyboard's reports to
   scancodes for `#Ι/kbin`, a mouse's to lines for `#m/mousein`),
   `Usbd` (the hubs' ports, a device attached). A process per
   keyboard or mouse (a read of its endpoint waits), one that looks
   at the ports four times a second. Not: the other drivers (disks,
   serial, ethernet: the kernel has the last), report descriptors (a
   mouse with more than the boot protocol's), usbd's file server.
   Check: `make check-windows`, the same screens with mini-usbd in
   the image in place of usbd.
2. **Devices plugged and unplugged** while it runs (QMP's device_add
   in a session).
3. **The same in the kernel** (the author's first wish): the
   enumeration and `Hid` called by the kernel at boot, no program; a
   choice at build time. The author (2026-10-06): "ideally some of
   the code for the userspace usbd and kernel-space can be reused, in
   a library". So a library (lib_usb, as lib_networking/9p) with what does not
   depend on where it runs: the descriptors read, a keyboard's
   reports to scancodes and its repeat, a mouse's report to its line,
   and the enumeration itself over a small record of functions (a
   control request to a device, a line to its ctl, a read of an
   endpoint, a pause): mini-usbd gives it the files of #u, the kernel
   its own `Devusb` and `Usbdwc`. What stays outside: the processes
   (a program's fork; the kernel's kprocs) and where the scancodes go
   (a file; `Kbd.kbdputsc`). A constraint: the kernel is compiled by
   ocaml-light's ocamlopt, with its own list of units, so the library
   keeps to what both have (found with `Latin1`: no
   `String.get_utf_8_uchar` there).
4. A real Pi1: to be tried by the author (QEMU's controller forgives
   more than the board's).

2026-10-06, **stage 1 done: mini-usbd**, 417 lines with its
interfaces (`Usbdev` 116, `Hid` 152, `Usbd` 149), in the image of
`make ix-usb` in place of principia's usbd: mini-rio now runs on ix's
programs alone (the kernel, rc, rio, the driver of its keyboard and
mouse).

- **Checked by the same screens**: `make check-windows`, its 18
  sessions under mini-qemu and QEMU, with the md5s recorded with
  principia's usbd, not recorded again: the keys, the three buttons,
  the mouse's moves arrive the same. For that mini-usbd says what it
  starts as usbd does ("usb/hub... usb/kb... usb/kb... " on the
  console: QEMU's hub, the keyboard, the mouse).
- **A bug found by QEMU** (mini-qemu forgave it): the mouse's
  process read 8 bytes of an endpoint whose packets are 4: a report
  of 4 bytes is then not a short packet, and the controller waits for
  a second one. A read asks for the endpoint's largest packet (as
  kb.c).
- **Keys repeat without a clock nor a second process**: the keyboard
  is asked to say its state every 32 ms (SET_IDLE, which kb.c sets
  too on this controller), and a key held 5 reports is written again
  at each one. Checked by eye under both emulators: x held a second
  (`graphics.py`'s ("key", "x", 1000): a key held), 21 of them.
- Not done, not checked: a device unplugged or plugged later (the
  code is there, the process that looks at the ports four times a
  second; stage 2 checks it); a device that does not answer SET_IDLE
  would not repeat; a real Pi1.

2026-10-06, **stage 2 done: devices unplugged and plugged again**.
mini-usbd's process that looks at the ports forgets a device that is
gone (the kernel is told: "detach"; the device's process ends at its
read's error) and starts one that comes.

- **A bug of the kernel's found** (docs/plans/bugs/ix.md): after one
  device was unplugged, no device answered any more, the keyboard
  dead. `kernels/lib_machine/usb.c`'s `usb_transfer` left the controller's
  channel enabled after a transfer that did not end, and a channel
  still enabled starts nothing. It is disabled first now.
- **`make check-plug`** (`tests/usb-plug.steps`, 9 screens, 17
  seconds): the mouse then the keyboard taken out (QMP's device_del),
  others put in (device_add: "usb/kb... usb/kb... " said again), rio
  typed on the new keyboard, its menu opened by the new mouse.
  `graphics.py` has the two steps ("unplug", "plug"). **Under QEMU
  only**: mini-qemu's QMP has no device_add nor device_del (its
  devices are made once, at its start: some 50 lines over
  raspberry/'s Usb, Board, Qmp and Main to change that, not done).
- The other checks: check-windows (18 sessions), check-ix,
  check-card pass. `make test-lite`: 33 of 34: `mini-ml -pp` fails on
  generators/tests/trees/lists.ml (`[@@deriving eq]`), a file of
  another session's commit that day (7f7b121), not of this work.
- Not checked: a hub unplugged with devices below it (the code is
  there), a real Pi1.

2026-10-06, **stage 3 done: the kernel as its own usbd, with the same
code**. `echo kernel > '#u/usb/ctl'` and mini-9pi finds and reads the
USB keyboard and mouse itself, no program. The boot script chooses:
usbd when it is in the image (`make ix-usb`), else the kernel (`make
ix`: `mini-pi mini-9pi` has a keyboard and a mouse with nothing but
the kernel). A choice when it runs, not when it is built: one kernel.

- **kernels/9pi/buses/lib_usb** (the author: not a top-level
  directory), 352 lines with its interfaces, compiled into mini-usbd
  and into the kernel: `Usbdesc` (a request's 8 bytes, a
  configuration's interfaces and endpoints), `Hid` (a keyboard's
  reports to scancodes, with the repeat, as a state and a step; a
  mouse's report to its move and buttons), `Usbbus` (the enumeration:
  hubs, ports, a device attached, over a record of ten functions, how
  a device is reached).
- **mini-usbd** is what is a program's: 165 lines (the files of #u,
  the processes that read and write). **`Kusb`** is what is the
  kernel's: 88 lines (`Devusb`'s and `Usbdwc`'s functions for the
  record; the reports read from the clock, a try a tick with
  `Usbdwc.intry`, since mini-9pi has no process of the kernel's own
  and the clock must not wait; scancodes to `Kbd.kbdputsc`, moves to
  `Devmouse.track`). 605 lines in all where stage 1 had 417 for the
  program alone.
- **Checked by the same screens again**: `make check-windows-kernel`,
  the 8 sessions with the image that has no usbd, under mini-qemu and
  QEMU, against the md5s recorded with principia's usbd: 16 of 16.
  `make check-windows` (mini-usbd over the library): 18 of 18;
  check-plug, check-ix, check-card pass; `mini-mk check` in
  kernels/9pi (the kernel by ix's tools, the Pi4's): 13 of 13;
  test-lite 34 of 34.
- **Not in the kernel's version**: a device plugged or unplugged
  later (a look at the ports waits, which the clock cannot: it would
  need a process of the kernel's, or the hub's own interrupt
  endpoint); `Etherusb`, the kernel's older USB driver, still has its
  own descriptors' code and still wants usbd's enumeration.
- **Three bugs on the way** (docs/plans/bugs/ix.md and ocaml_light.md;
  docs/notes_debugging_techniques.md, sections 14 and 15):
  - ocaml-light has no `"\xe0"` in a string: the kernel's arrow keys
    were five characters, the program's right, from one line.
  - The kernel by ix's tools had not linked since xix's `Chan` came
    into lib_core/commons the day before: the kernel's is now
    **`Kchan`** (the author: "Kchan.ml ?"), as `Kusb`.
  - `make check-ix` had failed since `words` was put in the boot
    directory, and was reported passing: the check was read through a
    grep that hid diff's lines. Read by its exit status now.

To do next, the author's (2026-10-06), the same shape for two more:
- **FAT**: "we should do the same thing for dossrv we did for usbd,
  and have a lib_fat under filesystems/ and a user/dossrv/", "and a
  Kdos.ml or something for the in kernel version".
- **The kernel's pixels**: "should we also use Kdraw.ml instead of
  the lib_graphics/Draw.ml?", "the rest Memdraw, Memimage could
  actually be in an intermediate lib, because they could work both in
  userspace and kernel space, like that was the case in principia's
  original code", "maybe we should split the kernel/lib_graphics/, to
  follow the convention we have been following for the lib_usb/".

2026-10-06, **FAT, the same shape as USB** (the author: "a lib_fat
under filesystems/ and a user/dossrv/", "and a Kdos.ml or something
for the in kernel version").

- **kernels/9pi/filesystems/lib_fat**: `Fat`, what knows a FAT (moved
  from mini-dossrv, 175 lines with its interface), now given how its
  device is read (`Fat.make : (int -> int -> string) -> t`, n bytes at
  an offset) where it took a descriptor; without lib_core's `Binary`
  nor a `"\xe5"`, so that the kernel's compiler takes it. Compiled
  into mini-dossrv and into the kernel.
- **mini-dossrv** (filesystems/user/dossrv, 84 lines) is what is a
  program's: the 9P server, a descriptor read.
- **`Kdos`** (filesystems, 94 lines with its interface) is what is the
  kernel's: a device, `#F`, whose tree is a partition's FAT:
  `bind '#Fdos' /root` (the attach's word is the SD card's partition,
  #S/sdM0/dos). The disk's device is read from the kernel as a program
  would read its file (`Kchan.namec`, the device's read). A channel
  has only its qid, so the files seen are kept in a table, by their
  place on the disk. No line of the boot's for it ("reset 19, fat"
  would change the console that is compared with 9pi's).
- **Checked**: `make check-card`'s session with ix's programs, 5
  commands more: after dossrv's mount on /root, `bind '#Fdos' /mnt`
  and the same commands there: the same five files with the same
  sizes and dates (`F` where a mount says `M`, r--r--r-- where dossrv
  says rw-rw-rw- of a tree it cannot write), config.txt's text, a name
  found in capitals, a file not there, a creation refused. Under
  mini-qemu and QEMU. And check-ix, check-windows (18), `mini-mk
  check` in kernels/9pi (13), test-lite (34), compile_ix.sh (the
  kernel's 97 files), the utilities' 51 cases: all pass, each read by
  its exit status.
- **Not done**: the boot script still starts dossrv (it is always in
  ix's image; choosing the kernel's device when it is not, as for
  usbd, is two lines, not tried: no image without dossrv to check it
  with); writing (in `Fat`, for both at once); the partitions are
  still fdisk's to say; offsets are bytes in an int: a partition past
  1 GiB on the Pi1 (31 bits) is out of reach, as before.

2026-10-06, **the kernel's pixels, the same shape** (the author:
"should we also use Kdraw.ml instead of the lib_graphics/Draw.ml?",
"the rest Memdraw, Memimage could actually be in an intermediate lib,
because they could work both in userspace and kernel space, like that
was the case in principia's original code").

- kernels/9pi/lib_graphics is now:
  - **lib_memdraw** (`Memchan`, `Memimage`, `Memdraw`, `Memfont`):
    images in memory, drawing, the default font: principia's
    libmemdraw.
  - **lib_memlayer** (`Memlayer`, `Memshape`): windows that cover
    each other, and the shapes, which are drawn through them:
    principia's libmemlayer.
  - **`Kdraw`** (its interface there, `ocaml/Kdraw.ml` over the two
    libraries, `c/Kdraw.ml` over principia's C): the kernel's part,
    the screen on the framebuffer and what `Devdraw`, `Swconsole`
    and `Swcursor` ask. `Kdraw`, not `Draw`: a program's `Draw` is
    the top-level lib_graphics's (the clash `Chan` had).
- **The two libraries name nothing of the kernel's now**: the one
  call there was `Memimage`'s write of a row to the framebuffer
  (`Machine.Phys.write_sub`); it is a function the caller gives
  (`Memimage.to_screen`), which `Kdraw` sets. They still need
  `Memdata` (the colour map and the font, generated at the kernel's
  build from principia's: conf/mkpixdata.py).
- No code changed but that call and the names; 947 lines moved.
- **Not done: a second user.** Nothing outside the kernel draws with
  them yet, so "could work in userspace" is by construction, not by
  a program: no dune library (it would need `Memdata` without the
  kernel's build). A first one could be a test on the host: draw in
  memory, compare the pixels.
- **Checked**: both pixels build (`make`, `make PIXEL=c`); `make
  check` (the twin's, against the C 9pi's screens and console: 13),
  check-windows (18), check-windows-kernel (16), check-plug, check-ix, check-card (7), `mini-mk
  check` (13), test-lite (34), compile_ix.sh (the kernel's 100
  files).
- **Two more builds found broken, both by earlier work of this
  plan's**, neither covered by a check (docs/plans/bugs/ix.md):
  `make PIXEL=c` had not linked since the graphical checks' rules
  named their script `GFX`, the name of the C pixels' sources (it is
  `GRAPHICS` now); and `make check-card`'s size mask knew the
  kernel's image under /root only, not under /mnt where `Kdos` now
  lists it too (it failed as soon as the image changed size).

2026-10-06, afternoon, the author away ("let's do 1, 2, 3, 5, and 6.
I'll review when I'm back"): what follows is **not committed**, for
that review. In the order of the list.

**1. `make check-all`** (kernels/9pi): every build and every check of
the directory, one after the other, stopped at the first that fails
(the two pixels, the twin's check, check-ix, check-card,
check-windows, check-windows-kernel, check-plug, `mini-mk check`).
What it found about the checks themselves:
- The graphical sessions fail now and then on a busy machine (another
  session's programs kept the load at 35 to 45 all afternoon): 16
  emulators side by side lose a key or a screen. check-all tries them
  a second time, 4 at once (`GJOBS`). It was not seen whole and green
  that afternoon: each of its parts passed, run alone.
- `mini-mk check` **does not fail when its sessions do** (mk's recipe
  ends on something else): its exit status says nothing, its "ok"
  lines are to be counted (13). Not mended. And its sessions' time
  limits (120 seconds) are too short for the kernel built by mini-ml
  on that busy machine: 137 seconds for stage B's, which passes with
  500.

**2. FAT written** (lib_fat's `Fat`, so mini-dossrv and `Kdos` at
once): a file written at an offset (past its end: zeros between),
emptied (an open's OTRUNC), made (a name of 8 and 3 characters with
its two bits of case, or a long name and an alias, NAME~1), a
directory made, a file or an empty directory removed; FAT12, 16, 32.
- The table is kept in pieces of 512 bytes (`string array`): a piece
  changed is one string made again and one write in each copy. Each
  change is written at once, the data before the table: no cache to
  lose.
- **Checked on the host first** (`filesystems/lib_fat/tests/fat.sh`,
  `Fattest`): an image of each size made by mkfs.vfat, 13 changes by
  `Fat`, each read back by mtools, then fsck.vfat: 39 of 39. Then in
  the emulators: `check-card`'s session writes through mini-dossrv
  (`echo ... > /root/note.txt`, a long name in two cases, the file
  emptied and written again) and through the kernel's device (`bind
  -c '#Fdos' /mnt`: the same), each read back through the other.
- 9P's create could not say "a directory" on the Pi1: the bit is the
  32nd, an int has 31. `lib_networking/9p` now carries the permissions' top byte
  at bits 16 on (`P9.perm`). mini-9pi's own create has the same loss
  (`Kdos` cannot be asked for a directory there); no program makes
  directories yet.
- Not done: a name changed (wstat); FAT32's count of free clusters
  (fsck mends it); two that write one partition at once (dossrv and
  `Kdos` each keep the table: the session writes through one, then
  the other, never both in turn).

**3. The kernel's side, finished.**
- **boot.rc falls back to the kernel's FAT** when dossrv is not in
  the image (`if not bind -c '#Fdos' /root`), and `make ix-kernel` is
  that image: neither usbd nor dossrv, the keyboard, the mouse and
  /root by the kernel alone. `check-card` has its session (9 lines of
  "ok" now): /root listed, read, written, /srv empty.
- **Devices plugged and unplugged with the kernel's USB**: a look at
  the ports waits, so it is a process's: **`Kproc`**, mini-9pi's
  first process of the kernel's own (a process's record with nothing
  of a program; `process_start` runs its work where another goes to
  user mode). `Kusb` starts one that looks once a second.
  `check-plug` runs its scenario a second time with the kernel's USB:
  the same 9 screens. A process more: the pids after it move by one
  (`tests/session-ix`: hello's is 21).
- `Etherusb` takes its request's 8 bytes from lib_usb (`Usbdesc`);
  its own descriptors' code stays (CDC's, which `Usbdesc` passes
  over). Not tried: the network with the kernel's USB (ix has no
  program for it; the twin's network session runs with usbd).

**5. The file system in the kernel (stage 6)**: xv6's, on the card's
second partition.
- **kernels/9pi/filesystems/lib_xv6fs**: `Xv6fs`, xv6's file system
  over a device's bytes (as `Fat`: given how to read and write),
  written anew (kernels/xv6's `Fs` is over a RAM disk and that
  kernel's types): inodes, the bitmap, directories; files read,
  written, emptied, made, removed; `format`, a new one.
- **The format extended** (taken without the author that afternoon;
  the author after: "let's extend xv6 format to support bigger
  files"): the format is xv6-multiarch's with one thing more. xv6's largest file
  is 58 blocks and a block of numbers: 314 KB with blocks of 1024
  bytes, less than one of ix's programs (hello is 632 KB). So a
  second block of numbers, of blocks of numbers (xv6's exercise
  "large files"): 64 MB. Its number is in the inode's 8 bytes xv6
  leaves unused (at 8), so an image of xv6's is read as it is, and
  xv6 reads one of ix's but for its large files. The other ways: the
  format as it is and no program on it; or a format of ix's own.
- **`Kfs`** (filesystems): the device, `#x` (`bind -c '#x' /mnt`:
  #S/sdM0/other, fdisk's name for the second partition), as `Kdos`.
- **mini-mkfs** (kernels/tools, with the library's code): an image
  with files in it, the directories on a name's way made; built by
  dune and by mini-ml (the two make the same image). `make card`
  puts one in the second partition, with a text and a program.
- **Checked on the host** (`lib_xv6fs/tests/xv6fs.sh`, `Xv6test`):
  xv6-multiarch's own two images read (their names, README's text:
  the format agrees with its mkfs); then images of each block size
  made here: files of 11 bytes, 300,000 and 2,500,000, written past
  the end and over a part, 60 files in a directory, a file removed
  and written again three times (its blocks given back), a name of
  15 characters refused: 30 of 30. **In the emulators**
  (`check-card`): `bind -c '#x' /mnt`, the listing, the text, **the
  program run from there** (632 KB read through the second block of
  numbers by the kernel), a file written, emptied, written again.
- Not done: the root from it (/root is still the FAT's; boot.rc does
  not bind it anywhere); xv6 itself booted on an image of mini-mkfs
  (the format's check the other way); a server of it as a program
  (the third of the shape: lib, K, user); times (xv6 keeps none).

**5, second half, not started: the Pi4 with arm64 programs** (stage
8). It is a stage of several days, not of an afternoon: arm64
processes in mini-9pi (a.out's of 7l loaded, the system call from
AArch64's EL0, `Ureg`, notes), lib_core/libc's Plan 9 files for
arm64 and the runtime's, mini-ml's Plan 9 target on arm64 (`mini-mk
O=7 OS=plan9`), the Pi4's firmware on the card. Nothing was touched.

**6, not done.**
- **The kernel's `P9` and `P9_wire` with lib_networking/9p's**: looked at, not
  begun. The two differ by more than their place: the kernel's has
  the client's half only, with the kernel's own types (`Types.qid`,
  ints; `Types.dir`); lib_networking/9p's has both halves, int64 qids,
  `Sys_plan9.dir`, lib_core's `Binary`, `Unix`'s descriptors, none of
  which the kernel's compiler has. Sharing wants lib_networking/9p's two modules
  made free of all that first (as `Fat` was of `Unix`), then `Devmnt`
  moved onto them: the kernel's every mounted file goes through
  `Devmnt`, and that afternoon the checks that would say it still
  works were failing one in three from the machine's load. Left for a
  quiet machine.
- **The lines trimmed**: not begun. That afternoon added lines
  (`Fat`'s writing, `Xv6fs`, `Kfs`, `Kproc`, mini-mkfs, two host
  tests).

**The state of the tree for the review** (nothing committed since
`08c1e09`). Each check passes run alone; `make check-all` in one go
was not seen green (above). Run alone, on the final tree: `make`
and `make PIXEL=c` build; `check` 13; `check-ix`; `check-card` 9;
`check-windows-kernel` 16; `check-plug` 2; `fat.sh` 39; `xv6fs.sh`
30; test-lite 34; compile_ix.sh (the kernel's 106 files).
`check-windows`: 16 of 18 in two runs side by side (win-ops under
mini-qemu, one screen), and that session alone three times of three.
`mini-mk check` (the kernel by ix's tools): the image builds; its
sessions passed (13) before `Kproc` and the file systems were added,
and were not seen passing after: two timed out at 120 seconds on
the busy machine (one passes with 500); to run again.

2026-10-06, **the larger files in mini-xv6 too** (the author: "yes
let's extend and mark clearly in the code that it's an extension to
the original xv6"). kernels/xv6's `Fs` has the second block of numbers
(`bmap`, `itrunc`, `maxfile`; `i_double`, the inode's byte 8), as
lib_xv6fs: one format for the two kernels and for mini-mkfs.
- **Marked**: a comment in capitals where it starts, "IX'S EXTENSION
  TO XV6'S FORMAT (not xv6's, nor xv6-multiarch's)", in `Fs.ml`, in
  `Fs.mli`'s header, in `Xv6fs.ml` and `Xv6fs.mli`, saying what xv6
  has there (8 unused bytes), why (314 KB), and what it costs (xv6
  cannot read whole a file made larger); and each line of it, in the
  two files, has "ix's extension".
- **`make check-large`** (kernels/xv6): an image made by mini-mkfs
  with xv6's programs (taken out of xv6's own image by `Xv6test`) and
  a text of 1,288,895 bytes; mini-xv6 with it as its disk: `wc big`
  says what wc says on the host (the file read whole, through the
  second block), then `cat big > copy; wc copy`: the same (written by
  mini-xv6's own `bmap`). On the Pi1 and on the Pi4.
- Unchanged: `make check` in kernels/xv6 (the session as xv6's C
  kernel's, usertests: 7 lines of "ok"), xv6fs.sh (30), test-lite
  (34).

2026-10-06, **mini-rio on the card, not in the kernel's image** (the
author: "let's do 3 and put at least rio on it instead of in the
kernel image"). The xv6 partition is used at the boot:
- **boot.rc** binds its bin after /bin (`bind -a '#x/bin' /bin`,
  when the card has a second partition): what is typed is looked for
  in the kernel's /boot, then there.
- **`make card`** puts mini-rio, hellorio and mini-colors in that bin
  (`CARD_BIN`, by mini-mkfs), with hello; **they are out of the
  kernel's bootdir** (`BOOTDIR_IX`): the image is 10.2 MB where it
  was 12.4. What the boot needs stays in the image (rc, ls, bind,
  mount, echo, cat, fdisk, dossrv, usbd), and the two programs that
  draw on the bare screen (hellodraw, hellomenu).
- So `rio` typed at the prompt is read from the card by the kernel's
  own file system (839 KB through `Kfs` and the second block of
  numbers), and so are the programs of its windows.
- **The graphical sessions have the card** (`MENU_USB`: the same
  `-drive` as check-card's, a snapshot: 18 emulators read one file),
  and were recorded again: the console has one line more ("dossrv:
  serving #s/dos"). **Compared with the screens before**: of 135,
  the ones that changed are the 15 where the console is seen (each
  session's boot; menu's and colors-bare's last; colors-win's first;
  usb-plug's first four); every screen of a window is the same, pixel
  for pixel, with rio read from the card.
- `tests/session-ix-b` (/boot's listing: three names fewer),
  `tests/session-card-ix` (the partition's bin listed, and /bin with
  it).
- Not done: without a card there is no rio (`mini-pi -g mini-9pi`
  makes the card and gives it, on the Pi1); the Pi4 has no card of
  ix's yet (its firmware: stage 8); a real Pi1 boots this card's
  kernel from the FAT and would find rio the same way, not tried.

- **A bug of mini-rio's found on the way** (docs/plans/bugs/ix.md):
  the line typed after a program that read the keyboard had ended was
  lost. hellorio's read of the console was waiting when it ended, and
  stayed in the window's list of readers: it took the next line.
  `P9_server` now forgets the reads that wait for a file closed or a
  request flushed (9P's Tflush did nothing there), and tells who
  answers whether someone still waits; the window gives the line to
  the next reader. How it showed: `win-new` typed `q` and Enter to
  end hellorio, the Enter was the line lost, or not, by how fast
  hellorio ended: the session failed one run in three with the
  kernel's USB, which yesterday was put on the machine's load. The
  step is the key alone now, and the session's last screen has "back
  in rc" printed, which the recorded one had not.
- **`make check-all`, whole and green for the first time**
  (2026-10-06, evening, the machine quiet): exit 0 in 14 minutes, 76
  lines of "ok" (the twin's and ix's 54, the card's 9, the kernel by
  ix's tools 13), no second try of a graphical check. So the two not
  seen passing the afternoon before are seen: `check-windows` (18,
  with the card) and `mini-mk check` (13, counted). With test-lite
  (34), fat.sh (39), xv6fs.sh (30), compile_ix.sh on windows, lib_networking/9p
  and the kernel (122 files).

2026-10-06, **the xv6 partition is the root** (the author: "let's not
mount the fat partition in /root but instead in a /mnt/fat maybe? and
for the root, let's use the xv6 filesystem but let's create some
directories in it like bin/arm/ usr/pad, etc. and bind bin/arm/ to
/bin as a union bind").
- **The partition's layout** (`make card`, mini-mkfs): `bin/arm`
  (mini-rio, hellorio, mini-colors, hello), `usr/pad` (a readme),
  `mnt/fat`, `tmp`. mini-mkfs makes an empty directory of a name that
  ends with / (`mnt/fat/`).
- **boot.rc**, as Plan 9's boot does with its file server:
  `bind -c '#x' /root` (the partition, by the kernel's `Kfs`),
  `bind -a /root /` (its directories after the kernel's own at /: so
  /usr and /tmp are its), `bind -c /root/mnt /mnt`,
  `bind -a /root/bin/arm /bin` (a union: /bin is a kernel's directory,
  the partition's programs after it; what the boot needs is still
  found in /boot, the path's second), `home=/usr/pad` and the shell
  starts there. **The FAT is at /mnt/fat** (dossrv's mount, or the
  kernel's `bind -c '#Fdos' /mnt/fat` when dossrv is not in the
  image): the firmware's files, the kernel among them.
- **Checked**: `check-card`'s sessions for the new places: `ls -l /`
  (the kernel's directories, and usr, tmp from the partition; bin and
  mnt twice, one of each), /bin's four programs, `cat readme` and
  `hello` from /usr/pad, a file written there by a relative name and
  read by /usr/pad's and /root/usr/pad's; the FAT's files at
  /mnt/fat, read and written through dossrv, then through the
  kernel's device bound on /tmp; with neither usbd nor dossrv in the
  image, the same places by the kernel alone. The graphical sessions'
  screens did not change (the console's lines are the same).
- Not done: `ls -l /` shows bin and mnt twice (a union lists each
  directory's entries: Plan 9's does too); the Pi4's card.

2026-10-07, **pwd, mkdir, rm and cp** (the author: "let's write a few
more utilities and add them on the xv6 partition", after goken's,
principia's and xix's utilities/).
- **utilities/files**: `Pwd`, `Mkdir` (-p, -m), `Rm` (-r, -f), `Cp`
  (to a file, or several to a directory), each one file, written from
  principia's C (187 lines for 440), its messages and statuses. Not
  cp's -g, -u, -x: they are a wstat, which ix's `Unix` does not have.
- **What they needed**: Plan 9's `Unix` has `mkdir` (create with
  DMDIR: bit 31, an Int32 for arm's int), `unlink` and `rmdir`
  (remove, one call), `getcwd` (fd2path of "."); `FS` gives them with
  a capability (`open_out_fd`, `mkdir`, `remove_any`, `getcwd`). The
  kernel's xv6 device made files only: `Kfs` makes a directory too.
- **On the card**: bin/arm has the four (`CARD_BIN`), so /bin by
  boot.rc's union.
- **A bug of the kernel's found** (bugs/ix.md): a directory made on
  the kernel's own FAT (`Kdos`, no dossrv) was a file: DMDIR looked
  for at bit 31, which a Pi1's int does not have. Fixed.
- **Checked**: `utilities/tests/differential.sh`, 98 cases as
  principia's binaries under mini-5i (47 new: each of the two in its
  own copy of a directory, the output, the status and what is there
  after compared); `check-card`'s sessions: in /usr/pad a directory
  and one in it made, files copied there, pwd after cd, rm refusing
  what is not empty, rm -r; the same on the FAT through mini-dossrv,
  and through the kernel alone (`session-card-ixk`).
- `FS` and `Files` merged (the author: "we probably need to merge FS
  and Files also at some point"): done 2026-10-07, below.

2026-10-07, **mv, touch and chmod, and the wstat they need** (the
author: "let's commit and do a few more and extending Kfs and Kdos as
needed").
- **utilities/files**: `Mv` (the name changed when the directory is
  the same, a directory's too; else a copy and the old one removed),
  `Touch` (-c, -t), `Chmod` (octal, or [who]op[rwxalt]): 230 lines
  for principia's 455 of C.
- **`Sys_plan9`**: `rename`, `chmod`, `set_mtime`, each a wstat of one
  field (the rest all ones: unchanged); on another system, Unix's
  rename, chmod, utimes. `FS.create_fd` (touch's file, which must not
  be there).
- **`Fat`** (lib_fat): `rename` (new entries, its long name's too,
  then the old ones taken away: the file's place, its identity,
  changes), `set_mtime`, `set_read_only` (FAT's one permission). The
  kernel's `Kdos` and mini-dossrv: a wstat does the three; a file
  that is only read is not opened to be written.
- **`Xv6fs`** (lib_xv6fs): `rename` (the entry's 14 characters), and
  **ix's second extension to xv6's format: the time a file was last
  written, at the inode's byte 12** (the 4 bytes left of the 8 xv6
  does not use; 0: not known, shown as the kernel's date). `Kfs`
  writes it at a create, a write and an emptying, and at a wstat; a
  name changed too. xv6 keeps no permissions and no place is left for
  them: a chmod that would change what is shown (rw-rw-rw-, a
  directory rwxrwxrwx) is refused, "xv6's file system keeps no
  permissions". kernels/xv6's `Fs` (mini-xv6) does not read that time.
- **Checked**: `differential.sh`, 147 cases as principia's under
  mini-5i (49 new; mini-5i's wstat changes no time, so touch's time
  is not compared there); `fat.sh`, 51 (12 new: names changed to a
  long one and back, in a directory, a directory's, read by mtools; a
  time read by mdir, read only by mattrib; fsck.vfat clean on FAT12,
  16 and 32), `xv6fs.sh`, 36 (6 new); `check-card`'s sessions: on the
  root, files and a directory renamed, a file moved into a directory,
  a time set (ls -l: Sep 9 2001), chmod refused; on the FAT by
  mini-dossrv and by the kernel alone, a long name given, a time, a
  file made read only (rc cannot open it to write) and back, a
  directory renamed, a file moved from the FAT to the root.
- **Found, not fixed: a program's clock is 0.** The kernel's
  `/dev/bintime` is a stub (24 zeros), so `Unix.time ()` is 0 in every
  program of ix's: touch without -t sets 1970 (the FAT's 1980, its
  first year; on the root 0 is "not known", the kernel's date), a
  file written through mini-dossrv is of 1980 (`Kdos`, which has the
  kernel's clock, says Sep 26 2026), and mini-ls has every file in
  the future (so its dates show a year, never an hour). A real clock
  there changes what `ls -l` prints in the recorded sessions, by the
  minute of the run: to decide with the author.
- Not done: a file renamed on the FAT while another channel has it
  open (that one's file is then not found); cp's -g, -u, -x.

2026-10-07, **the clock** (the author, on what is above: "the clock in
principia's kernel was not handled correctly there either").
- **The kernel**: `Dev.epoch`, the seconds since 1970 when it started:
  0 until someone writes them to `/dev/time` (decimal, as Plan 9's),
  so with principia's programs the time is still 9pi's, the seconds
  since the start, and the consoles recorded from the C kernel are
  the same. `/dev/time` and `/dev/bintime` (it was 24 zeros) say the
  clock; a Pi1's int has 31 bits, so the seconds in decimal and the
  nanoseconds' 8 bytes are made by hand (`Devcons`'s `unsigned`,
  `nanoseconds`). `Dev.now`, the time `Kfs` and `Kdos` write: the
  clock's, from the kernel's date until it is set.
- **conf/boot.rc** sets it: `echo 1790380800 > /dev/time`, the day
  mini-9pi was started (the Makefile's KERNDATE_IX): a Pi has no clock
  chip. So `Unix.time ()` is a time: mini-ls says an hour for what is
  recent (`Sep 26 00:00`, where it said `Sep 26  2026`), a file
  written through mini-dossrv is of that day and not of 1980, touch
  without -t works.
- **The recorded consoles**: the minute of what a session wrote is the
  run's; the Makefile's `unwarned` makes it `00:MM`, and the four
  sessions of ix's programs are recorded so (session-ix: a pid one
  more, boot.rc's echo).
- Not done: the hour is GMT's (no /env/timezone); nothing sets the
  clock from outside (a network's time, a `date -s`).

2026-10-07, **date, mtime, wc, basename, tee and cmp** (the author:
"let's do them in order, 1, 2").
- As principia's directories: utilities/time (`Date`: -n, -u, the
  seconds given), utilities/pipe (`Tee`: -a, -i), utilities/compare
  (`Cmp`: -l, -L, -s, the offsets), utilities/misc (`Basename`, `Wc`:
  -l, -w, -c, -r, -b, Unicode's spaces), utilities/files (`Mtime`):
  267 lines for principia's 524 of C. `FS.open_append_fd` (tee
  -a). On the card's bin/arm.
- **Checked**: `differential.sh`, 202 cases as principia's (55 new;
  tee with a standard input and its files compared; date without
  seconds is not compared, nor an option alone that mini-5i takes for
  itself: -s, -t); the card's session (`session-card-ix`): mtime of a
  file touched, date, wc of two files, basename, a pipe through tee to
  two files and wc, tee -a, cmp of the two (EOF) and of two that are
  the same.
- **Found: a program from the card takes 1.7 s to start** under QEMU
  (4.5 s for the boot, 13.3 s with five commands after): `Xv6fs` has
  no cache of blocks, by its design, and a program of 650 KB is read a
  block at a time from the SD card, each block's number read first.
  The session of the card has 30 such programs now: 2 minutes 17
  under QEMU (its limit raised to 240 s, mini-qemu's to 600).

2026-10-07, **the checks' time** (the author: "this is long, anything
we can improve to reduce the time for those make check-all?"; the
measures: docs/notes_performance.md, section 3).
- Most of a session's time was not the kernel's: `session.py` waits a
  second with no output before it types a line. `--quiet S`; ix's
  sessions have 0.3 (`IXQUIET`).
- `check-ix`'s and `check-card`'s sessions at once, not one after the
  other.
- **A cache in `Kfs`**: the card read by pieces of 4 KB, kept (2 MB at
  most); `Kfs.cached` turns it off. A program's first start from the
  card 1.76 s to 1.35, the next ones as from the kernel's image.
- `check-ix` 39 s for 2 minutes 10, `check-card` 3 minutes 12 for 8
  minutes 30.

2026-10-07, **`Files` merged into `FS`** (the author: "let's go with
FS": xix's name, the capabilities' own in `Cap` (`fs`), and what the
module does, which is more than files: mkdir, getcwd; mini-oberon's
own `Files` is then the only one).
- `FS` has `read`, `read_opt`, `write`, `write_perm` and `path`, under
  an `ix:` comment; lib_core/commons/Files.ml and .mli are gone; 98
  uses in 36 files say `FS.`; `COMMONS` (mkfiles/mkconfig) and the
  dune library without `Files`.
- **Checked**: `make test-lite` (34 jobs: every file by mini-ml, ix
  built by ix); `mini-mk O=5` (arm); kernels/9pi's `make check-ix`
  (Plan 9's programs linked and run); `differential.sh`, 202.

2026-10-07, **the card's session cut in short ones, and five programs
more** (the author: "let's do 2 and then 1 then").
- **check-card**: `session-card-ix` was one session of 73 lines, 3
  minutes under mini-qemu. Now five, all at once (`CARDS_IX`, one rule
  for all): `card-ix` (the card as boot.rc leaves it, its FAT by
  mini-dossrv then by the kernel's device), `card-files` (pwd, mkdir,
  cp, mv, touch, chmod, rm on the root), `card-fat` (the same on the
  FAT), `card-text` (mtime, date, wc, basename, tee, cmp), `card-misc`
  (below). `make check-card`: 68 s for 3 minutes 12.
- **utilities**: `Sleep` (utilities/process: seconds, and thousandths
  after a point), `Unmount` (namespace), `Seq_` (misc; the unit's name:
  `Seq` is the standard library's; -w; not -f format), `Cleanname`
  (misc; -d), `Du` (misc; -a, -s, -n, -b, -f; not -e, -h, -p, -q, -t,
  -u, -r): 216 lines for principia's 544 of C. `FS.cleanname` (libc's;
  mini-mv's own moved there), `Sys_plan9.unmount`.
- **Checked**: `differential.sh`, 253 cases (51 new). seq against
  plan9port's on the host, not principia's: its arm binary computes
  with the FPA's instructions, which mini-5i does not have (and
  plan9port's rounds the count of steps: `seq 1 100000 1000000` ends
  with 1e+06 there, at 900001 for principia's seq.c and ours).
  `session-card-misc` on the card: cleanname, seq, du of a directory
  made there, sleep, a bind listed, unmounted, listed again, and
  "not mounted" the second time.

2026-10-07, **every source is text; grep, tail and xd** (the author:
"let's do 1, and then 2").
- **tests/text_files.sh**, in `make test-lite`: no control byte but a
  tab and a newline in a source (OCaml's, C's, assembly, the scripts,
  the build files, the documents: 1,648 files, 3 s). linker/Exe.ml had
  six characters written raw, a NUL among them, for two weeks: git,
  file and magit took it for a binary file, and so did the check that
  the merge of `Files` into `FS` had renamed every use.
- **utilities**: `Grep` (utilities/text: -v, -i, -n, -c, -l, -L, -s,
  -h, -e, -f; on lib_core's `Regex`, mini-ed's: a line is matched by
  each pattern in turn, where grep.c makes one automaton of them all),
  `Tail` (pipe: -N, +N, -n, -c, the b, c, l, r and f after a number,
  -r, -f; the file read whole, where tail.c reads back from its end),
  `Xd` (utilities/byte: -c, the sizes and the bases, -a, -r, -s; not
  -R): 345 lines for principia's 2,151 of C.
- **Checked**: `differential.sh`, 321 cases (68 new); on the card,
  `session-card-search`: grep of the root's and the FAT's files, a
  pipe of ls, grep and tail, seq into tail and tail -r, xd of a file
  and of a pipe.
- **A bug of principia's xd found** (docs/plans/bugs/goken.md, 34):
  `xd -r` loses the file's end after lines that are the same. Not
  copied. And one of tail.c's copied: `tail -0` is the whole file.

2026-10-07, **uniq, tr, sed and sort; ps, time and kill** (the author:
"let's do 1 while it's fresh in our memory", "and 2").
- **utilities/text**: `Uniq` (-u, -d, -c, -N, +N), `Tr` (-c, -d, -s;
  ranges, \ooo, \xhhhh; by characters, not bytes), `Sed` (every
  command of sed.c's: p d q = s y a i c n N g G h H x D P l r w, the
  labels with b and t, { }, the addresses and their ranges, !, -n -g -e
  -f; on `Regex`; the script a list of commands and its jumps, as
  sed.c's), `Sort` (-b -d -f -g -i -n -r -w, +pos -pos and -k keys
  with their own letters, -t, -u, -c, -o; a line's key made of bytes
  once, as sort.c's: a number's sign, its point's place and its
  digits, a reversed key's bytes complemented; in memory, no
  temporary file; not -M). 944 lines for principia's 3,723 of C.
- **sed.c's oddities kept**, each said in the code, because the
  differential test says so: c writes its text only when its address
  is a line's number or a regexp; N at the last line writes nothing; D
  ends the cycle and what is left is written. And uniq.c's: a last
  line without its newline is not read.
- **utilities/process**: `Ps` (-a, -p, -r: /proc read), `Time` (a
  command run, its three times: `Sys_plan9.last_times`, the kernel's,
  from the line a wait reads), and **kill as Plan 9 has it, a script**
  (kill.rc: ps through sed, a line `echo kill>/proc/N/note` a process,
  for rc to run): mini-rc, mini-ps and mini-sed run principia's own
  script as it is. On the card in rc/bin, bound after /bin.
- **boot.rc**: the machine's owner said (`echo -n pad >
  '#k/hostowner'`: files and processes were nobody's, and ps's lines
  one word short); /boot bound after /bin (a script's `#!/bin/rc`);
  the card's rc/bin bound there too.
- **mini-5i** took -s, -t and -y for its own wherever they were, after
  the program's name too: `ls -s`, `cmp -s`, `tail -t`, `tr -s` could
  not be tested. Now only before the program's name; the cases are in.
- **Checked**: `differential.sh`, 481 cases (160 new: uniq 15, tr 25,
  sed 59, sort 52, the cases mini-5i hid); on the card,
  `session-card-filter` (the four in pipes with seq, ls, grep, tail)
  and `session-card-proc` (ps's owners and names, time of a command
  that ends, of one that is not there, a sleep in the background
  killed by `kill sleep | rc` and gone from ps).
- Not done: sort -M; sort's and uniq's characters past ASCII under
  -f and -d (sort.c has Unicode's tables); tr's and sed's are right.

2026-10-07, **test and xargs** (the author: "let's do 1"): what a
script asks and builds.
- `Test` (utilities/misc: the files' questions -e -f -d -s -r -w -x -A
  -L -T, -t, the strings', the numbers', -older with a time or an age,
  -nt, -ot, !, -a, -o, the parentheses; as [ too) and `Xargs`
  (utilities/pipe: -n lines, -p procs): 177 lines for principia's 551
  of C. test.c opens a file to know whether it may be read, written
  or run; `Test` reads its permissions.
- **Checked**: `differential.sh`, 549 cases (68 new; xargs with
  principia's arm echo as its command, one at a time); on the card,
  `session-card-script`: rc's if, && and || on test's answers, a for
  over files, ls and grep into xargs, xargs -n.

2026-10-08, **a window's border is a handle** (the author: "I was not
able to resize when hovering on the border of a window"): rio's, which
was not there (a window changed by the menu's Resize and Move only).
- **The mouse on a border**: the cursor of that corner or side (rio's
  eight, `Cursors.corners`; a corner is the 20 pixels at a side's end,
  as rio's `whichcorner`), the arrow again when it leaves.
- **A button pressed there**: the left or the middle one pulls that
  corner or side, the others staying where they are; the right one
  moves the window, the cursor a box. The outline follows the mouse
  (the sweep's), and the window is told at the button's release, by
  the message the menu sends (`Reshape`). Smaller than 100 by 50, it
  stays as it was. The border of a window that is not in front brings
  it there first.
- The border is the window system's even when the window's program
  reads the mouse (`Window.on_border`: rio's `winborder`): a game's
  window can be pulled.
- `Rio.band` is the one loop under the sweep, Move and the border (they
  were two copies); `show` tells the kernel a cursor only when it is
  another. `windows/` is 925 lines (837), 54 of the 88 the cursors'
  bits.
- Not as rio's: the mouse is not put on the corner at the press (the
  corner keeps its distance to it); a second button does not cancel.

Checked: `win-border` (`tests/win-border.steps`, in `make check-rio`
and `check-windows`): the corner's cursor, the corner pulled with the
left button (the outline half-way), a command, the window pulled by
its top with the right one, its left side with the middle one, a
command after each: 16 screens, the same under mini-qemu and QEMU.
The five other window sessions show their recorded screens (the sweep
and Move go through `band` now). Run in a copy of the tree, the
kernel as committed.
