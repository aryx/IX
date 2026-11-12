# Plan: tiny-kernel's boot image only what boots, the rest on the disk

The author (2026-11-12), of boot.img nearing its 10 MB limit: "I think
the /examples can be on the disk instead of the boot; they are not
needed to boot", then: "in theory we need just a few bin for the boot;
the rest can be on the disk", and: "usually a boot is mostly a kernel
and very basic programs that are needed to then load the disk and other
sysadmin thing (in plan9 it is like that with the bind and mount and
boot.rc)".

## Today

`boot.img` (tiny/Buildfile's boot.img) is the kernel followed by every
file the system has but its sources: 9.15 MB, against a limit of 10 MB
(TinyKernel/Makefile refuses more: past it are KFS.ml's
buffers).

| part | size |
|---|---|
| the 31 programs of `/bin` | 7.4 MB (ml 670 KB; cc, office, www about 420 KB each) |
| `/lib/ml`'s `stdlib.a` | 0.44 MB |
| the kernel | 0.39 MB |
| `/examples` | 0.2 MB |
| the rest of `/lib` | small |

`disk.img` (TinyKernel/Makefile) has `/src` alone, 8 MB, what the web
page fetches; a run or a test grows a copy to 64 MB. When there is a
disk, it is the root, in a union with `/boot`, `/dump` and the image's
files (TinyKernel.ml's boot); without one, the image's files are all
there is. The first process is `/bin/sh`.

Most of `make check`'s sessions boot without a disk (emacs, office,
tetris, www, troff, play, prof...); sessions 20 and 28 boot with a
copy of it.

## What it becomes

A boot is a kernel and the few programs that bring the disk up, and
let a person repair it when they cannot; the system is on the disk.
Plan 9's: the kernel runs `/boot/boot` from its image, whose
`boot.rc` mounts the root from the file server and binds it together
(`mount`, `bind`), then runs `init`, and every program after comes
from the root. tiny-kernel has the first half inside the kernel:
TinyKernel.ml's boot mounts the disk and makes the union itself (its
`boot.rc`), then runs `/bin/sh`.

- **boot.img**: the kernel and `/boot`'s few programs: the first
  process and what a person needs when the disk does not come up
  (decision 2): with the kernel about 1.3 MB (sh 80 KB, rc 270 KB,
  utils 315 KB, ed 245 KB), from 9.15 MB.
- **the disks**: the system, `/bin`, `/lib`, `/examples`; and the
  sources, `/src` (decision 1).
  The image has no `/lib`: what a program links is the disk's, as the
  programs that link it are. Its one file the kernel reads at boot,
  `/lib/memory` (MEMORY=segments or pages, the kernel's way of giving
  memory), is the boot's configuration, not the system's: it becomes
  `/boot/memory`, as Plan 9 keeps plan9.ini apart.

The first process stays `/bin/sh`, found on the disk through the
union; without a disk, the image's own shell instead (decision 2).

Later, and apart (a kernel change): the boot's work out of the kernel,
Plan 9's way, a script run by the image's rc that mounts the disk and
binds the root, with `mount` and `bind` as system calls.

tiny/Buildfile says which files are which: a list for the image, and
the disk's, which TinyKernel/Makefile's disk.img copies (it makes the
disk, by tiny-mkfs, on the host; build install puts `/lib` there on
tiny-kernel).

## Decisions

