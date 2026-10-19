# Plan: a debugger in t-ix, debug and trace on tiny-kernel in about 550 lines

The author (2026-10-18): "what could be a tiny-debugger?"; then
"running on the tiny-machine"; then "let's write the plan document";
then (2026-10-19) "we can maybe use dbg or debug instead of db", and
"we also probably want something like tiny-strace, that maybe we can
also just call trace (like we have debug)" (section 5).

t-ix has a compiler for C and one for ML, a profiler (tiny-prof), and a
kernel that runs their programs, but nothing that stops one of them
to look at it. A program that goes wrong on tiny-kernel says
`ml: 5: trap 3 at 412, 1048580: killed` and is gone. This plan is a
debugger that runs on tiny-kernel as one of its programs, `debug`, and
the few lines of kernel that it needs. (Plan 9's name, `db`, is taken:
the host's tiny-db is the database.)

Its twins: Plan 9's `db` and `acid`, which control a process through
`/proc/n/{mem,regs,ctl}`, and the breakpoints of mini-5i (`machine/`),
which a debugger can have for free because it is the CPU. Here the
debugger is not the CPU: it is a process that controls another one.

## 1. The idea: stop, look, resume, by messages

```
    debug, a process (ML, TinyLibStd): commands typed, as in ed
        |  write "b main" "c" "s" "r" "m addr n" "w addr word"
        |  read  "stopped pc cause" "exited status" ...
        v
    a trace descriptor: sys_trace pid (TinyKernel.ml)
        |  the kernel stops the process, reads its frame and its window,
        |  writes its memory, and resumes it for one instruction or until it traps
        v
    the traced process, which does not know it is traced
        |  a breakpoint is a word 0 in its code: c_illegal
        |  a step is the timer set to one instruction: c_intr
        v
    tiny-machine, unchanged
```

- **The machine already has what is needed.** In TinyMachineCPU,
  "zero is no opcode, so memory never written stops a program": a
  breakpoint is a 0 word written where the instruction was, and the
  CPU traps with `c_illegal` (2). The timer counts instructions, so a
  single step is the timer set to 1 before `k_run`, and the CPU traps
  with `c_intr` after one instruction. Neither needs a new device, a
  debug register or a trace bit. (A machine of our own design pays off
  here: on arm64, gdb places a breakpoint on each side of a branch to
  step, because the timer does not count instructions.)
- **The kernel only adds a state.** A traced process that traps is not
  killed, as `run` does today for every cause but a call and an
  interrupt (`TinyKernel.ml`, the `puts "...: killed"`). It becomes
  `Stopped`, and the debugger's waiting read answers. Reading the
  registers is `reg p k` on its frame, and reading its memory is a
  `peek` at `p.base` plus the address. Resuming makes it `Ready` again.
- **The interface is messages on a descriptor**, as for `/dev/draw` and
  `/dev/audio`: one new call, `sys_trace pid` (23), gives a descriptor.
  Writes to it are commands and reads are answers. A read waits until
  the process stops or exits, and in this kernel a waiting call is a
  closure the scheduler retries, so no new mechanism is needed for
  waiting either. A `/proc/n/` tree would be Plan 9's way, and it would
  suit the kernel's files as ML values, but it needs reads at an
  offset, and a single descriptor is less code.
- **The debugger is ordinary.** debug is a program like `ed`: it reads
  commands on the console, and it knows nothing of the kernel but the
  messages. It works at the level of instructions and function names.
  There are no line numbers, since neither tiny-c nor tiny-ml emits
  them (section 4).

## 2. The kernel side, about 60 lines

The messages, one per write, each answered by one line to read. The
numbers are in decimal, the only ones the kernel's `int_of_string_opt`
reads; debug shows them in hex:

```
    b addr      a breakpoint: the word saved, 0 written      ok
    d addr      the breakpoint removed: the word put back    ok
    c           continue                                     (none until it stops)
    s           one instruction                              (none until it stops)
    r           the registers                                r1 v ... r15 v pc v
    m addr n    n bytes of memory                            their hex
    w addr v    a word written                               ok
    (a stop)                                                 stopped pc break
                                                             stopped pc illegal word
                                                             stopped pc fault addr
                                                             stopped 0 exec
    (the end)                                                exited status
```

There is no message to kill: the tracer has `kill(pid)`.

Starting a program stopped: the child of debug calls `sys_trace` on its
own pid (0) before its `exec`, which means "stop me at my first
instruction and wait for my parent". This is Plan 9's `hang` written to
`/proc/n/ctl`. Attaching to a process already running, `debug pid`, is
the same call with its pid.

What the kernel keeps for a traced process: who traces it, its
breakpoints (an address and the word that was there), and whether it
steps. The details that need care:

- **Continuing from a breakpoint.** The word is put back, the process
  steps one instruction, the 0 is written again, and then it continues.
  The kernel does this, not debug, so that `c` is one message.
- **The timer.** The kernel's own tick (`k_timer tick`, and `counted`
  in `interrupts`) is shared with every process. A step sets the timer
  to 1 for the stepping process only and sets it back after. The time
  of the step must not count as a tick for the other processes.
