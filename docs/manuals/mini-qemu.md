# mini-qemu: a user's manual

mini-qemu (`raspberry/`, `machine/`) emulates a Raspberry Pi 1 (ARMv6,
32-bit) and a Raspberry Pi 4 (ARMv8, 64-bit, one to four cores). It
understands the part of QEMU's command line that the Pi kernels'
Makefiles use, so it can stand in for `qemu-system-arm` or
`qemu-system-aarch64`. Everything in it is OCaml you can read: every
instruction, device access, USB transfer and network frame. That makes
it a machine you can look inside, which QEMU is not. This manual covers
how to run it and how to look inside it. How it works is the tutorial
[notes_pi.md](../tutorials/notes_pi.md); what it must do and why is
[plan_pi.md](../plans/plan_pi.md).

## 1. The quick way: mini-pi

`mini-pi` (at ix's top, and `bin/mini-pi`) builds and boots a kernel
without the long command line:

    ./mini-pi mini-9pi          # ix's Plan 9 kernel in OCaml, Pi1, to rc's prompt
    ./mini-pi -g mini-9pi       # the same, in a window: type rio there
    ./mini-pi -g -p c mini-9pi  # with principia's C pixels instead of the OCaml ones
    ./mini-pi mini-9pi4         # the same kernel on the Pi4 (arm64)
    ./mini-pi mini-xv6-pi1      # ix's xv6 in OCaml; mini-xv6-pi4 on the Pi4
    ./mini-pi 9pi               # principia's own C 9pi
    ./mini-pi xv6 | xv6-pi1 | xv6-pi4   # xv6-multiarch's C kernels

Options:

| option | effect |
|---|---|
| `-g` | a window: the framebuffer, a USB keyboard and mouse |
| `-p c` / `-p ocaml` | mini-9pi's pixels (its draw device's memdraw): OCaml (the default) or principia's C |
| `-w` | 9pi: keep the writes to the SD card image (by default they are lost at exit) |
| `-q` | run QEMU instead, with the same arguments, to compare |
| `-d` | mini-qemu's log (section 4.1) |
| `-n` | no build: the kernel as last built (and so `-p` is ignored) |
| `-v` | verbose, to see where it blocks: each build step's output and time, then mini-qemu's `-status 2` with the kernel's symbols (section 4.6) |
| `-c N` | xv6-pi4: N cores |

`./mini-pi` alone prints the full usage. Quit with Ctrl-A then x, or
close the window.

## 2. The command line

    mini-qemu -M raspi1ap -nographic -kernel kernel.img
    mini-qemu -M raspi1ap -nographic -device loader,file=kernel.img,addr=0x8000,cpu-num=0,force-raw=on \
              -drive file=sd.img,if=sd,format=raw,snapshot=on -device usb-kbd -device usb-mouse
    mini-qemu -cpu cortex-a72 -M raspi4b -kernel kernel.elf -m 2G -smp 1 -nographic

QEMU's options that mini-qemu takes:

| option | meaning |
|---|---|
| `-M raspi1ap` / `raspi4b` | the board |
| `-kernel F` | the kernel: a raw image at 0x8000 (Pi1), an ELF (Pi4) |
| `-device loader,file=F,addr=A` / `-bios F` | a raw image at an address |
| `-drive file=F,if=sd[,snapshot=on]` | the SD card; with `snapshot=on` the writes stay in memory |
| `-device usb-kbd`, `usb-mouse`, `usb-net` | USB devices behind the DWC2 controller |
| `-m SIZE` | the Pi4's RAM (default 2G; the Pi1 always has 512MB) |
| `-smp N` | the Pi4's cores, 1 to 4 (default 1, the fastest: the cores take turns) |
| `-nographic`, `-display none` | no window |
| `-serial stdio\|mon:stdio\|null` | the UARTs, in order |
| `-qmp unix:PATH,server,nowait` | the machine protocol (section 4.3) |

