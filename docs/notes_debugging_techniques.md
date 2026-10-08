# Debugging techniques, written up as they get used

Notes on *how* problems in ix were tracked down, each technique with the
real case that earned it (mostly from kernel/9pi/, mini-9pi, and its
twin reference, principia's C 9pi, under QEMU and mini-qemu). What the
bugs were belongs to the plans (docs/plans/plan_9pi.md's status); this
file is about the method. Add a technique when a real session earns
it, not before.

## 1. Diff against the reference, with the very same inputs
mini-9pi is a twin: for every behavior there is an answer, the C 9pi's.
So the first move for any doubt is not to reason about what Plan 9
"should" print but to ask it. A small script boots the C kernel under
QEMU, types a file of commands at rc's prompt, and saves the console
(the scratchpad's c9pi.py, cut from raspberry/tests/9pi.py: its SESSION
read from argv[1], its output written to argv[2]); session.py
--lines does the same for mini-9pi. Then diff:

```
c9pi.py cmds.txt ref.txt
session.py --prompt "% " --lines cmds.txt -- Main.exe ... > mine.txt
diff <(sed -n '/% first-command/,$p' mine.txt) \
     <(tr -d '\r' < ref.txt | sed -n '/% first-command/,$p')
```

Real finds this way, each one line of diff:
- a walk error: '//lib/plumbing' does not exist (9pi) against
  '/lib/plumbing' file does not exist (mini-9pi): two bugs, the path is
  printed as typed (not cleaned), and a name missing past the first of a
  batch is "does not exist" (walk's Edoesnotexist);
- ps's sizes, 184K against 180K: 9pi's boot process has four variables
  userinit set (terminal, cputype, service, etherargs), so rc's heap was
  a page bigger;
- ls -l's dates, 2094 against 2026 (see 3).

The pitfall: the inputs must be identical, the *whole* sequence. A
"mystery pid" (ps was 38 in the C, 37 in mini-9pi) cost an hour of
reading usbd's source; the cause was that the C session had run one
command (cat) before ps and mine had not. Re-running both with the same
command file made the difference vanish. When a number differs by one,
first check the two sessions typed the same things.

## 2. Two emulators as a cross-check
Every mini-9pi check runs under mini-qemu *and* QEMU. When one passes and
the other fails, the bug is where the two emulators differ in what they
check, and the kernel was relying on what the lenient one ignores.
The SD card came online under mini-qemu but not QEMU ("i/o error"); a
diagnostic the C driver has (emmccmd's "emmc: cmd %ux error intr %ux
stat %ux", added to Emmc.ml, timeouts included for the hunt) printed:

```
emmc: cmd 9010000 error intr 18001 stat 1ff0000
```

Decoded by hand: command 0x09 = CMD9 (SEND_CSD), intr 0x18001 = Cmddone |
Err | Ctoerr: a timeout. CMD9's argument is the RCA shifted by 16,
0x4567 lsl 16 = 0x45670000 - past the Pi1's 31-bit ints (technique 3):
the C primitive wrote 0xC5670000. mini-qemu's card ignores CMD9's
argument; QEMU's checks it. Lesson: port the reference's own error
messages first, then read them in hex against the spec.

## 3. The Pi1's 31-bit ints: recognize the symptom, then find the 2^30
On the Pi1, an OCaml int holds -2^30..2^30-1. Anything a 32-bit machine
calls normal breaks silently: 1 lsl 30 is min_int, 0x80000000 does not
compile, a register with bit 31 set comes back as garbage. The symptom
is always an absurd number; the move is to write it in hex and look for
bits 30 and 31:
- ls -l's length 2305843008139952128 = 0x2000000000000000: the 1GB
  partition's "sectors per 2^30" computed with 1 lsl 30 (negative);
- a date in 2094: the kerndate (2026 = 0x6aa0e987) has bit 30 set, and
  le32 sign-extended it into bit 31;
- CMD9's RCA argument (above);
- DMDIR (bit 31) in a create's perm: get_le32 returned max_int.
The fixes follow one pattern: move 32-bit values as bytes or 16-bit
halves at the boundary (Machine.io_get16/io_set32, tf_bytes, P9's u31
fields), keep inside OCaml only what fits, and name the representation
in the .mli (d_lenhi, perm's sign as DMDIR).

## 4. A system call trace, filtered so it does not break the test harness
Syscall.trace (off; set it in Main's boot to use it) prints each call
"[pid Name args][pid = result]". Three bugs fell to it:
- command substitution hung: the trace showed pipe's fds, the fork, the
  child's write and exit, but the parent's read never returned; reading
  pipe's code again: it attached #| three times (namec "#|", "#|/data",
  "#|/data1"), so the ends were two different pipes. Plan 9's syspipe
  walks both ends from one attach.
- `echo 1.5*2 | hoc`: echo's process made no system call until hoc was
  dead (see 5).
- usbd's mount "missing" from pid 1's namespace: the trace showed the
  Mount call returning 5, success (see 7).
The trace's own output lands on the console, so session.py no longer
sees rc's "% " at the end of the output and waits forever. Filter it:
by call (`match c with Rfork | Exec | Exits -> true`), by pid (`p.pid >=
28`), or stop the session on a string (`--until "echo: write"`) instead
of the prompt. And when the output is a wall, `tr ']' '\n' | grep -E
'^\[(29|30) '` keeps one or two processes.

## 5. Confirm a race by turning its suspected cause off, then fix it the reference's way
`echo 1.5*2 | hoc` printed an extra "echo: write error" under
mini-qemu. The trace showed echo's side preempted by a clock tick
before its exec, while hoc ran to its death and closed the pipe. To
confirm, not guess: make preempt_due return false (one edit), rerun: the
extra line went away. Cause proven; but the fix is not "no
preemption" - it is reading how 9pi schedules (proc.c's ready/runproc,
hzsched): a FIFO run queue, a 100ms slice, and cpu->readied (the process
just woken runs next: a server answers its client at once). mini-9pi
took all three; the one remaining divergence (a process woken while the
CPU was idle gets a fresh slice) is documented as such. Timing races are
where a twin's output can differ without a bug: when the C itself only
wins the race by being fast, say so in the plan rather than chase it.

## 6. Read the reference's function, stripped, before writing its twin
principia's sources are syncweb-tangled: `/*s: ... */` markers on every
chunk. To read one function whole:

```
grep -v "/\*[sex]:" files/chan.c | awk '/^walk\(/,/^}/'
```

Most fidelity bugs were details only the source shows: pexit pushes a
wait record at the head (await returns the last child first); devenv's
remove moves the last variable into the hole; a note starting "sys:"
gets " pc=0x..." at delivery; exec resets the note handler (hoc died
of rc's handler until exec cleared it: "sys: trap: fault read va=0x0"
instead of "undefined instruction"); procargs quotes each argument and
a thread's name shows as "text [name]"; devdir's atime is seconds()
while its mtime is kerndate. When a reference value is one second off
(KERNDATE from pi.5's mtime: 1788930440 against 9pi's 1788930439),
decode the reference's raw bytes (struct.unpack on the stat entry) and
find the real constant in its binary (kernel/9pi/conf/kerndate.py).

## 7. Distrust your own diagnostic output as much as the program's
usbd's mount of /srv/usb on /dev seemed absent from `cat /proc/1/ns`.
It was there: mini-9pi's /proc/n/ns printed a mount as "bind /dev /dev"
(its member's name is the mount point's), so it hid among the binds.
The trace (4) showed the Mount succeed, which is what exposed the
misleading printer. When a diagnostic tool of your own says something
surprising, check the tool against a second source before chasing the
program.

## 8. A crash in the collector: from the address to a compiler bug (a worked case)

The whole hunt, because each step is a technique and two of them were
dead ends worth knowing. The symptom: with QEMU's USB keyboard and
mouse attached, mini-9pi died a few seconds after rc's prompt,
deterministically:

```
mini-xv6: in the kernel, data abort, lr 800447d0, far 00000000
```

**Name the address.** The board's C (lib/pi1/machine.c's kfault)
prints the abort's lr; kernel.elf keeps its symbols:

```
arm-linux-gnueabihf-addr2line -f -e build/pi1/kernel.elf 0x800447d0
arm-linux-gnueabihf-nm -n build/pi1/kernel.elf | awk '$1 <= "800447d0"' | tail -3
```

`oldify_local_roots`: the OCaml collector, walking a stack's frames.
That names suspects, not the bug: a C primitive allocating without
registering its values (CAMLparam), a kernel stack (16KB) overflowed
into its neighbour's, a stale view of a stack. The crash reproduced
under QEMU too (so not an emulator bug), and at a fixed address (so
not random memory corruption).

**Test a hypothesis with a knob, and believe the result.** Kernel
stacks from 16KB to 64KB: same crash, same address. Not an overflow
(the layout changed, the crash did not). Reverted.

**Narrow with a debug print of the device's work.** A switchable print
of each USB transfer (Usbdwc.debug) showed the last transfer before the
crash: a control read of 4096 bytes, the size of the DMA page. Another
hypothesis (the DMA writing past its page), checked in the emulator's
source (raspberry/Dwc2.ml writes the device's bytes only): out.

**A theory that explained too much.** Reading kernel/lib_machine's runtime.c,
I found what looked like a latent bug (after a return to user mode from
inside OCaml, the runtime's `caml_bottom_of_stack` names abandoned
frames) and "fixed" it. The crash came *earlier*. A fix that makes
things worse is evidence against its theory: it was reverted, and the
right move was to stop reasoning and look.

**Look: gdb on QEMU, stopped at the exact instruction.** The fault is
`lr - 8` (an ARM abort). Its disassembly showed a hash-table probe
(`ldr r2, [r4]`, r4 a frame descriptor); stop there only when it fails:

```
qemu-system-arm ... -gdb tcp::12399 -S &
gdb-multiarch -batch -ex "set architecture arm" -ex "file build/pi1/kernel.elf" \
  -ex "target remote localhost:12399" \
  -ex "break *0x800449f0 if \$r4 == 0" -ex "continue" \
  -ex "info registers" -ex "x/24wx \$r5 - 16" -ex "bt 8"
```

Mapping registers by the prologue's loads (r7 the runtime's globals, r5
the walked sp, r1 the return address looked up) gave the key fact: the
"return address" was 0x8013e9c8, an address in `kstacks` - a saved sp,
not code. The code addresses around it on the stack, named with nm,
were the frames of the call: Printf, Usbdwc.chanio, Usbdwc.ctltrans,
Devusb's write, Syscall. One frame's size was wrong by exactly the
distance between where the return address really was (0x8013e974) and
where the walk read it.

**Read the compiler's own frame table, not a hand-parsed binary.**
`ocamlopt -S` (in a copy of the build directory, with its .cmi/.cmx)
writes the frame table as text: each call's label, frame size, live
slots. ctltrans's descriptors were right (24 + 8 for its `try`), but in
chanio:

```
sub   sp, sp, #4        @ one argument on the stack
bl    caml_apply8       @ descriptor: 56; the real frame: 48 + 4 = 52
```

A `Printf.sprintf` with 8 format arguments is a 9-argument application,
one on the stack; the ARM backend's frame_size rounds the whole frame,
the pushed argument included, up to 8. That rounding came from an
earlier fix in the ocaml-light fork (AAPCS alignment), correct only
when the outgoing area is itself a multiple of 8, which upstream OCaml
guarantees in `proc.ml` and the fork did not. The first crash (before
my debug print existed) was the same: Devusb's `seprintep` is a
`Printf.sprintf` of 11 arguments. Fixed as upstream does, as a patch
to the compiler's clone (docs/plan_bugs_ocaml_light.md, bug 5).

What to keep from it:
- a crash inside the runtime is usually the runtime's *input* (here the
  compiler's frame table), so find what it was walking;
- eliminate hypotheses by experiments that can fail (the stack size),
  and revert what did not help;
- when the reasoning stops converging, stop at the faulting
  instruction and read memory: one stack word ended an hour of theories;
- compare the compiler's claim (the descriptor) with the machine's fact
  (the stack), and grep the generated assembly for what differs
  (`sub sp` before a call).

## 9. OCaml 1.07's errors: know the three that are not your logic
ocaml-light compiles most OCaml, but three things read like type errors
and are not:
- record fields are not told apart by type: a later record with a field
  `typ` (P9's message) makes every `{ typ = ...; vers; path }` a qid
  error ("This expression has type qid_type but is here used with type
  message_type"); give fields unique names (mtyp, dname, d_perm);
- a constructor shadows another type's: Syscall's `Rendezvous` (a call)
  hid Types' `Rendezvous of int` (a wait): "expects 0 argument(s)";
- the stdlib is 1997's: no List.remove_assoc, List.mem_assq,
  String.contains, String.iter, String.init; and String.index_from with
  a start equal to the length raises Invalid_argument (a "#c" path
  panicked the boot).
When unsure whether a construct exists, compile a three-line file with
the cross compiler before using it:

```
/tmp/ix-ocaml-light-arm/bin/ocamlopt -c w.ml
```

## 10. Build and process hygiene: know which inputs a build used, kill by PID
- A test image (kernel-pi1-b.img, its own B=build/pi1-b) silently
  overwrote the main image's bootdir: the Makefile named FS from BOARD,
  not from B. Symptom: the main boot printed the test script's output.
  When output belongs to "the other configuration", list each build
  directory's inputs.
- A rule `kernel-pi1-b.img: FORCE; $(MAKE) ... IMAGE=$@ $@` recursed
  forever: inside the sub-make the target *was* IMAGE and matched the
  same rule. Guard it (ifneq ($(IMAGE),kernel-pi1-b.img)).
- Stop runaway processes by PID (ps -eo pid,args | grep ... | awk
  '{print $1}' | xargs kill), never pkill -f with a pattern that can
  match your own shell; and look for emulators left over from earlier
  sessions (ps ... | grep qemu-system) before timing anything.

## 11. Bringing up a device with no reference: the network (a worked case)

Stage E (plan_9pi.md) put a USB Ethernet adapter under mini-9pi:
QEMU's `usb-net`, a driver in the kernel (network/Etherusb.ml), `#l`,
then IP. No C reference exists (principia's 9pi has no driver for it),
so each step was checked against the other end instead: QEMU, its
user network, the host. Five problems, each a technique.

**Ask the device, not your model of it.** Before writing the driver,
the device was attached to the running kernel and looked at from rc
(`ls '#u/usb'`): usbd had enumerated it (`ep5.0`), found no driver for
it, and left it alone, so a kernel driver could take it over. QEMU's
own source (hw/usb/dev-network.c) then answered the questions a
datasheet would: RNDIS is listed first, so the driver must choose the
ECM configuration (value 1) itself; the MAC is a string descriptor;
frames end with a short or empty packet.

**A hang may be your own diagnostic.** The first probe hung `bind`.
Turning on the USB transfer trace (Usbdwc.debug) showed every control
transfer succeeding, and then... the trace itself kept going: the
keyboard's polling, printed forever, so the test harness (session.py,
which waits for a quiet prompt) never saw rc's prompt. Technique 7
again: after a trace, check what the trace changes. Swapping it for two
one-line messages ("found", "none") showed the probe finished.

**Read the emulator's model of the hardware, down to the register.**
The real hang: the driver polled the bulk IN endpoint from the clock,
one transaction at a time, expecting a NAK to halt the channel as it
does for an interrupt endpoint. QEMU's hcd-dwc2.c says otherwise: "for
ctrl/bulk, automatically retry on NAK" -- the channel never halts, so
kernel/lib_machine's usb_transfer spun a million polls in the clock interrupt.
The first fix (halt the channel on NAK: CHDIS) then broke usbd's
transfers ("failed data transaction: pid 0x2d ep 0x2": a SETUP sent to
the network's endpoint): QEMU's channel disable sets the halted bit
but leaves the NAKed packet scheduled, retried later with the next
transfer's registers. The fix that follows the hardware instead of
fighting it: a second channel, its bulk IN left pending (the
controller retries it), its completion polled (usb.c's usb_start1,
usb_poll1). The lesson: when two models disagree (the driver's, the
emulator's), read the emulator's code for the exact register's
behaviour; guessing twice cost two rebuilds.

**When a value is wrong, print what the program actually received.**
`ipconfig` configured the interface, but its mask read 0.0.0.0. The
parser was fixed for the form Plan 9's `%M` was assumed to print
(`/120`), still 0.0.0.0. One print of the ctl message the kernel got
ended the guessing: `add|10.0.2.15|ffff:ffff:ffff:ffff:ffff:ffff:ffff:ff00`,
IPv6's notation. Guessing a format costs a boot per guess; printing it
costs one.

**The second emulator catches the first one's bugs.** Under QEMU all
worked; under mini-qemu (with its new usb-net) the probe found no
device. The difference: the descriptor mini-qemu served. A hand-counted
length (75) disagreed with the bytes (67); usbd read a configuration
whose declared length lied. Fixed by computing the length from the
bytes (Usb.ml's with_total): a number derived, not written. Then the
same session gave the same bytes under both emulators (tests/session-net,
the round trips' times masked), the check technique 2 describes.

## 12. A struct copied through a register the emulator half-modelled

mini-9pi4's first boot under mini-qemu died in memdraw with a write to
address 0, a pointer (a Buffer's alpha) that was never null in C.
QEMU booted the same image fine, so the emulator was suspect
(technique 2). Disassembling the faulting function (objdump -d) showed
gcc copying the 104-byte struct through `ldp q0, q1` / `stp q0, q1`:
128-bit SIMD registers. mini-qemu's arm64 kept only the low 64 bits of
the vector registers (enough for the OCaml runtime's doubles, and so
documented), writing zeros for the high half of a `q` store: every
other 8 bytes of a copied struct zeroed. The fix: the high halves kept
(Arm64's fph). The technique: when a compiled program misbehaves only
under one emulator, look at the instructions the compiler chose at the
fault, and check each against what the emulator implements, not what
it decodes.

## 13. The runtime's own trace: CAMLRUNPARAM's v, even in a kernel

mini-9pi spent 30-50% of its boot in the major collector
(plan_9pi_gc.md), and the question was why: how many collections,
and when. OCaml's runtime answers it itself: OCAMLRUNPARAM's v prints
its collector's events (ocaml-light's CAMLRUNPARAM=v=1: `<` `>` around
each minor collection, `!` a major cycle's marking done, `$` its
sweeping done, "Growing heap to ..." each increment). A freestanding
kernel has no environment, and its libc stubbed getenv to NULL (and
sscanf, which the runtime parses the values with, to a panic): so
libc.c's getenv now returns CAMLRUNPARAM when the kernel is built
with one (make CAMLRUNPARAM=v=1), and a sscanf of the one format
startup.c uses. The trace, interleaved with the console's output,
showed at once what no profile had: the heap grown by 248k steps ten
times over the boot, and after rc's prompt, idle, `<>$<>$<>$...`
without end: something in the idle kernel keeps allocating, and with
a live heap that small each minor collection's slice finishes a whole
major cycle. The technique: before instrumenting a runtime, ask it;
most have a verbose switch, and making it reachable (an environment
variable a kernel lacks) is cheaper than adding counters. And read
the trace in time, not only its totals: the steady state after the
boot said more than the boot's count.

## 14. A fault one run in three: log the data at the boundary, compare runs, stop rerunning

mini-9pi's kernel got its own USB keyboard (plan_rio.md: Kusb, with
the code mini-usbd uses, kernel/9pi/buses/lib_usb). Seven graphical
sessions gave the recorded screens; one, win-scroll, failed under
mini-qemu, at step 7 one time and at step 6 another, and a screen
showed "line 7" where "line 17" was expected. It looked like a key
lost now and then: a race, a report dropped, the clock missing a
tick. An hour went into that theory by rerunning: long lines typed on
the console (18 of 18 right), in a window (4 runs the same, right),
six more runs lost to a quoting mistake in the test's own script, six
to a timeout too short. Each run a minute or four, each saying only
"right this time".

What ended it took one build: every keyboard report that made
scancodes written to the serial line, as hexadecimal, the report and
what it became (`[0000520000000000>5c78653048]`), by `uart_putc` alone
(the console's print also draws on the screen, and a screen that
changes is never "still" for the harness: the first try of the log
hung every run at the boot). Eight runs side by side: the eight logs
identical, 188 lines, and the eight step-7 screens identical too, and
wrong. So nothing was lost and nothing raced: the fault was the same
at each run, and the last two lines of the log said what: the up
arrow, whose scancode is 0xe0 then 0x48, came out as `5c 78 65 30 48`,
the five characters `\xe0H`. The shared module wrote the byte as the
string "\xe0", and the kernel's compiler (ocaml-light) has no `\x`
escape in a string: it keeps the four characters. OCaml 4.14 and
mini-ml, which compile the same file for mini-usbd, have it: the
program was right and the kernel wrong, from one source line. (The
first "line 7" was never explained: it did not come back in the eight
runs, nor after the fix. It is written here so that the next one is
not taken for the same bug.)

The techniques:
- A test that fails at a different step each time is not yet known to
  be a random fault: the harness stops at the first wrong screen, so a
  fixed fault that an earlier flake hides or shows looks random. Run
  it several times side by side and compare the runs with each other
  before believing in a race.
- Put the log at the boundary between the layers (here: what the
  device said, and what the driver made of it, on one line): one run
  then says which side is wrong. Rerunning the whole says only that
  something is.
- Log in a form that cannot hide the fault: bytes as hexadecimal. The
  screen showed "b8b" typed, which says nothing; `5c7865` is `\xe`.
- A debug print must not go where the test looks (section 7's point,
  again): to the serial line, not the screen.
- Code shared by two compilers is to be read once for what the weaker
  one does not have, before it is run: ocaml-light has no "\xHH" in a
  string (it has "\ddd"), no `String.iter`, no
  `String.get_utf_8_uchar`. Section 9 has its error messages; this is
  the case with no message at all.

## 15. One error, then everything fails: suspect the state the error left behind

`make check-plug`: QEMU's device_del takes the USB mouse out while
mini-usbd runs. The console said `usbotg: ep4.1 error` (the mouse's
endpoint: expected), then `ep3.1 error` (the keyboard's), then
`ep2.0 error` (the hub's) twice a second, for ever. Three devices
failing after one was unplugged cannot be three faults: it is one
thing they share. Their only shared thing below the hub is the
controller's channel: kernel/lib_machine/usb.c runs every transfer on channel
0 and waits for it to halt. The rate was the second clue: two errors
a second is the wait's own timeout (a million turns of its loop), not
the four looks a second mini-usbd makes at eight ports. So transfers
were not failing, they were not starting: the transfer to the device
that was gone had not halted in time, the channel stayed enabled, and
a channel still enabled starts nothing. The fix: a channel found
enabled is disabled first. The technique: when a first, expected
error is followed by errors everywhere, do not look at the later ones
one by one; ask what state the first one's path leaves (here an error
path that returns without undoing what the normal path undoes), and
read the rate of the later errors: it often names the timeout they
come from.

## 16. "It is slow": a tool a layer, a model to check the numbers against, and the emulator's clock doubted

The playground's games on mini-9pi (plan_playground_speed.md): a frame
of TinyWolfenstein took 100 ms under QEMU, 10 a second, and the keys
felt late. No one thing was slow; eleven were, in four layers (the
game, the library that makes the device's messages, mini-ml's code,
the kernel's drawing), and the night's work was finding which tool
says the truth about which layer. What was used, in the order it
became necessary:

- **A meter in the program, on a flag** (`stats=on`, Plan9_loop and
  the draw platform): every 40 frames, what a frame's update, view and
  showing cost. The showing splits in two only if the messages are
  held until the frame's end (`Display.hold`): then the time to make
  them is the program's and the one write's time is the device's.
  Without the hold a write happens whenever the buffer fills and the
  two are mixed. The meter costs four clock reads a frame and stays
  in the code.
- **Leaving a part out, on a temporary flag** (`skip=all`, `skip=draw`,
  `skip=msg`, `skip=ink`): the frame with no shape, with the places
  computed but nothing sent, with everything but one message. The
  differences are the parts' costs (the place of a rectangle 9 ms, its
  message 5, its colour 2), and they add up to the whole or something
  is missing. The file is copied to the scratch directory first and
  copied back after: an experiment is never left in the tree.
- **Instructions counted, not time**, for the program's side:
  a file of ten lines per question, compiled by the same mini-ml and
  linked as a game is (`mini-mk O=5 GAMES=Zbench` in games/puzzle),
  run by `mini-5i -s` with 100 turns then 1,100, the difference
  divided by 1,000. A float multiplied: 65 instructions. `Float.min`:
  360. A byte added to a Buffer: 258. An integer division: 200. No
  host, no load, no clock: the same number each time, and it says
  what to change (Display's own bytes, for 12,000 instructions a
  rectangle's message down to 1,000).
- **The emulator's speed measured before its times are believed**:
  three loops of known instruction counts timed on mini-9pi under
  QEMU. Integers and byte stores: 900 to 1,400 million instructions a
  second. Floats: 225 (QEMU computes them in software). So a
  millisecond of QEMU is a million instructions of integer code, and
  QEMU makes a program of floats look four times slower than its
  instructions say: a real Pi1, which has the unit, will not show the
  same split. A time under an emulator is a count multiplied by a
  rate that depends on what is counted.
- **An emulator whose clock is its instruction count is a counter**:
  mini-qemu's guest time is 30 instructions a microsecond, whatever
  the host does. The program's own meter, run under mini-qemu, prints
  milliseconds that are 30,000 instructions each: a frame's update,
  view, messages and device, in instructions, with no tool but the one
  already there. (The key has to be held five minutes: a frame is a
  third of a simulated second.) It said a frame is 12 million
  instructions where QEMU's 32 ms and "a thousand million a second"
  had said 32 million: QEMU runs a loop of integers that fast and
  code that is calls and returns three times slower, each return
  through a register being a search for where to go.
- **The model checked against the measure, and the gap pursued**: the
  counts said 5,000 instructions a shape; the meter said 12 ms for
  232, which at the measured rate is 43,000. A gap of eight times is
  not noise, it is a thing not in the model. What a micro-benchmark
  of 1,000 turns never does is fill the heap: mini-ml's collector
  copies everything alive at each collection, the heap was 1 MB, and
  a frame made more than that in floats. `ML_HEAP=4194304 wolfenstein`
  (the runtime's variable, no build) halved the program's time and
  proved it in one run. (Then the floats were made in place by the
  compiler, a block taken without a call, and the same game needs no
  larger heap.)
- **A profile of the steady part only**: mini-qemu's `-prof` samples
  from the boot on, and the boot is most of a short run (phys_zero,
  the major collector: 20% that are not the game's). Two runs, the
  keys held 4 seconds and 24, and the samples of the first taken from
  the second's: what is left is 20 seconds of frames
  (kernel/9pi/tests/perf/pcprof.py reads it).
- **The same samples against the program's symbols**: the addresses
  below the kernel's are the program's, and `mini-ld -v` with the
  game's own link command gives its listing; pcprof.py takes a
  listing for an ELF. The first lines were `ml_curry2_0` and
  `ml_curry2_1`, 16% between them: every call of another unit's
  function of two arguments made a closure for the first one. Nothing
  else would have said so: it is no function of the game's, of the
  library's or of the runtime's, and it is everywhere.
- **Timers inside the kernel, by the message's letter and by the
  stage**, printed on the serial line every 40 flushes (section 14's
  rule: not on the screen): `d:255x14390us p:43x2569us`, then for a
  draw `clip 1695 faster 7844 (prelude 3158) flush 1162`. A flat
  profile had a tail of fifty functions under 1% each that summed to
  a third; the stage's timer says which stage owns the tail (reading
  the colour of a fill three times, by its channels: the prelude).

What went wrong on the way, each of which cost an hour:
- **Frames counted that were not drawn.** The first frames a second
  for the draw platform (28, 53) counted the loop's turns; a turn
  that draws nothing (the frame is the one before) is no frame. The
  numbers had been told to the author. A counter is read once against
  something else (40 frames in 1.7 s is 23 a second) before it is
  quoted.
- **A profile read against the wrong build.** After the kernel was
  rebuilt with a timer in it, the old samples named `format` for 9%:
  every address was a few functions off. The samples and the ELF they
  are read with are one build's, or the names mean nothing.
- **A change measured that was not built.** mini-mk rebuilds a unit
  when its sources change, not when the compiler does: a new mini-ml
  and the same instruction count means the objects are yesterday's.
  `rm -rf _mk/5/lib_core _mk/5/games ...` before measuring a
  compiler's change; and a count that does not move at all is a
  reason to check the build, not to conclude.
- **A copy that was thought to go forward.** memmove's loop was
  unrolled, eight words a turn, and its share did not move: the hot
  addresses were in the other loop, the one that copies backwards
  (the destination was after the source, in another string). The
  profile's addresses inside the function, against its disassembly,
  said so in a minute.
- **The time given by a clock of 10 ms.** A frame's parts are read
  from the kernel's clock, a hundredth of a second: over 40 frames
  the sums are right, one frame's are not, and two runs differ by 2
  or 3 ms a part with nothing changed (the host runs other builds).
  A change of 1 ms is not seen this way; instructions are.

## 17. Keys that feel late: what a program polls, and when it can be told

"Sometimes nothing is sent and then it's buffered or something and
send; for a game it does not feel right." Three faults, none of them a
lost key, each found by asking where a key waits:

- The loop was woken by a process that wrote a tick a hundred times
  a second; a frame took a tenth of a second; ten ticks waited in the
  pipe before a key written after them. Found by counting, in the
  meter, the ticks given a frame: 197 for 40 frames. The clock is now
  asked for one waking, for the next frame's time (Source.alarm).
- mini-ml's threads are cooperative: what a source's thread has read
  is given when the main thread lets it run. The loop polled without
  yielding, so the poll found nothing though the bytes were read.
  `Thread.yield ()` before `Event.poll`.
- A tap shorter than a frame was down and up between two ticks: a
  game that asks at each tick which keys are down never saw it. The
  release is now kept until a tick has seen the key.

And one that was the test's: forty-eight keys sent, six with no
effect, in a run that could not be made again. The keys had been sent
before the game had started (it was still on its title, which takes
one key and ignores the rest). `LIVE_START=6` in tests/live.py waits
for the program first. A test of input says when the program is ready
before it says what was typed; and the picture after each key is
compared with the one before it, since "the key had an effect" is the
only thing the test is about.
