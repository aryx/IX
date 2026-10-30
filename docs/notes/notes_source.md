# Notes on Source: how a program of ix waits, with threads that do not block

The author, 2026-10-19, after mini-netscape's worker: "I still don't
fully understand this Source thing, how it works, why it was simpler
than implementing real threads like in OCaml itself"; then "maybe we
should create a note document for it".

`Source` (`lib_core/commons/Source.mli`) is how a program of ix that
has threads waits for the outside world -- a key, the mouse, a clock,
a 9P request, a socket -- when it is compiled by mini-ml, whose
threads are cooperative. Its design is in
[`plan_rio.md`](plans/done/plan_rio.md), "Threads: the design"; here
it is from the start, with what was met since.

## 1. The problem: a thread that blocks stops them all

mini-ml's threads (`lib_core/concurrency/Thread.ml`, 91 lines) live in
one process of the system. A thread is a value stack and a machine
stack; switching to another is a call of the runtime that saves three
words of the one that leaves and puts back the other's. The scheduler
is a queue of the threads ready to run, in OCaml. A thread runs until
it waits -- on a channel (`Event.sync`), a mutex, a `join` -- or
yields; nothing takes the processor from it.

The kernel sees one process. So when a thread makes a system call that
waits -- a read of the keyboard, of a socket, of a pipe -- the process
sleeps in the kernel, and every thread with it: the window does not
draw, the mouse is not read, a timer is late.

## 2. Three answers

