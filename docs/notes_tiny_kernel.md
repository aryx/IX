# TinyKernel.ml: a free kernel in ML

How tiny-kernel (`tiny/TinyKernel.ml`, `./tiny-machine tiny-kernel`)
was designed, and what came out. It is the Kernel row's tiny program in
the README's series, where mini-9pi is the mini one. Two analyses come
first; both were written while the design was being discussed, and the
author asked to keep them. Then the design that was built.

## 1. The question: what could a TinyKernel.ml be?

After mini-9pi and mini-xv6, the author asked what a TinyKernel.ml
running on TinyMachine.ml could be: "not sure how to be tiny and
needing the C-OCaml bridge in kernels/lib_machine/".

**Why mini-9pi and mini-xv6 need `kernels/lib_machine/`.** They are compiled by
ocaml-light's `ocamlopt`, whose runtime is thousands of lines of C
(allocation, the collector, exceptions, primitives). That runtime needs
gcc, a libc, boot code, and C glue for physical memory, trap frames and
the MMU. Together, that is the bridge, and it cannot be made tiny.

**Why tiny-ml avoids it.** ix has its own ML compiler with a C runtime
small enough to read:
- `TinyML.ml` compiles ML to arm64 through TinyC's stack machine.
- `TinyML_runtime.c` holds the allocator and Cheney's collector (500
  lines).
- tiny-c already has a tiny-machine back end (`-tm`), 100 lines.

So the bridge shrinks to three pieces, all built by ix's own tools:
1. a `-tm` back end for tiny-ml;
2. a few ways to reach the machine;
3. a page of assembly for the trap.

The first proposal made TinyKernel.ml a twin of tiny-os v6 (xv6's kind
of kernel), with the same system calls, disk and user programs. The
argument was that the diff against v6 would be the test.

## 2. Why the kernel first came out like xv6

The author noticed that the Tiny series is free everywhere else: "For
the TinyXxx series we are usually more free to not follow existing
program ... but still you suggested to make a kernel like xv6".
Why the difference:

1. **A kernel is not a leaf.** When a tiny program like the editor or
   the shell drifts from its original, nothing else has to change:
   you write its tests and you are done. A kernel is a contract with
   every program above it. Changing its system calls means a new
   shell, ls, cat and C library, or porting old ones. So the most
   expensive part of a kernel's design is its interface. Borrowing an
   existing interface is what makes a free design affordable.
2. **A reference answers the hard questions.** For the other tools,
   correct behavior is easy to state: this input gives that output.
   For a kernel it is diffuse: scheduling, blocking, what `wait`
   returns when, what happens when a pipe's reader dies. Having xv6 or
   9pi to diff against has been the main debugging tool for mini-9pi
   and mini-xv6 (technique 1 in `notes_debugging_techniques.md`). So
   the proposal reached for an oracle by habit.
3. **The precedent was right there.** That session was all twins
   (mini-9pi, mini-xv6). tiny-os v6, the nearest tiny kernel, is
   xv6-inspired by the author's decision. The proposal followed the
   closest example instead of the Tiny series' rule: keep what is
   fundamental, and cut the rest by lines of code.
4. **xv6 is already the tiny point of its design space.** It is Unix
   V6 cut down for teaching, so copying it looks like a small risk. But
   it is tiny for C: locks, a kernel stack per process, an on-disk file
   system. In ML other choices get smaller still: continuations instead
   of kernel stacks, a file system made of ML values. Copying xv6
   would miss what ML makes cheap.

So the free design is the right default for TinyKernel.ml.

## 3. The free design

What a kernel keeps, and how each concept is kept here:

| concept | kept how | why it is cheap in ML on tiny-machine |
|---|---|---|
| user and kernel modes, system calls | a trap returns from `k_run`; the call is a `match` on its number | the machine has one way in and one way out |
| preemptive scheduling | round robin on the timer | a list, the process that ran moved last |
| protection | tiny-machine's base/bound window, relocating: a partition of 1 MB per process | no page tables to build |
| processes: fork, exec, exit, wait | `fork` copies the window's memory and the trap frame | with base/bound, fork is one `k_copy` |
| blocking | a closure kept per waiting process: the rest of the call, retried by the scheduler | no kernel stack per process, no `swtch`, no sleep, no locks |
| files and directories | a tree of ML values in the kernel heap | no disk format, no mkfs, no buffer cache, no log |
| console, pipes | other kinds of open file | pipes are what makes a shell a shell |

Dropped:
- the disk (the files come in the boot image and live in memory);
- page tables and multicore;
- users, permissions and signals.

The core types:

