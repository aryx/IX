# mini-qemu: a user's manual

mini-qemu (`raspberry/`, `machine/`) emulates a Raspberry Pi 1 (ARMv6,
32-bit), a Raspberry Pi 2 (ARMv7, 32-bit, four cores) and a Raspberry
Pi 4 (ARMv8, 64-bit, one to four cores). It
understands the part of QEMU's command line that the Pi kernels'
Makefiles use, so it can stand in for `qemu-system-arm` or
`qemu-system-aarch64`. Everything in it is OCaml you can read: every
instruction, device access, USB transfer and network frame. That makes
it a machine you can look inside, which QEMU is not. This manual covers
how to run it and how to look inside it. The tutorial
[notes_pi.md](../tutorials/notes_pi.md) explains how it works, and
[plan_pi.md](../plans/plan_pi.md) says what it must do and why.

## 1. The quick way: mini-pi

`mini-pi` (at the top of ix, and also `bin/mini-pi`) builds and boots
a kernel without the long command line:

    ./mini-pi mini-9pi          # ix's Plan 9 kernel in OCaml, Pi1, alone: ix's own
                                # programs in its image (mini-rc, ed, ls...), no SD card
    ./mini-pi mini-9pi4         # the same on the Pi4 (arm64)
    ./mini-pi mini-9pi2         # the same on the Pi2: its four cores, the Pi1's card
    ./mini-pi mini-9pi-principia      # with principia's programs and SD card, to rc's prompt
    ./mini-pi -g mini-9pi-principia   # the same, in a window: type rio there
    ./mini-pi -g -p c mini-9pi-principia  # with principia's C pixels instead of the OCaml ones
    ./mini-pi mini-9pi4-principia     # the same kernel on the Pi4 (arm64)
    ./mini-pi mini-xv6-pi1      # ix's xv6 in OCaml; mini-xv6-pi4 on the Pi4
    ./mini-pi -g mini-oberon    # the Oberon system in OCaml (kernels/oberon/);
                                # mini-oberon4 on the Pi4
    ./mini-pi mini-singularity  # Singularity in OCaml (kernels/singularity/);
                                # mini-singularity4 on the Pi4
    ./mini-pi -g mini-squeak    # Squeak on the bare Pi4 (kernels/squeak/)
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
| `-P` | mini-9pi2: the Pi 2's four cores each on a core of the host's (mini-qemu's `-cores-parallel`, by the mini-qemu OCaml 5 builds, in `_build5`) |

`./mini-pi` alone lists the kernels; `./mini-pi --help` prints the
full usage, including the options. Quit with Ctrl-A then x, or
close the window.

## 2. The command line

    mini-qemu -M raspi1ap -nographic -kernel kernel.img
    mini-qemu -M raspi1ap -nographic -device loader,file=kernel.img,addr=0x8000,cpu-num=0,force-raw=on \
              -drive file=sd.img,if=sd,format=raw,snapshot=on -device usb-kbd -device usb-mouse
    mini-qemu -cpu cortex-a72 -M raspi4b -kernel kernel.elf -m 2G -smp 1 -nographic

QEMU's options that mini-qemu takes:

| option | meaning |
|---|---|
| `-M raspi1ap` / `raspi2b` / `raspi4b` (or `-machine`) | the board (a `,` and what follows it ignored) |
| `-kernel F` | the kernel: a raw image at 0x8000 (Pi1), an ELF (Pi4) |
| `-device loader,file=F,addr=A` / `-bios F` | a raw image at an address |
| `-drive file=F,if=sd[,snapshot=on]` | the SD card; with `snapshot=on` the writes stay in memory |
| `-device usb-kbd`, `usb-mouse`, `usb-net` | USB devices behind the DWC2 controller |
| `-m SIZE` | the Pi4's RAM (default 2G; the Pi1 always has 512MB, the Pi2 1GB) |
| `-smp N` | the Pi4's cores, 1 to 4 (default 1, the fastest: the cores take turns) |
| `-nographic`, `-display none` | no window |
| `-serial stdio\|mon:stdio\|null` | the UARTs, in order |
| `-audiodev wav,path=F` | the Pi1's jack: what its PWM plays, a WAV file written at exit (below) |
| `-qmp unix:PATH,server,nowait` | the machine protocol (section 4.3) |

It accepts and ignores `-cpu`, `-monitor`, `-append`, `-D`,
`-no-reboot`, `-S` and `-netdev`. The network behind a usb-net is
always mini-qemu's own user-mode network (`Usernet.ml`). The guest is
10.0.2.15, the host and gateway are 10.0.2.2, and TCP to 10.0.2.2
reaches the host's 127.0.0.1.

Since 2026-10-11 the network also goes beyond the gateway, as QEMU's
does:

- a TCP connection to any other address becomes a connection from the
  host to that address;
- a UDP datagram goes out from a socket on the host, and its answers
  come back;
- 10.0.2.3 is the name server (the host's own, from
  `/etc/resolv.conf`).

So a guest whose default route goes through 10.0.2.2, and which uses
10.0.2.3 for its names, reaches the Internet. On mini-9pi, run
`echo add 0 0 10.0.2.2 > /net/iproute`,
`echo 'dns=10.0.2.3' > /net/ndb`, then `curl http://example.com/`.
While mini-qemu waits for a connection to open, the board is stopped
(for 10 s at most). Ping does not work beyond the gateway, and the
host cannot open a connection to the guest.

Options that only mini-qemu has (`-h`, `-help` and `--help` print the
usage and examples):

| option | meaning |
|---|---|
| `-ips N` | instructions per simulated microsecond (default 30): the system timer's rate |
| `-cores-parallel` | the Pi 2: each started core on a core of the host's, not in turns (see "The cores" below); only in a mini-qemu built by OCaml 5 |
| `-d` | the log of what the guest did wrong (section 4.1) |
| `-trace N` | the Pi4: the first N instructions, disassembled (section 4.2) |
| `-prof F` | a guest profile: every 1024th PC counted, written to F at exit (section 4.5) |
| `-status N` | every N seconds, where the guest is: its time, how idle, its hot functions (section 4.6) |
| `-symbols ELF` | the kernel's ELF, for `-status` to name the PCs |
| `-meters on`, `-meters off` | the meters (section 5): on in a window unless `off`; `on` without a window writes their line each second on standard error |

## 3. The console, the window, the clock

- **The serial console** is the terminal. On a tty, standard input is
  raw, as with QEMU's `-nographic`, and Ctrl-A x quits. Without a tty
  (a pipe, a test script), the input is read to its end and then
  closed. The tests drive the console this way
  (`kernels/lib_machine/session.py`).
- **The window** (SDL) opens when `$DISPLAY` is set and there is no
  `-nographic`. It shows the framebuffer, redrawn when it changes.
  Keys go to the USB keyboard. A click grabs the host's pointer for
  the USB mouse, which moves relatively, as a real one does, and
  Ctrl-Alt-G releases it.
- **Random numbers.** The board's generator (the Pi 1's BCM2835 at
  0x20104000, the Pi 4's RNG200 at 0xfe104000) returns bytes from the
  host's `/dev/urandom`. mini-9pi's `/dev/random` reads from it, and
  so do the secrets of a TLS connection. In a run without a window,
  these numbers are the only thing that differs from one run to the
  next.
- **Sound.** The Pi 1's jack is its PWM (two channels at 0x2020c000,
  with their clock in the clock manager at 0x201010a0). The guest
  feeds it either by hand through its FIFO or with the DMA controller,
  which writes a word each time the FIFO asks for one (request line
  5). A block of samples lasts as long as its samples do in the
  board's time. `-audiodev wav,path=F` keeps what is played and writes
  it as a WAV file at exit (16 bits, two channels, at the rate the
  guest set: 44,099 for a range of 5,669 of a 250 MHz clock). A second
  of the file is a second the guest played, however long the emulator
  took, and the file is the same on every run. In a window the samples
  also go to the host's sound card (SDL), in real time: a guest too
  busy to keep up sounds broken there, but whole in the file. QEMU has
  no such device (a guest's writes go nowhere). The Pi 4's jack (its
  second PWM) is not emulated yet.
- **The clock.** Without a window, the board's time is counted in
  instructions (`-ips`). A run is then deterministic, with the same
  output and the same screens every time, and the tests rely on that.
  With a window, the board's time is paced to the host's. When an idle
  kernel waits at a WFI, the board's time skips ahead to the host's,
  but it is never allowed to run ahead of it (a key's repeat depends
  on this). A busy kernel falls behind, as a slower machine would.
- **The cores.** The Pi 2's four cores (and the Pi 4's, with `-smp`)
  take turns in one thread, each running a batch of instructions at a
  time. The run is then the same each time, but four busy cores are
  four times slower than one. With `-cores-parallel`, each started
  core of a Pi 2 runs in its own OCaml 5 domain, and so on its own
  core of the host. Four busy cores then take about the time of one,
  but the run is no longer the same each time (which core gets the
  kernel's lock first is up to the host's scheduler). This needs a
  mini-qemu built by OCaml 5:

      opam exec --switch=5.5.1 -- dune build --build-dir _build5 --profile release ./raspberry/Main.exe

  or `./mini-pi -P mini-9pi2`, which does that build for you. A
  mini-qemu built by OCaml 4.14 says it cannot run the cores in
  parallel, and they take turns instead. In parallel, the board's
  clock is the instruction count of the first core that is not
  waiting, and `-prof` counts the first core only.

