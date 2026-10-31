# Plan: replay and going back, in ix's emulators (`machine/`, `raspberry/`) and the playground

Split from plan_debugger.md on 2026-10-31, its stages 10 to 12 and
its decision 13 (the author: "Good idea to move in a separate
plan_debugger_replay.md the time travel stuff"), when that plan's
debugger was done and its traces were what was left.

These stages came with the debugger plan's rewrite of 2026-10-29 (the
author: "Anything more recent that we could steal ideas from that
helps even more the debugging process?"): what a debugger of today
does that Plan 9's did not, and can be had small because ix has its
own emulators. They build on plan_debugger.md's mini-acid (its builtins
drive the replay) and on mini-5i's /proc (that plan's decision 12: the
same side serves the replay).

## Stages

| | what | who uses it | state |
|---|---|---|---|
| 1 | **Replay, and going back** (rr, Mozilla 2014; Pernosco; and before them ocamldebug's checkpoints, Vouillon, 1990s): mini-5i records what comes from outside (each system call's results, the signals' instants), and plays a run again exactly; snapshots along the way, and a run played to an instant from the nearest. Then going back: `reverse-continue` to the last write of an address (a watchpoint over the run played again), which is the question of the debugger plan's survey's second line: who wrote the bad value. mini-acid drives it by builtins | whoever debugs a crash whose cause was earlier: the collector's, the kernel's | |
| 2 | **The board's run played again**: the same in mini-qemu, the whole system (its interrupts' instants, the keyboard's, the card's, the network's bytes recorded), so a kernel's panic is replayed and gone back from; and a gdb remote stub, QEMU's `-s`, for the host's gdb on mini-9pi's kernel meanwhile | who debugs mini-9pi | |
| 3 | **Time travel in the playground** (Elm's debugger, 2016): a program of lib_playground is a model, an update and messages; the messages recorded, any instant is the first model updated by them. A slider over a game's past, its model shown | a reader of a game; the playground's teaching | |

## Decisions to take

1. **What replay records, and its cost.** mini-5i is deterministic but
   for its system calls (their results, the bytes they read), its
   signals and its time: a log of those is a run. rr's design, without
   rr's hard part (counting instructions on a real CPU's counters):
   mini-5i counts them. Snapshots: the memory's segments copied every
   N instructions (or by pages changed). Proposed: a run of mini-doom's
   start recorded, its log's size and the replay's speed measured first;
   threads (mini-5i runs them one at a time) in the log as switches at
   counted instants.

## Tests

- Stage 1: a program whose bug writes a bad value early and crashes
  late (a C program, then the survey's kind: a mini-ml program with a
  bad external); the reverse watchpoint names the write; a recorded
  run replayed gives the same instructions' count and output.

## Status

2026-10-31: split from plan_debugger.md (its stages 10, 11, 12 and
decision 13, as they were). Nothing begun.