1. **Two disks: the system and the sources** (decided, the author: "I
   like the 2 disk thing too"). The system's disk, the root: `/bin`,
   `/lib`, `/examples` (about 8 MB); the sources' disk at `/src` (8 MB
   today). A machine runs the system with its first disk alone; the
   second is for building it (make self, the toolchain's sessions).
   And the system's disk alone enforces that `/lib` is enough to
   build a program (the author: "having 2 disks allows us to strongly
   enforce that a /lib is enough to compile user programs"): with no
   `/src` there, a program built on it, `/examples`', can only use
   what build install put in `/lib` (the runtimes, the libraries'
   objects and interfaces, the headers); with one disk, a Buildfile
   could reach into the sources unseen (the examples did, until
   d1d70ffc).
   Neither the machine nor the kernel has two today: tiny-machine has
   one disk device (TinyMachineDevices' `disk`, one `-d`) and
   TinyKernel.ml's boot mounts one (step 0).
2. **What `/boot` keeps: the repair kit** (decided, the author: "I like
   the repair kit idea"). Plan 9's `/boot` has the programs to bring
   the root up and to repair it; here the kernel brings it up, so what
   is left is the kit to look at a disk and mend it: `sh`, the first
   process when there is no disk; `rc`; `utils`, under its names (`ls`,
   `cat`, `cp`, `mv`, `rm`, `mkdir`...); `ed`. The first process is
   `/bin/sh` on the disk, the image's when there is none.

The tests do not weigh on what the image keeps (the author: "what we
need for testing is another thing, and should not influence too much
the boot vs disk thing"): a session that runs the system boots with a
copy of the disk, as 20 and 28 do already (step 3).

## Steps

0. Two disks: tiny-machine's second disk device (its registers after
   the first's, a second `-d`), the web page's; tiny-kernel mounting
   the second at `/src`. KFS keeps one disk's state in
   global refs today (`fs_io`, `fs_blocks`, `fs_nfree`, `fs_fresh`,
   `fs_next`...): a record of them for each disk, passed to its
   functions; its test (KFS_test.sh) on two.
1. tiny/Buildfile: the image's list and the disk's; boot.img of the
   first; `/lib/memory` as `/boot/memory` (its reader, TinyKernel.ml's
   boot, and KMemory.ml's comments with it); the comments.
2. TinyKernel/Makefile: the system's disk (`/bin`, `/lib`,
   `/examples`) and the sources' (`/src`), each by tiny-mkfs; the
   10 MB check kept, for the image.
3. The tests: each session that runs the system given a copy of the
   system's disk, the toolchain's the sources' too; session 28,
   `/examples` built and run, on the system's disk alone (so that
   `/lib` is enough); check.expected and the screens recorded again
   after a look.
4. The web page (TinyMachine/TinyMachineWeb.ml, docs/t-ix.html): the
   disk always given; the manual's lines on the image and the disk.
5. `make self`: the image tiny-kernel builds is the new one, the disk
   its own `/bin` too (build install).

## Status

Decided: two disks (1), the repair kit (2). Done: steps 0 to 4.

Step 0, done (2026-11-12): tiny-machine's second disk at -80(r0), by a
second -d (e5d39f65); KFS's state an `fs`, given to its functions as
Linux's super_block, `fs_mount io k n` and `fs_sync`; KFiles' `Disk of
fs * tree * inode`; the boot mounting a second disk at `/src`; the
KFS test on two disks at once (in fd343ddf, another session's commit,
whose message tells only its own change). Checked: make test, make -C
tiny/TinyKernel check, self-quick; a boot on two disks, `/src`'s file
read.

Steps 1 to 3, done (2026-11-12):
- the Buildfile: `boot.img` the kernel and `BOOT` (sh, rc, utils, ed),
  under `bin/` (seen as `/boot/bin` with a disk, `/bin` without), the
  utilities' links and `memory`, read by the kernel as `/boot/memory`;
  `build install` puts the system in `BIN`, `LIB` and `EXAMPLES`
  (`/bin`, `/lib`, `/examples`), the utilities' names by `ln`. The image
  is 1.3 MB, from 9.15.
- tiny-mkfs links the host's hard links (the same device and inode):
  `/bin/cat` is `/bin/utils` on the disk too (the author chose it over
  a link syntax and over copies, 8 MB of them).
- TinyKernel/Makefile: `disk.img` the system's disk (12 MB), from
  `_make/system`, what build install put there; `src.img` the sources'
  (8 MB); both made at each make, kept when their bytes are the same
  (a program of the disk changes, the image not).
- The kernel, for the system on the disk: an exec reads the program
  from the disk straight into the process's memory (`fs_read_at` a
  piece at a time; old: the file read whole into a string first, 65
  million instructions for an `ls`); the collection counts the free
  blocks as it marks, one pass over the map (old: two), and the boot's
  banner says no free blocks (old: a second collection, at each boot).
  A boot on the system's disk, 18 million instructions (6 with no disk,
  the image's files alone); ten `ls`, 50
  million (24 with every program in the image).
- The tests: each session on a copy of the system's disk (`$(D)`), the
  toolchain's and self's with the sources' too; session 25 on a blank
  disk, the repair kit alone (rc copied and run, ed written over);
  session 28 builds `/examples` with `/lib` alone. Scripts that assumed
  the first shell at `/` (mltests' `..`, vcs, session 5) go by `..`;
  emacscolors' screen taken later (emacs, 420 KB, read from the disk).
  Re-recorded: check.expected (the banner, the cwd, session 25), the
  `ls` of windows and nested (the empty `/usr/glenda`), self-quick's
  banner. self.keys builds `all boot.img` (calc is the disk's: a line
  added to it remakes no image). lite.sh and the network test give the
  disk; linux.py reads `/boot/bin/ed`, the image's.
  Checked: make test, make -C tiny/TinyKernel check, self-quick,
  MEMORY=segments booted.

Step 4, done (2026-11-12): the web page's disks, `disk` and `disk2`
(TinyMachineWeb.ml fetches each the page names, in turn): docs/t-ix.html
gives `src.img` as the second, make website puts it in the assets;
./tiny-machine tiny-kernel runs on both (run.img, runsrc.img), and its
-web page's address names both. The manual's lines on the image and
the disks were step 1's. Checked: TinyMachineWeb_test.py in Chrome
(`ls /` shows `src`, the second disk's), ./tiny-machine tiny-kernel.
The assets themselves (make website) not yet published.

Next: step 5, make self.