| | OCaml 4.14 (dune's builds) | OCaml 5 | mini-ml |
|---|---|---|---|
| a thread is | a thread of the system (pthreads) | a domain: a thread of the system with its own minor heap | a value stack and a machine stack, switched by the runtime |
| who runs | one at a time: a lock over the runtime | all at once, a core each | one, until it waits or yields |
| a read that waits | releases the lock first: the others run | the others run | **through `Source`**: a process waits in its place |
| a thread that only computes | the lock taken from it every 50 ms (a ticker thread) | runs beside the others | keeps the processor: it must yield |

OCaml's answer is in its runtime: each blocking call is wrapped in
"leave the runtime" and "enter it again" (`caml_enter_blocking_section`),
so the lock is free while a thread sleeps in the kernel, and a ticker
thread sets a flag every 50 ms that makes the running thread give the
lock at its next safe point.

## 3. What Source does

Plan 9 has no `select`: a process waits for you. `Source` gives each
thing a program waits for a process of its own, which waits in an
ordinary read, and brings what it read to the program as a message on
a channel:

    the keyboard  --> a process, waiting in read  --.
    a socket      --> a process, waiting in read  --+--> one pipe --> the program reads it
    the clock     --> a process, waiting in sleep --'    when all its threads wait

    a frame on the pipe:  [ the source's number | a length, 2 bytes | the bytes ]

    the program:  a frame --> its source's pump thread --> its channel
                  --> the thread in Event.sync (Event.receive ch), or in Event.select

1. `Source.reader caps fd n` forks a process. It closes every
   descriptor but its own few, reads `fd`, and writes each read,
   framed, to the one pipe all sources share (a frame under 4 KB is
   one write, whole, among the others').
2. The program never reads `fd`. Its threads wait on channels. When
   none can run -- each is waiting -- the scheduler calls its idle hook
   (`Thread.idle`), which `Source` set to: read the pipe. Waiting there
   is right, since nothing else could run.
3. Each whole frame goes to its source's queue, and that source's pump
   thread is woken; the pump sends the bytes on the source's channel,
   and the thread waiting on it runs.
4. The process reads again only when the program has taken what it
   gave (a byte on a pipe of the source's own). So a program that is
   late gets the newest: `/dev/mouse` read late gives where the mouse
   is, not each place it went. (Before, the process read ahead, and a
   window dragged under mini-rio followed the mouse seconds behind.)

`Source.timer` and `Source.alarm` are the same, a process sleeping
instead of reading. A thread can wait for several things at once:
`Event.select [ receive keys; receive mouse; receive alarm ]`.

The same interface has a second file, `lib_core/commons/Source.ml`,
for OCaml's threads: there a thread does the read and sends, since a
read that waits frees the runtime.

## 4. Why it was simpler than threads of the system

What mini-ml would need for OCaml's kind of threads:

- threads of the system sharing memory: `clone` in ix's C library for
  Linux on arm and arm64, and in mini-9pi's kernel, where Plan 9 has
  only processes that may share memory (`rfork(RFMEM)`);
- a lock over the runtime, and each blocking primitive releasing it;
- a collector that moves blocks while another thread may hold their
  addresses: every thread's stack a root, stopped at a safe point;
- a ticker and a signal for the 50 ms, and safe points in the
  compiled code to give the lock at;
- then the bugs of memory shared between threads, in the runtime
  itself.

What `Source` needed: `fork`, `pipe`, `read`, `write` -- which ix's
programs have on Linux and on mini-9pi already -- and 126 lines. No
memory is shared, so the collector, the runtime and the scheduler did
not change, and a thread still loses the processor only where it says
so: between two waits it is alone, and what it changes needs no lock.

What it costs: a process for each source; a copy of what is read
through a pipe; frames of 4 KB at most; and a condition on the program,
next.

## 5. The rule, and the condition

The rule (plan_rio's): **a thread never reads a descriptor that may
block; it receives from a source's channel.**

The condition: **the program must wait sometimes**. The pipe is read
only when no thread can run. A program that is a loop of events --
each thread waiting on its channels, as mini-rio's windows and its
file server, and `Plan9_loop`, the playground's loop on Plan 9, which
waits on the keyboard, the mouse and `Source.alarm` between two frames
-- reads its sources. A loop that never waits never does.

Met: mini-netscape's worker (`Tab_worker`, 2026-10-19). Built by
mini-ml, its window's loop is the window-less platform's, the tests',
which makes frame after frame and never waits on a channel; a worker
waiting through a source there would never be woken. `worker=wait`
works: the window waits on a condition for the worker, nothing is
ready, the scheduler is idle.

## 6. On mini-9pi: a fork copies

mini-9pi's fork (`rfork(RFPROC|RFFDG|RFREND)`) copies the memory the
program has touched; the kernel shares none of it. A source forked
late is a copy of a large program: mini-page, which had drawn its
first page (tens of megabytes) before `Plan9_loop` forked its keyboard
reader, no longer fitted in mini-9pi's 192 MB beside its copy
(`plans/bugs/ix.md`, 2026-10-10). Since then the platform forks its
sources before the program starts. **A source is made early**, when
the program is small.

## 7. Where it is used

- mini-rio: the 9P requests of its file server (`Rio`: a
  `Source.reader` on its pipe).
- `lib_graphics`' `Keyboard` and `Mouse` on Plan 9: `/dev/kbd`,
  `/dev/cons`, `/dev/mouse`; and `Plan9_loop`, the playground's loop
  there, waits on them and on `Source.alarm` for its next frame.
- `Stats`: a timer.
- mini-netscape's worker, built by mini-ml: the worker and the window
  are threads; the network does not go through `Source` yet.

## 8. Next: mini-netscape's network on mini-9pi

There a read of `/net/tcp/n/data` waits, and with it the window: a
page from a slow server freezes mini-rio's window as it did on Linux
before the worker. Two ways, by section 6:

- **A reader a connection** (`Source.reader` on its data file, made
  by `Tcp`): the smallest change, in `lib_networking/tcp/plan9`; but a
  fork each new connection, of a program already large -- the copy
  section 6 warns of.
- **A network process, made at the start** (Plan 9's webfs, which
  abaco fetches through): forked while the program is small,
  it holds the connections, the TLS sessions and the keep-alive pool,
  and answers requests on a pipe the program reads through a source.
  It also does TLS's arithmetic on another processor where there is
  one. What it asks: the cookies, which a page's script reads and
  writes in the program (each request takes the program's, each answer
  gives back the process's).

The second is the one that fits section 6.

## Others

- Plan 9's libthread: `proc`s and `thread`s, and `ioproc(2)`, a
  process kept to do a thread's blocking calls -- `Source`'s idea.
  Rob Pike, "A Concurrent Window System" (Computing Systems, 1989):
  a window system as processes on channels.
- John Reppy's Concurrent ML (1991): `Event`'s channels, `sync`,
  `select`, `wrap`; OCaml's `Event` module is its.
- Go: goroutines over a few threads, and the runtime's network poller
  (epoll) parks a goroutine whose read would block -- `Source` done
  inside a runtime.
- Node.js's libuv: the network by epoll, and a pool of threads for the
  file calls that cannot be made non-blocking.
- OCaml's Lwt: promises over `select` (or libev), and `Lwt_unix`'s
  blocking calls run on threads of the system.

References: `lib_core/commons/Source.mli`,
`lib_core/concurrency/Source.ml` and `Thread.ml`; plan_rio.md,
"Threads: the design"; `browsers/netscape/Tab_worker.mli`; thread(2)
and ioproc(2) of Plan 9.
