# t-IX's optimizations, and what each one is worth

The twin of [notes_opti_inventory.md](notes_opti_inventory.md) (m-ix's
graphics and mini-ml) for t-IX: tiny-machine, tiny-kernel, tiny-ml and
the tiny programs. Started 2026-10-27 (the author, after play's WAV
was made to keep up: "maybe we can start a notes_tiny_opti_inventory.md
like we did for mix").

Scope: tiny/ from 2026-10-08 to 2026-10-27. Sources: the commit
messages (each row gives its commit), the code's old: comments and
switches. Every number is copied from the commit with the setting it
gives, except T12 and T13's, measured for this note. Not yet gathered:
the tiny-c and tiny-assembler sides, the tiny programs' own
algorithms (TinyBrowser, TinyOffice), and the second pass every row
deserves (each gain measured alone again, on today's tree).

How it is measured: instructions, counted by tiny-machine -prof and
read by tiny-prof (by function, the kernel's -k map and a program's
-u map), or the host's seconds for a fixed count of the machine's
instructions (tests/TinyMachine_bench.sh: a recorded session, natively
and under node). A machine's run is the same instructions every time:
a profile is exact, and a change that should not change behaviour is
checked by the recorded sessions' screens and sounds (TinyKernel's
make check, frames and WAVs compared byte for byte).

Two budgets matter. The host's: with a window, tiny-machine holds the
machine to 20 million instructions a second (the web page to 8); a
host that runs fewer falls behind, and the sound comes in gaps. The
machine's: what a program needs a second of machine time, whatever the
host.

## Summary table

| # | Name | Where (module, commit) | Gain recorded | LOC | Switch |
|---|---|---|---|---|---|
| T1 | Batched ticks: after a tick that looks, bare steps to the next moment that can change something | TinyMachineDevices `ticks`, 90f1fc38 | natively 15.2 to 22.0 M instr/s; node 6.8 to 8.1 | (part of +222 -15) | `batched` |
| T2 | No closure at each load and step | TinyMachineCPU `load`, `set`; 90f1fc38 | node 4.5 to 5.2 M instr/s | (same) | none (old: comments) |
| T3 | Decoded words kept, by the word | TinyMachineCPU `keep_decoded`, 90f1fc38 | node 6.8 to 8.1; natively 21.3 to 22.0 | (same) | `keep_decoded` |
| T4 | The scheduler idle: interrupts counted, nothing retried but by a key, the mouse or the alarm | TinyKernelScheduler `idle`, 56354ee0 | "a quarter of the instructions of a machine where nothing happened" | (part of the windows' step) | none (old: comment) |
| T5 | tiny-ml: `String.length` and `s.[i]` inline; an ML program's heap at its full size | TinyML's -tm back end, mlsys.c; cbc0b9cc | the browser reading OCaml's Wikipedia page 447M to 356M to 233M instructions (collector 26% to 2%) | +79 -18 | none |
| T6 | Text drawn in one call (glyphs), lines as rectangles, rows copied four words a turn | TinyKernelGraphics, draw.tm, TinyLibDraw, www; 539519f2 | a page down 3.56 s to 0.93 s of the host; ~5.4M instructions | +240 -47 | the old path kept for the rest |
| T7 | tiny-ml's names in hash tables, keywords by table | TinyML, fe58f4b3 | TinyML.ml compiled on tiny-kernel 11 min to 171 s (202 with Printf) | +390 -230 | none (old: comments) |
| T8 | SHA-1 in C | TinyMLRuntime/core.c, a2da2e93 | a digest of 141 KB 770M to 77M instructions; 3.8 of the self-build's 5.5 hours | (part of +193 -79) | none |
| T9 | Marshal in C, interfaces marshalled; a function's text into one buffer | core.c, TinyML; 8885624d | Troff's unit 16.7M to 7.7M instructions (host); a unit of one line 3.2 s to 2.2 s on tiny-kernel | +550 -135 | none |
| T10 | `read_file`: pieces read, then copied once | TinyLibGUI, 3e5c8a7f | a WAV of 141 KB was 85M instructions (600 a byte) | small | none (old: comment) |
| T11 | The machine's speed a setting, 20 M with a window | TinyMachine, entry.tm; 29662089 | not a saving: the machine 2.5 times faster for a person watching, the programs' pace by ticks kept | +157 -54 | `-rate n` |
| T12 | The kernel's idle loop not stepped: the time added at once | TinyMachineDevices `ticks`, `idle_skipped` (2026-10-27) | play's run (boot, the 6.4 s WAV, sleep 2: 9.6 s of machine time) at -rate 20: 11.0 s of the host to 8.7 | +17 | `idle_skipped` |
| T13 | A sound's write that waits woken when the ring has room, not every 10 ms | TinyKernelIO `Voice`, TinyKernelDevices `speak` (2026-10-27) | the same run: 135M busy instructions to 88M; with T12 6.1 s of the host | +18 -10 | none (old: comment) |

## Worth it?

Kept, the gain large and measured:
- T1 and T3: the host's speed, every program's. T1 is what lets a
  2.2 GHz Neoverse hold a window at 20 million.
- T5, T7, T8, T9: tiny-ml's programs and tiny-kernel building itself.
- T13: ten lines, a third of play's instructions.

To measure again:
- T12 on the recorded sessions: their machine is the same (the
  screens and sounds are byte for byte), but their host time was not
  timed. It saves what a machine idles, so a busy program gains
  nothing; play gains its ~13% of idle and the sleep after.
- T2 and T3 natively on today's tree: their numbers are node's.

## Details

**T12. The idle loop not stepped.** tiny-kernel waits in `k_idle1: j
k_idle1`, interrupts on. tiny-machine stepped it, a jump at a time, 20
million a second with a window: the host's speed spent on nothing. In
a calm stretch of [ticks] (no event, no interrupt, no device until
the next look) nothing but the time changes in that loop, so the time
is added at once; the machine after it is the same as after the steps.
`what mc = 2` (already used to count `spent`) says the pc is on the
jump to itself, in the kernel, with the pages off. Measured: play's
run as above, korobeiniki.wav's sound the same bytes, 11.0 s to 8.7 s
(the host at load 10). A profile (-prof) no longer counts the idle
loop's instructions; `spent` (each core's busy and idle, with -cores)
still does.

**T13. The sound's write woken when it fits.** play writes its WAV
2,048 samples a write; the kernel takes a write whole when it fits in
the ring (8,192 samples, a second ahead of the speaker), else the
process waits. The alarm was set 4 ticks (10 ms) on, and each look
copied the write from the process (`k_string`) and parsed it again
(`sounds`'s `String.sub`): 2,048 samples need 256 ms of room, so a
block was copied about 25 times. `speak` now says how many samples are
missing, and the alarm is set to when the speaker will have played
them (20 a tick of 2.5 ms). Profile of the same run at -rate 20:
`k_string` 26.9M to 5.6M, the kernel's `ml_string_sub` 31.6M to 6.9M;
busy instructions 135M to 88M. The song alone is then about 68M
instructions for 6.4 s, 10.6 million a second: half of the window's
20, where it was about 17.

What remains in play's profile (88M, 2026-10-27): play's own `piece`
and the read of the file (`u_read`, the program's `ml_string_sub`,
`ml_bytes_blit_string`: the 141 KB read before the first sound), the
kernel's `add_samples` (a peekb and a pokeb a sample) and k_string.

## Open questions

1. T12's gain on the recorded sessions (tests/TinyMachine_bench.sh)
   not measured.
2. T4's number is the commit's words, not a measure kept.
3. T1 to T3 were measured together on 2026-10-10; T1's and T3's own
   numbers are each "measured alone" in the commit, T2's under node
   only.