```ocaml
type node = Dir of (string * node) list ref | Data of string ref | Tty
type file = Open of node * int ref * bool | Reader of pipe | Writer of pipe | Console
type state = Ready | Waiting of (unit -> bool) | Zombie of int
```

The recommendation of section 1, to borrow v6's system calls for
v6's userland, was not taken. The author: "I want the 'free'
TinyKernel.ml, ... with all those concepts and kept how". The system
calls are the kernel's own. Six user programs still come for free:
tiny-os t6's cat, echo, ls, wc, mkdir and rm use only calls both
kernels have, so they run unchanged.

## 4. What was built (2026-09-27)

| file | what | lines of code |
|---|---|---|
| `tiny/TinyKernel.ml` | the kernel, in tiny-ml's ML | 318 |
| `tiny/TinyKernel/entry.tm` | `k_run`, the trap's entry, the timer, the window, copy and zero | 142 |
| `tiny/TinyKernel/runtime.c` | the memory's layout, write and exit, peek and poke, strings to and from memory | 79 |
| `tiny/TinyKernel/user/` | `sh.c` (fork, exec, dup), `mltests.c`, `user.h`, `sys.tm` | 435 |
| the kernel, then | | **539** |

Lines are counted without comments or blank lines. For comparison, t6's
kernel is 1,171 lines (`main.c`, `proc.c`, `file.c`, `t6.h`,
`entry.tm`) and v6's 2,178.

**The toolchain's changes**, each kept apart so that the old paths
work as they did:
- `TinyML.ml`: `-tm`, a second back end of the stack machine
  (`machine_tm`, 150 lines). The registers r1..r11 hold the
  expression stack, r12 is the value stack's top, and r13 is scratch
  and the result. Static data is written for 4-byte words, and
  `max_int` is 2^30 − 1.
- `TinyML_core.c`: the runtime's common part, split out of
  `TinyML_runtime.c` and word-size generic (`intptr`). Its includer
  gives it memory through `ml_run`: the host's arrays on arm64, or
  fixed addresses in the kernel.
- `TinyC.ml`: the `intptr` typedef (Plan 9's `uintptr`, signed), an
  integer as wide as a pointer, so the runtime is written once for
  both machines.

**Better than planned: no intrinsics.** Section 1 expected about 30
lines of new primitives in the compiler (`%peek`, `%csrr`, ...). None
were needed. The machine is reached through `external` functions of C
or assembly, called like any runtime function. The one idea that made
this possible: **the kernel is a loop, and `k_run` returns at the
process's next trap.** `k_run` saves the kernel's sp and link, loads
the process's registers from its frame, and erets. The trap entry
saves them back and returns from `k_run` with the cause. So the kernel
calls a process like a function, as a hypervisor's `KVM_RUN` runs a
guest. There is no trap handler written in ML and no way into ML but
the toplevel.

**Blocking by closures, without wakeups.** A call that must wait (a
read of an empty pipe, a write to a full one, a `wait` with children
running) leaves its process `Waiting` with a closure for the rest of
the call. The scheduler calls that closure when it looks for a process
to run, and the process becomes ready when the closure can finish. So
there is no channel and no wakeup to forget. Waiting is on a
condition, as with Brinch Hansen's `await` or Plan 9's
`sleep(r, cond)`; the price is one retry per round of the scheduler.

**The test** (`make check` in `tiny/TinyKernel/`, 10 s):
- `mltests`: fork and wait's statuses, exec's arguments through a
  pipe, pipes (1,500 bytes through a 512-byte pipe, and the end), files
  (create, truncate, unlink), directories and `..`, a fault killed,
  and preemption (two spinning children both start before either
  ends);
- a script through the shell (a pipe, redirections, `ls` by t6's
  program, `cd` and `..`);
- both against `check.expected`.

It booted the first time, with every test passing.

`tiny/TinyML_test.sh` now also runs tiny-ml's test programs on
tiny-cpu through `-tm`: 11 of 14 pass. The other three are left out on
purpose: arith and strings print `max_int` (31 bits there), and gc's
lists go deeper than tiny-cpu's 1 MB holds. The arm64 results are
unchanged, and tiny-os t6's and v6's checks pass.

## 5. Next, cheap in this design

- Saving the files: the tree written to a disk (`-d`) at the halt and
  read at the next boot.
- A waiting closure kept with what it waits for and retried only when
  that changes (a typed wakeup).
- `kill(pid)`, ended at the process's next trap.
- Copy-on-write fork with tiny-machine's Sv32 pages: the reason pages
  came.
- The kernel's heap measured: live words after each collection,
  printed at the halt.
- Running tiny-ml programs as user programs, so that the whole system,
  kernel and userland, is ML.