It accepts and ignores `-cpu`, `-monitor`, `-append`, `-D`,
`-no-reboot`, `-S` and `-netdev`. A usb-net's network is always
mini-qemu's own user-mode one (`Usernet.ml`). The guest is 10.0.2.15,
the host is 10.0.2.2, and TCP to 10.0.2.2 reaches the host's
127.0.0.1.

Options only mini-qemu has:

| option | meaning |
|---|---|
| `-ips N` | instructions per simulated microsecond (default 30): the system timer's rate |
| `-d` | the log of what the guest did wrong (section 4.1) |
| `-trace N` | the Pi4: the first N instructions, disassembled (section 4.2) |
| `-prof F` | a guest profile: every 1024th PC counted, written to F at exit (section 4.5) |
| `-status N` | every N seconds, where the guest is: its time, how idle, its hot functions (section 4.6) |
| `-symbols ELF` | the kernel's ELF, for `-status` to name the PCs |

## 3. The console, the window, the clock

- **The serial console** is the terminal. On a tty, standard input is
  raw, as with QEMU's `-nographic`, and Ctrl-A x quits. Without a tty
  (a pipe, a test script), the input is read to its end and then
  closed. The tests drive the console this way
  (`kernel/lib/session.py`).
- **The window** (SDL, when `$DISPLAY` is set and there is no
  `-nographic`): the framebuffer, redrawn when it changes. Keys go to
  the USB keyboard. A click grabs the host's pointer for the USB
  mouse, which moves relatively, as a real one does, and Ctrl-Alt-G
  releases it.
- **The clock.** Without a window, the board's time is the
  instructions' (`-ips`): a run is deterministic, with the same
  output and the same screens every time. The tests rely on that.
  With a window, the board's time is paced to the host's: an idle
  kernel's WFI skips ahead to the host's time, but it is never let
  run ahead of it (a key's repeat depends on it). A busy kernel falls
  behind, as a slower machine would.

## 4. Looking inside

### 4.1 The log: `-d`

`-d` prints to standard error what a real board would do silently or
fatally:

    mini-qemu: unassigned read at 0x20215040
    mini-qemu: undefined instruction e7f000f0 at 0x80012345

An **unassigned** access is a device register that mini-qemu does not
emulate, at that physical address (Pi1 I/O at 0x20000000, Pi4 at
0xfc000000), logged once per address and direction. Reads return 0
and writes are dropped. When a new kernel
hangs at boot, this is usually the first thing to look at: it names
the device the driver is waiting on. An **undefined instruction** is
logged before the guest takes its exception: either the kernel's bug
or one of mini-qemu's missing instructions (then see
`machine/tests/census_*.txt`, the instructions the corpus uses).

### 4.2 The instruction trace: `-trace N` (the Pi4)

    mini-qemu -M raspi4b -kernel kernel.elf -nographic -trace 2000      # the first 2000
    mini-qemu -M raspi4b -kernel kernel.elf -nographic -trace -100000   # every 100000th

Each line is `[core] pc elN instruction`, disassembled:

    ffff000000080010 el1 msr vbar_el1, x0

The first form is for the boot, up to the MMU turned on and the first
exception level change. The second is a cheap sampling profile: which
code a long run is in.

### 4.3 The machine protocol: `-qmp`

As in QEMU, `-qmp unix:/tmp/q.sock,server,nowait` opens a socket that
takes JSON commands, one a line. mini-qemu polls it between batches of
instructions, so it never blocks. It knows:

| command | effect |
|---|---|
| `qmp_capabilities` | the handshake |
| `query-status` | running |
| `screendump` `{"filename": F}` | the framebuffer as a PPM file, as QEMU writes it |
| `send-key` `{"keys": [...], "hold-time": ms}` | keys on the USB keyboard, by QEMU's qcodes |
| `input-send-event` | QEMU's input events: relative motion, buttons and the wheel to the USB mouse, keys to the keyboard |
| `quit` | exits |

For example:

    $ socat - UNIX-CONNECT:/tmp/q.sock
    {"execute": "qmp_capabilities"}
    {"execute": "screendump", "arguments": {"filename": "/tmp/s.ppm"}}

