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

Next, stage 3: the card.
