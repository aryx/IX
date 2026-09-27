# Plan: an activity monitor in mini-qemu (and mini-pi -g)

## Why

QEMU shows the guest's screen and nothing else: whether the CPU is busy
or idle, which device the kernel is talking to, whether a packet went
out, is invisible. For teaching, that is the interesting part. mini-qemu
already runs every instruction and every device access in OCaml, so it
knows all of it for free; this plan makes it show it, live, beside the
screen (mini-pi -g) and in the terminal, so that a student can see,
e.g., the CPU go from 100% to idle when rc waits for a key, the USB
keyboard's interrupt endpoint polled, a ping's frames out and in, the
SD card read during a boot, a page fault per page of a program's stack.

The author (2026-09-27): "network monitoring or something to see if
it's used, a bit like an activity monitor; same maybe for CPU and other
system resources ... to make mini-qemu more versatile and useful than
qemu for our teaching context", "especially mini-pi -g with possibly
some other graphics next to the main window with monitoring stuff".

## What is measured (the counters)

All counters are plain ints bumped where the event already happens
(an increment, no allocation), per board, in one `Stats` record; the
display samples them 30 times a second (the window's frame rate) and
keeps a short history (the last ~10 s) for its graphs.

- **CPU**: instructions run; time asleep (WFI: idle, the batches
  skipped); per exception level or mode: user (EL0 / usr), kernel
  (EL1 / svc...), so user vs kernel vs idle as %; per core on the Pi4.
- **Exceptions**: system calls (SVC), IRQs, aborts (page faults: data,
  prefetch), undefined instructions; per second.
- **Memory**: the MMU's walks (TLB misses: mini-qemu's cache misses),
  the address space switches (TTBR0 writes: context switches, a proxy
  for "which process runs"); the physical pages touched (a map).
- **Devices**, by name as the memory map has them (uart0, emmc, dma,
  usb, gic, mailbox, fb...): reads and writes per second, each a bar.
- **USB**: transfers per device and endpoint (the keyboard's interrupt
  polling, the hub's, the net's bulk), NAKs, bytes.
- **Network** (Usernet): frames in and out, bytes, by protocol (ARP,
  ICMP, TCP), the NAT's connections (guest port -> host port, bytes
  each way, state), and a log of the last frames, one line each
  (tcpdump-like: `10.0.2.15.5001 > 10.0.2.2.8123: S 1234 win 65535`).
- **Storage**: SD sectors read and written; **UART**: bytes each way;
  **framebuffer**: the screen's rows written (a heat strip).

## Where it is shown

1. **mini-pi -g: a panel beside the screen**, in the same SDL window
   (the window widened, the guest's framebuffer on the left, the panel
   on the right, e.g. 320 pixels): the CPU as a stacked graph (user,
   kernel, idle) over the last seconds; a line per counter with a
   sparkline; the network's log; the USB tree with each endpoint's
   activity. Drawn with mini-qemu's own pixels and a built-in font
   (xv6's font1.bin, already in the repo), so no new library. A key
   (F12, outside the guest's keys) or `-monitor-panel off` hides it.
2. **The terminal** (no window, or the window's other half): a status
   line on standard error refreshed once a second, off by default
   (`-stats`), e.g. `cpu 12% (usr 3 sys 9) idle 88% | irq 104/s svc
   31/s pf 0/s | usb 210/s | net 2/s 180B/s | sd 0/s`; and at exit a
   summary (totals).
3. **QMP**: `query-stats` (a JSON of the counters), so tests and
   scripts can assert on them (e.g. a test that the idle kernel really
   sleeps, that a boot reads N sectors).
4. **A trace file** (`-stats-log F`): the counters sampled every 100 ms
   as CSV, to plot afterwards (a lesson's figure).

## Steps

- **M0: the guest profile, done** (2026-09-27): `-prof F`
  (`raspberry/Prof.ml`): every 1024th PC counted, written at exit;
  `kernel/9pi/tests/perf/pcprof.py` maps the PCs to a kernel's
  functions. It came first because it was needed: it found mini-9pi's
  OCaml pixels spending 38% of their time in the Pi1's software
  division (docs/notes_performance.md, case 1). The panel (M2) can
  show it live: the top functions of the last second.
- **M0.5: where is it, done** (2026-09-27): `-status N` and `-symbols
  ELF` (`raspberry/Status.ml`), mini-pi -v: every N seconds a line on
  standard error, the board's time, how idle, the hot functions of the
  last N seconds named from the kernel's ELF (manual, section 4.6).
  To see where a boot blocks; the terminal status line of M1 can
  extend it with the counters.
- **M1: the counters** (`raspberry/Stats.ml`, the hooks in Board, Pi4,
  the CPUs' loops, Memory's device dispatch, Dwc2/Usb, Sdhost,
  Usernet), the terminal status line and the exit summary, QMP's
  query-stats. Checked: the counters' totals of a known session (a
  boot to rc's prompt: SD sectors read, system calls) the same run
  after run; the tests unchanged (the counting must not change
  timing: it is outside the guest's time).
- **M2: the panel** in the window (Display gets a second area; a small
  text and graph drawer), mini-pi -g showing it; the network log.
- **M3: more views** as teaching asks: the physical memory map (pages
  touched, by kind), the page-fault log, a per-address-space CPU split
  (TTBR0), the SD access pattern.

M1 is small (about 200 lines); M2 the bulk (about 400: the drawing).

## Decisions (the author, 2026-09-27)

1. **The same window**: the panel beside the guest's screen.
2. **On by default** (with -g), for now.
3. **Simple first**, extended later: few lines of code.
4. **tsdl, and mini-qemu's own pixels** for the panel (rectangles,
   lines, xv6's 8x16 font): the Playground wants to own the main loop
   (Elm's view and update), where mini-qemu's is the emulator's, and
   is another repository. ~/playground/libs/gui (pure OCaml, immediate
   mode, rectangles and paint) is the candidate if the panel becomes
   interactive (tabs, clicks, a filter typed).

## Questions for the author (asked before the decisions)

1. The panel beside the screen in one window, or a second window?
   (one window: simpler to capture and to show in a lecture)
2. On by default with -g, or behind a flag?
3. Which views first after CPU and network (USB, SD, memory, faults)?
4. The status line in the terminal: useful, or noise next to the
   guest's console?