## 4. Looking inside

### 4.1 The log: `-d`

`-d` prints to standard error what a real board would do silently or
fatally:

    mini-qemu: unassigned read at 0x20215040
    mini-qemu: undefined instruction e7f000f0 at 0x80012345

An **unassigned** access is an access to a device register that
mini-qemu does not emulate, at that physical address (the Pi1's I/O
is at 0x20000000, the Pi4's at 0xfc000000). It is logged once per
address and direction. Reads return 0 and writes are dropped. When a
new kernel hangs at boot, this is usually the first thing to look at:
it names the device the driver is waiting on. An **undefined
instruction** is logged before the guest takes its exception. It is
either a bug in the kernel or an instruction mini-qemu is missing; in
the second case, see `machine/tests/census_*.txt`, which lists the
instructions the corpus uses.

### 4.2 The instruction trace: `-trace N` (the Pi4)

    mini-qemu -M raspi4b -kernel kernel.elf -nographic -trace 2000      # the first 2000
    mini-qemu -M raspi4b -kernel kernel.elf -nographic -trace -100000   # every 100000th

Each line is `[core] pc elN instruction`, disassembled:

    ffff000000080010 el1 msr vbar_el1, x0

The first form is for the boot, up to where the MMU is turned on and
the exception level first changes. The second is a cheap sampling
profile: it shows which code a long run is in.

### 4.3 The machine protocol: `-qmp`

As in QEMU, `-qmp unix:/tmp/q.sock,server,nowait` opens a socket that
takes JSON commands, one per line. mini-qemu polls it between batches
of instructions, so it never blocks. It knows:

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
`kernels/9pi/tests/graphics.py` for rio, and `kernels/lib_machine/session.py
--usb --screendump` for a typed session.

### 4.4 Comparing with QEMU

Most bugs are found by running the same thing under both and diffing
the results: the console (`session.py ... -- mini-qemu ...` then
`-- qemu-system-arm ...`), the screens (screendump) and, for the Pi4,
the instruction trace against QEMU's `-d in_asm,exec`. `mini-pi -q`
runs QEMU with mini-pi's arguments. The techniques are described bug
by bug in
[notes_debugging_techniques.md](../notes/notes_debugging_techniques.md).

### 4.5 A guest profile: `-prof F`

`-prof F` counts the PC of every 1024th instruction the guest runs and
writes the counts to F at exit, one line per PC in the form
`pc count`, in hexadecimal, with the most sampled first. Any exit
works: Ctrl-A x, QMP's `quit`, closing the window, or SIGTERM.
`pcprof.py` maps them to the kernel's functions:

    mini-qemu -M raspi1ap ... -prof /tmp/prof.txt
    kernels/9pi/tests/perf/pcprof.py /tmp/prof.txt _make/9pi/pi1-ocaml/kernel.elf

     37.8% __aeabi_idivmod
     17.9% memmove
     10.6% mark_slice
      ...

Samples below the kernel's first symbol are counted as `(user)`: the
user programs. On the Pi4, only the AArch64 state is sampled (the
kernel), not the AArch32 programs. When the option is off, it costs
one test per instruction. The case that led to the option, where
mini-9pi's OCaml pixels were 6 times slower than the C ones, is case 1
in [notes_performance.md](../notes/notes_performance.md).

### 4.6 Where is it? `-status N` (and `mini-pi -v`)

When a boot stops printing, is the kernel stuck in a loop, waiting for
a device, or only slow? `-status N` prints a line on standard error
every N seconds of the host's time (`raspberry/observe/Status.mli`);
`-symbols ELF` names the PCs from the kernel's ELF. `mini-pi -v`
passes both (`-status 2`), and also shows each build step's output
and time (the first build of ocaml-light takes about 5 minutes, and it
is silent without `-v`):

    ./mini-pi -v mini-9pi
    ...
    mini-qemu: [4s] board 2.7s (+1.4s), idle 0%: 30% svc mark_slice, 13% svc memmove, 12% svc sweep_slice, 8% usr (user)
    ...
    %
    mini-qemu: [12s] board 26.9s (+11.2s), idle 97%: 1% svc Proc_fun_281; waiting at svc wait_interrupt+0x4

Each line gives:

- the host's time;
- the board's time, and how far it went since the last line;
- the share of the board's time the CPU waited at a WFI (the time
  skipped to its next interrupt);