Because mini-qemu and QEMU speak the same protocol, the same script
drives both, and their screens can be compared byte for byte. That is
how the graphics are tested: `raspberry/tests/graphics.py` for xv6,
`kernel/9pi/tests/graphics.py` for rio, and `kernel/lib/session.py
--usb --screendump` for a typed session.

### 4.4 Comparing with QEMU

Most bugs are found by running the same thing under both and
diffing: the console (`session.py ... -- mini-qemu ...` then
`-- qemu-system-arm ...`), the screens (screendump), and for the
Pi4, the instruction trace against QEMU's `-d in_asm,exec`. `mini-pi
-q` runs QEMU with mini-pi's arguments. The techniques, bug by bug,
are in
[notes_debugging_techniques.md](../notes_debugging_techniques.md).

### 4.5 A guest profile: `-prof F`

`-prof F` counts the PC of every 1024th instruction the guest runs and
writes the counts to F at exit, one line each: `pc count`, in
hexadecimal, the most sampled first. Any exit works: Ctrl-A x, QMP's
`quit`, closing the window, or SIGTERM. `pcprof.py` maps them to the
kernel's functions:

    mini-qemu -M raspi1ap ... -prof /tmp/prof.txt
    kernel/9pi/tests/perf/pcprof.py /tmp/prof.txt kernel/9pi/build/pi1-ocaml/kernel.elf

     37.8% __aeabi_idivmod
     17.9% memmove
     10.6% mark_slice
      ...

Samples below the kernel's first symbol are counted as `(user)`: the
user programs. On the Pi4, only the AArch64 state is sampled (the
kernel), not the AArch32 programs. When off, the cost is one test per
instruction. The case that earned the option, mini-9pi's OCaml pixels
6 times slower than the C ones, is
[notes_performance.md](../notes_performance.md), case 1.

### 4.6 Where is it? `-status N` (and `mini-pi -v`)

A boot that prints nothing more: is the kernel stuck in a loop, waiting
for a device, or only slow? `-status N` prints a line on standard error
every N seconds of the host's (`raspberry/Status.mli`); `-symbols ELF`
names the PCs from the kernel's ELF. `mini-pi -v` passes both (`-status
2`), and also shows each build step's output and time (a first build
of ocaml-light takes about 5 minutes, silent without `-v`):

    ./mini-pi -v mini-9pi
    ...
    mini-qemu: [4s] board 2.7s (+1.4s), idle 0%: 30% svc mark_slice, 13% svc memmove, 12% svc sweep_slice, 8% usr (user)
    ...
    %
    mini-qemu: [12s] board 26.9s (+11.2s), idle 97%: 1% svc Proc_fun_281; waiting at svc wait_interrupt+0x4

The host's time; the board's (and how far it went since the last
line); the share of the board's time the CPU waited at a WFI (the time
skipped to its next interrupt); where the rest went, the most first,
each with the CPU's mode (Pi1: usr, svc, irq, ...; Pi4: el0, el1, or
a32 for an AArch32 program). A sample is taken after each batch of
instructions, the batch charged to its last PC. User programs are
counted as one, `(user)`.

Reading it:

- **booting**: idle near 0%, the kernel's functions (above: the boot's
  OCaml heap, `mark_slice`, and copies).
- **at a prompt, waiting for input**: idle near 100%, `waiting at` the
  kernel's WFI, the board's time running ahead of the host's (no
  window: an idle kernel's time skips to its next tick).
- **waiting forever for a device**: the same line, but no prompt: the
  console's last lines say what it was doing.
- **stuck in a loop**: idle 0%, one function near 100%, line after
  line.


## 5. Coming: the activity monitor

[plan_monitor.md](../plans/plan_monitor.md) adds live counters (CPU
user, kernel and idle; exceptions; device accesses; USB transfers;
network frames; SD sectors) shown in a panel beside the screen with
`-g`, as a status line in the terminal, and as QMP's `query-stats`.
Its parts will be folded into this manual as they land.