- **fork.** A child copies its parent's memory, breakpoints included,
  and a child that is not traced would be killed at its first 0. The
  kernel writes the saved words back into the child's copy, since the
  traced process's breakpoints list is at hand.
- **exec.** The new image replaces the code and its breakpoints. The
  process stops at its first instruction, so debug can set them again
  (`stopped pc exec`).
- **The other causes.** A fault (`c_fault`, an address outside the
  window) stops a traced process too, and that is the most common
  reason to run debug: to see where a program dies, and from where.

The call is added where the others are: the dispatch in TinyKernel.ml,
`TinyKernel/libc/sys.tm` for C, and `TinyKernel/libml/calls.ml` with
`TinyLibSystem.ml` for ML.

## 3. The debugger side, debug, about 300 lines

debug is ML on TinyLibStd, a file of `user/` and `/bin/debug` in the boot
image. Its commands are ed's kind, a letter and its arguments:

```
    debug prog args        the program started, stopped at its first instruction
    debug pid              attached to a process
    b main  b 0x1a4     a breakpoint, at a function or an address
    c  s  n             continue, one instruction, one instruction over a call
    r                   the registers, the pc with its function
    x addr [n]          memory as words; x/i: as instructions
    bt                  the backtrace
    q                   quit (the program killed, or left to run if attached)
```

What it reuses rather than rewrites:

- **The disassembler.** TinyMachineCPU decodes a word back to its text
  (`tiny-cpu -l`'s listing), so `x/i` and the line printed at each stop
  (`main+0x14: bne r1, r0, 0x4`) are that function.
- **The names.** TinyProfiler's `find` (the function an address is
  in) and `clean` (tiny-ml's `f155_foo<>` as `foo`) move from
  TinyProfiler.ml to where both can use them, rather than being copied.
- **The backtrace, from the code itself.** There is no frame pointer
  and no table of frame sizes, but the epilogue of tiny-c's functions
  and of tiny-ml's (`-tm`) has the same two words: `ldw lr, k(sp)` and
  `addi sp, sp, f`. debug reads forward from the pc to the function's
  epilogue, decodes those two words, and gets the frame's size and
  where lr was saved. Then it repeats at the caller. Two cases need
  care: a stop at a function's first instruction, before its
  `addi sp, sp, -f`, when lr is still in r15; and tail calls, whose
  frames are gone (a backtrace shows the callers that will be returned
  to, not all of the calls that were made).
- **tiny-ml's values.** The value stack (r12 under `-tm`) is the
  roots of the collector. `bt` can show, for each frame, its slots on
  that stack as integers or pointers. Printing them as ML values would
  need their types, so it is left out (section 4).

debug's core is functions over a target: its peek, its registers, its
step and continue. On tiny-kernel the target is the trace descriptor.
On the host, for its tests, the target is TinyMachineCPU running a
`.tm` program directly. The same file is tested on the host first,
the way TinyKernelNetwork is.

## 4. Where the names come from

A program in `/bin` is an image with a header of three words (a magic
number, the image's size, the memory it asks for) and no symbols, so
debug has nothing to name addresses with. Two ways to fix this:

1. **The symbols after the image** (Plan 9's a.out: text, data, then
   the symbol table). `tiny-linker -a` writes, after the image, its labels
   as text lines (`name address`; its `-map` writes them beside the
   image today, for tiny-prof). The header's size stays the image's,
   and `load_prog`'s check `size = n - 12` becomes `size <= n - 12`,
   so that a loader that knows nothing of symbols still works. debug reads
   them from the file it was given, or from `/bin/` plus the process's
   name when attached.
2. **A file beside the program** (`/bin/prog.sym`). This changes no
   format, but it doubles the files of `/bin` and the two can disagree.

The plan takes the first. It costs the boot image some kilobytes,
which is to be measured. Leaving out compiler-local labels (`.L12`,
TinyProfiler's `local`) keeps it small.

What is left out, deliberately:

- **Line numbers and source.** tiny-c and tiny-ml would have to
  emit them, and the assemblers would have to carry them. A function
  name and an instruction is what Plan 9's db shows, and enough to find
  a crash in a program of a few hundred lines.
- **Types.** Printing a C variable or an ML value by its type needs
  the compilers to describe their frames. acid's road, a language for
  the printing, is a later plan if one is wanted.
- **The kernel.** Debugging tiny-kernel itself would be a debugger on
  the host, inside tiny-machine (a `-db` option, as mini-qemu has a
  gdb stub). That is another plan: this one is a program of the
  system, for the system's programs.
- **A window.** A debug on TinyLibGUI's `run_canvas` (the registers, the
  instructions around the pc, and buttons for step and continue) is a
  natural second program, on the same messages, once the line version
  works.

## 5. trace, the calls a process makes

A second program on the same descriptor: `trace`, strace's idea, the
system calls of a process as they are made, one line each. Plan 9's
twin is ratrace, which writes `startsyscall` to `/proc/n/ctl` and
reads the process's stops; Linux's strace stops a process the same way
(ptrace's `PTRACE_SYSCALL`). The program and the call share the name
`trace`, as `kill` is a program and a call on Unix. What it would
print, roughly (cat's real calls are utils's, through TinyLibSystem):

```
    % trace cat f
    open("f", 0) = 3
    read(3, "hello\n", 512) = 6
    write(1, "hello\n", 6) = 6
    hello
    read(3, "", 512) = 0
    close(3) = 0
    exit(0)
```

- **The kernel: a stop on the way in and on the way out.** One more
  command, `y` (and `n` to stop it): a traced process stops at each
  `sys`, before the call is done, and its tracer reads
  `call n a1 a2 a3` (the number and r1 to r3). `c` from there does the
  call and stops the process again on its way out, `ret n r`: at once
  if the call finished, or when its waiting closure does (in
  `runnable`, where a Waiting process becomes Ready). Between the two,
  the tracer reads the process's memory (`m`): a write's bytes and a
  path on the way in, a read's bytes on the way out. `exit` has no way
  out (its end says `exited`), and `exec`'s is its stop at the new
  program's first instruction. About 25 lines: the call's number kept
  in the trace while the process waits to be let in, and `syscall`
  given the number rather than reading it from `k_tval`, so that the
  tracer's `c` can run it later.
- **Why two stops and not one line after the call**: the kernel would
  have to keep the arguments, and an `exec`'s path is gone once the
  call is done (its memory is the new program's), while a `read`'s
  bytes are not there yet before it. The two stops keep the kernel to
  stop, look and resume, and leave the decoding to the program.
- **The program, about 100 lines of ML.** `trace prog args` starts its
  program as debug does (fork, `trace(0)`, exec), `trace pid` attaches;
  then `y`, and a loop: read a stop, print, `c`. It has a table of the
  calls (their names in `user.h`'s order and the kind of each argument:
  a number, a path, a buffer and its length), reads a path up to its 0
  and a buffer's first 32 bytes with `m`, and prints them escaped, as
  strace does. It writes to its descriptor 2, so that `trace prog > f`
  keeps the program's output apart.
- **Left out**: the children (strace `-f`). A forked child is not
  traced; following it would need the tracer to get a descriptor on it
  at the fork, and one loop over several descriptors (`ready`). A later
  step, if `trace sh` is wanted.

trace needs only step 1 and the `m` command, not the step or the
names, so it can come before debug: it is the smaller program, and it
exercises the same messages.

## 6. The steps

1. **A stop instead of a kill.** `Stopped` as a state, the tracer and
   the breakpoints in the process, `sys_trace` with `b`, `d`, `c`, `r`, and
   the stop on `c_illegal` and `c_fault`. **Done (2026-10-19)**: about
   100 lines of TinyKernel.ml (a `trace` record and a `Trace` file, the
   messages in `command`, `stop`, `detach`); the stop at exec and the
   breakpoints undone in a forked child, of step 6, came with it, as
   they were a line each. A breakpoint is used once until step 2: `c`
   from it puts its word back and removes it. The test is mltests's
   `traces` (a breakpoint, a fault, an exec), not a separate program;
   `trace` in libc's `sys.tm` and `user.h`, in docs/manuals/t-ix.md.
   tetris's and play's sums recorded again: their sounds 5 ms later, as
   for every change to the kernel's timing.
2. **The step.** The timer set to 1, `s`, continuing from a
   breakpoint, and the tick kept right for the other processes.
3. **debug with addresses only.** The commands of section 3 but `bt`,
   over the target. It is tested on the host with TinyMachineCPU, and
   then on tiny-kernel.
4. **The names.** The symbols after the image (section 4), `find`
   and `clean` shared with tiny-prof, `b main`, and the function at
   each stop.
5. **The backtrace.** Epilogues decoded, for tiny-c's programs, then
   for tiny-ml's with the value stack.
6. **fork and exec.** The child's breakpoints undone, the stop at
   exec. debug on `sh` running a pipeline.
7. **trace.** `y`, the two stops and `c` through a call, in the kernel;
   `m`; the program, `/bin/trace`; a session in `make check` tracing
   `cat` of a file (section 5). It needs only step 1, so it may come
   next.

After step 1, a program that would have been killed can be looked at.
After step 5, debug answers the question a crash raises: where, and called
from where.