- where the rest of the time went, the most first, each with the
  CPU's mode (Pi1: usr, svc, irq, ...; Pi4: el0, el1, or a32 for an
  AArch32 program).

A sample is taken after each batch of instructions, and the whole
batch is charged to its last PC. User programs are counted as one,
`(user)`.

Reading it:

- **booting**: idle is near 0%, and the line shows the kernel's
  functions (above: the collector of the boot's OCaml heap,
  `mark_slice` and `sweep_slice`, and copies, `memmove`).
- **at a prompt, waiting for input**: idle is near 100%, the line
  ends with `waiting at` the kernel's WFI, and the board's time runs
  ahead of the host's (without a window, an idle kernel's time skips
  to its next tick).
- **waiting forever for a device**: the same line, but no prompt
  appears; the console's last lines say what the kernel was doing.
- **stuck in a loop**: idle is 0%, and one function is near 100%, line
  after line.


## 5. The meters, and the activity monitor to come

Since 2026-10-11, a window has **meters** (`Monitor.ml`): a strip of
40 rows under the guest's screen, and numbers in the window's title.
Both show the last half second.

    mini-qemu  cpu 43%, user 12%,  11.2 Mips  x1.00  net in 120 KB/s out 3 KB/s  2 tcp 1 udp  tcp 93.184.216.34:80

- **cpu** is the share of the board's time the processor ran (it
  waited at a WFI the rest of the time); **user** is the part of it
  spent in user mode.
- **Mips** is the instructions the host ran per second; **x1.00** is
  the board's clock against the host's (below 1, the board is late:
  a busy kernel on a slow host).
- **net** is the frames' bytes per second to the guest and from it,
  then the open TCP connections and UDP conversations, then the last
  thing the network did.
- The strip shows the processor at the left, one column per half
  second, with the user programs' part in light green over the
  kernel's dark part. At the right it shows the network: the bytes in
  go upward in blue and the bytes out downward in orange, on a scale
  of tens (the full height is 1 MB/s).

`-meters off` leaves the window as it was. Without a window, `-meters`
writes the line each second on standard error (do not use it under a
script that waits for a prompt: the line would come in between). The
numbers are the emulator's, not the guest's, so a wedged kernel shows
as a full dark column. `raspberry/tests/Monitor_strip.exe W out.ppm`
draws the strip from made-up samples.

[plan_monitor.md](../plans/plan_monitor.md) describes the rest: the
counters (exceptions, device accesses, USB transfers, SD sectors), a
panel beside the screen with its own text, and QMP's `query-stats`.
