/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* mini-xv6 (plan_kernel.md): the processes' kernel side, the same on
 * every board (board.h says what differs: the trap frame's size, the
 * registers swtch keeps). Each process a slot: a trap frame (the
 * user's registers, saved by the board's trap entry), a kernel stack
 * and a context; the switch between them; the calls into OCaml
 * ("process_start", "trap", "irq", "fault").
 *
 * The runtime's view of the stack. OCaml's collector finds the values
 * a stack holds from a few globals, set when OCaml calls C
 * (caml_bottom_of_stack, caml_last_return_address: where OCaml's frames
 * stop; caml_gc_regs, caml_exception_pointer, local_roots). They
 * describe the running stack; each process's kernel stack has its own
 * values, kept in its context while it does not run: k_swtch saves them
 * with the registers and puts them back when the process resumes. And
 * the collector must see the stacks that do not run: scan_stacks,
 * installed as the runtime's scan_roots_hook (the one systhreads uses),
 * walks each with do_local_roots. */

#ifdef OCAML4
#define CAML_INTERNALS                /* roots.h, stack.h */
#endif
#include <mlvalues.h>
#include <callback.h>
#include <memory.h>
#include <alloc.h>
#ifndef MINI_ML
#include <roots.h>
#include <stack.h>
#include <string.h>
#endif
#ifdef OCAML4
/* OCaml 4.14's runtime (kernel.mk's COMPILER=ocaml): the same view of
 * the stack, in its domain state; the same hook */
#define caml_bottom_of_stack Caml_state_field(bottom_of_stack)
#define caml_last_return_address Caml_state_field(last_return_address)
#define caml_gc_regs Caml_state_field(gc_regs)
#define caml_exception_pointer Caml_state_field(exception_pointer)
#define local_roots caml_local_roots
#define scan_roots_hook caml_scan_roots_hook
#define do_local_roots caml_do_local_roots_nat
#endif
#include "board.h"

#define NPROC 64                      /* xv6's param.h */
#define KSTACK 16384

void user_return(void);
void exit(int status);

/* Several cores (docs/plans/plan_multicore.md; board.h's CORES, the
 * Pi 2's four): one lock for all of the kernel. A core takes it where
 * it comes into the kernel (the board's trap entries: kernel_enter)
 * and gives it back where it leaves for user mode (user_return:
 * kernel_leave) and around its wait when it has nothing to run
 * (wait_interrupt). So one core at a time is in the kernel: the heap,
 * the collector and every module are one core's as before, and the
 * runtime never learns that there are several. What is a core's own:
 * the slot it runs (current), that slot's trap frame (cur_tf, read by
 * the trap entry in assembly: cur_tfs), and a scheduler's slot with
 * its stack to wait on (slot NPROC + the core's number; NPROC for
 * all of them in OCaml, k_current's and k_swtch's).
 * The runtime's view of the stack is the lock's holder's: given up
 * with the lock (saved in the running slot's context), taken with it.
 * A process in user mode on another core is, for the collector, a
 * stack that does not run, as one switched from. */
#ifdef CORES
#define NCORE CORES
static inline int core(void)
{
  unsigned v;
  __asm__ volatile("mrc p15, 0, %0, c0, c0, 5" : "=r"(v));    /* MPIDR */
  return v & 3;
}
uintptr *cur_tfs[NCORE];
#define cur_tf (cur_tfs[core()])
#else
#define NCORE 1
#define core() 0
uintptr *cur_tf;
#endif

/* the trap frames; the board's trap entry uses the running process's */
uintptr trapframes[NPROC][TF_WORDS];

/* a context: what swtch keeps (the callee-saved registers, sp, lr, the
 * callee-saved floating point registers: board.h), then the runtime's
 * view of the stack */
struct context {
  uintptr regs[CONTEXT_REGS];
  uvlong vfp[8];
#ifndef MINI_ML
  char *bottom_of_stack;
  uintptr last_return_address;
  value *gc_regs;
  char *exception_pointer;
  struct caml__roots_block *roots;
#endif
};

/* the processes' slots, and one more a core: its scheduler's (the
 * first's on the boot stack, another core's on the stack it started on) */
static struct context contexts[NPROC + NCORE];
static char kstacks[NPROC][KSTACK];
#ifdef CORES
static int currents[NCORE] = { NPROC, NPROC + 1, NPROC + 2, NPROC + 3 };
#define current (currents[core()])
#else
static int current = NPROC;
#endif
static int started[NPROC + NCORE];

void swtch(struct context *from, struct context *to);
#ifdef CORES
void core_slice(void);
#endif

/*****************************************************************************/
/* The trap frame */
/*****************************************************************************/

/* the running process's trap frame, word n */
value tf_get(value n) { return Val_long(cur_tf[Int_val(n)]); }
value tf_set(value n, value v) { cur_tf[Int_val(n)] = Long_val(v); return Val_unit; }

/* back to user mode, from the running process's trap frame */
value user_resume(value unit) { (void)unit; user_return(); return Val_unit; }

/*****************************************************************************/
/* The processes */
/*****************************************************************************/

/* mini-ml's runtime (plan_kernel_mini_ml.md, step 4): the values a
 * function keeps are on a value stack, not the machine's. A process has
 * its own (vstacks), given to the runtime with its number (ml_stack: 0
 * is the boot's, the scheduler's; slot i's is i + 1), and a switch says
 * which one runs (ml_stack_switch), the runtime keeping each one's top,
 * exception handler and C roots. Nothing to save here, no hook: the
 * collector scans them all. */
#ifdef MINI_ML
#define VSTACK 16384                  /* words */
static value vstacks[NPROC][VSTACK];
void ml_stack(int, value *);
void ml_stack_switch(int);
#define save_view(c)
#define restore_view(c)
#else
static void save_view(struct context *c)
{
  c->bottom_of_stack = caml_bottom_of_stack;
  c->last_return_address = caml_last_return_address;
  c->gc_regs = caml_gc_regs;
  c->exception_pointer = caml_exception_pointer;
  c->roots = local_roots;
}

static void restore_view(struct context *c)
{
  caml_bottom_of_stack = c->bottom_of_stack;
  caml_last_return_address = c->last_return_address;
  caml_gc_regs = c->gc_regs;
  caml_exception_pointer = c->exception_pointer;
  local_roots = c->roots;
}

/* the collector's hook: the stacks that do not run (a process not yet
 * started has no OCaml frames) */
static void scan_stacks(scanning_action f)
{
  int i;
  int cur = current;
  for (i = 0; i < NPROC + NCORE; i++)
    if (i != cur && started[i] && contexts[i].bottom_of_stack != NULL)
      do_local_roots(f, contexts[i].bottom_of_stack, contexts[i].last_return_address,
                     contexts[i].gc_regs, contexts[i].roots);
}

#endif

/* a new process's first run: its kernel stack empty, its view of it
 * empty, OCaml entered by a callback (whose link says: no frames
 * above) to "process_start", which enters user mode */
static void trampoline(void)
{
  static value *start = NULL;
  restore_view(&contexts[current]);
  if (start == NULL) start = caml_named_value("process_start");
  callback(*start, Val_int(current));
  exit(4);                     /* process_start never returns */
}

/* slot [p]'s kernel side: a fresh kernel stack, entered at the
 * trampoline (its first switch) */
value proc_context(value p)
{
  int i = Int_val(p), k;
  struct context *c = &contexts[i];
  for (k = 0; k < 10; k++) c->regs[k] = 0;
  c->regs[CONTEXT_SP] = (uintptr)(kstacks[i] + KSTACK) & ~(uintptr)15;
  c->regs[CONTEXT_LR] = (uintptr)trampoline;
#ifdef MINI_ML
  ml_stack(i + 1, vstacks[i]);
#else
  c->bottom_of_stack = NULL; c->last_return_address = 0; c->gc_regs = NULL;
  c->exception_pointer = NULL; c->roots = NULL;
#endif
  started[i] = 1;
  return Val_unit;
}

/* slot [p]'s trap frame: zeros, user mode, interrupts on (xv6's
 * userinit) */
value tf_init(value p)
{
  int i = Int_val(p), k;
  for (k = 0; k < TF_WORDS; k++) trapframes[i][k] = 0;
  trapframes[i][TF_PSR] = TF_USER_PSR;
  return Val_unit;
}

/* fork: the running process's trap frame copied to slot [p]'s, but r0:
 * 0, fork's result in the child */
value tf_copy(value p)
{
  int k;
  for (k = 0; k < TF_WORDS; k++) trapframes[Int_val(p)][k] = cur_tf[k];
  trapframes[Int_val(p)][0] = 0;
  return Val_unit;
}

/* a slot no longer used: the collector need not look at its stack */
value proc_free(value p)
{
  started[Int_val(p)] = 0;
#ifdef MINI_ML
  ml_stack(Int_val(p) + 1, vstacks[Int_val(p)]);     /* empty again */
#endif
  return Val_unit;
}

/* from the running slot to [to] (a process, or NPROC the scheduler);
 * returns when something switches back */
value k_swtch(value to)
{
  int from = current, t = Int_val(to);
  if (t == NPROC) t += core();        /* this core's scheduler */
#ifdef MINI_ML
  ml_stack_switch(t < NPROC ? t + 1 : 0);
#else
  static int hooked = 0;
  if (!hooked) { scan_roots_hook = scan_stacks; started[NPROC] = 1; hooked = 1; }
#endif
  save_view(&contexts[from]);
  current = t;
  if (t < NPROC) {
    cur_tf = trapframes[t];
#ifdef CORES
    core_slice();
#endif
  }
  swtch(&contexts[from], &contexts[t]);
  /* back in [from] (on another core, maybe) */
  restore_view(&contexts[from]);
  return Val_unit;
}

/* (a core's scheduler: NPROC, whichever the core) */
value k_current(value unit) { (void)unit; return Val_int(current < NPROC ? current : NPROC); }
value k_core(value unit) { (void)unit; return Val_int(core()); }

/*****************************************************************************/
/* The cores */
/*****************************************************************************/

/* How long each core waited with nothing to run, in microseconds
 * (their 30 low bits: the reader takes differences), for mini-9pi's
 * /dev/sysstat (the author, 2026-10-12: "so we can see the 4 cores
 * activity, whether they are idle or not"). The board's clock is read
 * before the wait and as soon as it ends, so a core that then waits
 * for the kernel's lock is not idle. A core may wait for seconds (one
 * with no tick of its own): a wait that goes on is counted up to now
 * (idling; the clock's value taken out at the wait's start, added
 * back at its end). All of it changes with the lock held. */
void wait_for_interrupt(void);
value timer_now(value unit);
static unsigned idle_us[NCORE];
static int idling[NCORE];

void idle_begin(void) { int c = core(); idle_us[c] -= Long_val(timer_now(Val_unit)); idling[c] = 1; }
unsigned idle_wait(void) { wait_for_interrupt(); return Long_val(timer_now(Val_unit)); }
void idle_end(unsigned t) { int c = core(); idle_us[c] += t; idling[c] = 0; }

value core_idle(value vc)
{
  int c = Long_val(vc) % NCORE;
  unsigned v = idle_us[c];
  if (idling[c]) v += Long_val(timer_now(Val_unit));
  return Val_long(v & 0x3fffffff);
}

/* What each core runs (Machine.doing: the process, its program, a
 * system call's name or what entered the kernel), for the watchdog's
 * words below; copied (the collector moves an OCaml string), and cut
 * short: a core's line of the screen */
static struct { int pid; char prog[16]; char what[16]; } doing_[NCORE];

static void copy_(char *d, value s, int n)
{
  int i, len = string_length(s);
  for (i = 0; i < n - 1 && i < len; i++) d[i] = String_val(s)[i];
  d[i] = 0;
}

value doing(value pid, value prog, value what)
{
  int c = core();
  doing_[c].pid = Int_val(pid);
  copy_(doing_[c].prog, prog, sizeof doing_[c].prog);
  copy_(doing_[c].what, what, sizeof doing_[c].what);
  return Val_unit;
}

/* numbers for the last words, which take no printf (machine.c's) */
void lastwords(const char *s);
static void lw_dec(unsigned v)
{
  char b[12]; int i = 11;
  b[i] = 0;
  do { b[--i] = '0' + v % 10; v /= 10; } while (v);
  lastwords(b + i);
}
#ifdef CORES
/* the kernel's lock (the board's: ldrex and strex, klock_try one try);
 * held by the first core from its start */
int klock_try(void);
void klock_give(void);
void wait_for_interrupt(void);
/* the board's: a core's own timer and the cores' mailboxes */
void core_timer(int ticks);
int core_timer_fired(void);
void core_mail(int c);
void core_mail_clear(void);

/* the other cores run processes (cores_run), and which wait for one:
 * 1 waiting, 2 told to look (cores_wake) */
static volatile int cores_running;
static int waiting[NCORE];

/* The watchdog (the author, 2026-10-21, the Pi 2's screen frozen, no
 * cursor: "we should find a way to display some kernel panic info").
 * A core stuck in the kernel, or two waiting for each other, keeps the
 * kernel's lock, and every other core then waits for it, the first
 * one too at its clock's interrupt (its cursor no longer moves). A core
 * that has waited WATCHDOG_US says so once, in last words (machine.c):
 * which core holds the lock, for how long, and what each core was
 * doing (Machine.doing); then it waits on, the words staying on the
 * screen. The times are the board's clock's, the 30 bits of timer_now
 * (17 minutes, and round). The kernel never holds the lock that long
 * when it works: a program's start from the card, the longest, is a
 * second or two. */
#define WATCHDOG_US 10000000
static volatile int klock_holder;               /* -1: nobody; the first core from its start */
static volatile unsigned klock_since;
static volatile int watchdog_said;

static unsigned now_us(void) { return Long_val(timer_now(Val_unit)); }
static unsigned since_us(unsigned t) { return (now_us() - t) & 0x3fffffff; }

static void watchdog(int me)
{
  int c, h = klock_holder;
  watchdog_said = 1;
  lastwords("watchdog: core "); lw_dec(me); lastwords(" waited 10 s for the kernel's lock, held by core ");
  if (h < 0) lastwords("none"); else lw_dec(h);
  lastwords(" for "); lw_dec(since_us(klock_since) / 1000000); lastwords(" s\n");
  for (c = 0; c < NCORE; c++) {
    lastwords("  core "); lw_dec(c);
    if (doing_[c].prog[0] == 0) lastwords(": nothing yet");
    else { lastwords(": pid "); lw_dec(doing_[c].pid); lastwords(" "); lastwords(doing_[c].prog); lastwords(", "); lastwords(doing_[c].what); }
    lastwords(waiting[c] ? ", idle\n" : "\n");
  }
}

/* old: klock_take the board's, its loop there */
void klock_take(void)
{
  unsigned t0 = now_us();
  while (!klock_try())
    if (!watchdog_said && since_us(t0) > WATCHDOG_US) watchdog(core());
  klock_holder = core();
  klock_since = now_us();
}

void kernel_enter(void) { klock_take(); restore_view(&contexts[current]); }
void kernel_leave(void) { save_view(&contexts[current]); klock_holder = -1; klock_give(); }

/* a process is about to run: another core's own timer, for its slice
 * (the first core has the board's, the clock's) */
void core_slice(void) { if (core() != 0) core_timer(1); }

/* nothing to run: the lock given back while the core waits for an
 * interrupt (masked: wfi returns when one is pending). The first
 * core's are the devices' and the clock's; another's is its mailbox,
 * written by a core that made a process ready, or its own timer, a
 * second (set again at each wait: a timer left pending would end each
 * wait at once). That second is the watchdog's: the core then takes
 * the lock, and a core stuck with it is seen (klock_take), the first
 * one too, whose interrupts are then masked.
 * old: core_timer(0), the timer off: a core stuck with the lock and the
 * others idle, nobody saw it */
value wait_interrupt(value unit)
{
  int c = core();
  unsigned t;
  (void)unit;
  if (c != 0) core_timer(100);
  waiting[c] = 1;
  idle_begin();
  kernel_leave();
  t = idle_wait();
  kernel_enter();
  idle_end(t);
  /* (cleared with the lock held and no longer waiting: nobody writes
   * it again before the next wait) */
  waiting[c] = 0;
  if (cores_running) core_mail_clear();
  return Val_unit;
}

/* a process was made ready: one core that waits is told. (The first
 * too: its wait ends at any of its interrupts, the mailbox's is one) */
value cores_wake(value unit)
{
  int c, me = core();
  (void)unit;
  if (cores_running)
    for (c = 0; c < NCORE; c++)
      if (c != me && waiting[c] == 1) { waiting[c] = 2; core_mail(c); break; }
  return Val_unit;
}

/* another core's tick, in its interrupt: did its timer fire (armed
 * again then) */
value core_tick(value unit)
{
  int fired;
  (void)unit;
  core_mail_clear();
  fired = core_timer_fired();
  if (fired) core_timer(1);
  return Val_bool(fired);
}

/* the other cores, started and waiting (the board's cores_start, which
 * said [n] cores), go to their scheduler: OCaml's "scheduler", entered
 * by core_run on the stack each started on. From here on a process
 * runs on whichever core takes it from the queue. */
value cores_run(value n)
{
  int c;
#ifndef MINI_ML
  scan_roots_hook = scan_stacks;
#endif
  started[NPROC] = 1;
  cores_running = 1;
  for (c = 1; c < Int_val(n); c++) core_mail(c);
  return Val_unit;
}

/* a core other than the first, started: it waits to be told
 * (cores_run), then takes the lock and is a scheduler; never returns */
void core_run(void)
{
  int c = core();
  while (!cores_running) wait_for_interrupt();
  klock_take();
  core_mail_clear();
  started[NPROC + c] = 1;
  restore_view(&contexts[NPROC + c]);          /* no OCaml frames above */
  callback(*caml_named_value("scheduler"), Val_unit);
  exit(5);
}
/* (asked under an emulator too: kernel.mk's SMP=1, for a test; the
 * recorded sessions are one core's, the order of two processes'
 * lines being no longer one with several) */
/* (or by whoever starts the emulator, with the same kernel: a word
 * put in memory below the image, CORES_WORD at CORES_AT, which
 * QEMU's -device loader,addr=,data=,data-len=4 writes (./mini-pi -q
 * mini-9pi2 does: the author, 2026-10-13, of stats there: "only show
 * one"). Nothing of the kernel's is below its image; a board is not
 * asked, its cores run anyway.
 * old: Val_bool(0) without CORES_TEST) */
#define CORES_AT 0x7000
#define CORES_WORD 0x534d5021                   /* "SMP!" */
value cores_test(value unit)
{
  (void)unit;
#ifdef CORES_TEST
  return Val_bool(1);
#else
  return Val_bool(*(volatile unsigned *)(KERNBASE + CORES_AT) == CORES_WORD);
#endif
}
#else
value cores_test(value unit) { (void)unit; return Val_bool(0); }
value cores_wake(value unit) { (void)unit; return Val_unit; }
value core_tick(value unit) { (void)unit; return Val_bool(0); }
value cores_run(value n) { (void)n; return Val_unit; }
#endif

/*****************************************************************************/
/* The traps */
/*****************************************************************************/

/* a system call: the kernel's OCaml handler, registered by name */
void trap(void)
{
  static value *handler = NULL;
  if (handler == NULL) handler = caml_named_value("trap");
  callback(*handler, Val_unit);
}

/* a user's IRQ (the board's irq entry) */
void irq(void)
{
  static value *handler = NULL;
  if (handler == NULL) handler = caml_named_value("irq");
  callback(*handler, Val_unit);
}

/* a user's fault (the board's abort entries): the kernel's "fault"
 * with the exception class (arm64's ESR_EL1.EC, which the Pi1's board
 * says too) and xv6's %p of the syndrome, the pc and the fault's
 * address, formatted here: the values are a machine word, and Int64
 * is not reliable in ocaml-light for arm32 (bugs/ocaml_light.md) */
void user_fault(int ec, uintptr esr, uintptr elr, uintptr far)
{
  CAMLparam0();
  CAMLlocal2(regs, s);
  static value *handler = NULL;
  uintptr v[3];
  char b[24];
  int k, d;
  v[0] = esr; v[1] = elr; v[2] = far;
  regs = alloc_tuple(3);
  for (k = 0; k < 3; k++) Field(regs, k) = Val_unit;
  for (k = 0; k < 3; k++) {
    /* "0x%016lx" (by hand: the two builds' C libraries print differently) */
    b[0] = '0'; b[1] = 'x'; b[18] = 0;
    for (d = 0; d < 16; d++) b[2 + d] = "0123456789abcdef"[((uvlong)v[k] >> (60 - 4 * d)) & 15];
    s = copy_string(b);
    Store_field(regs, k, s);
  }
  if (handler == NULL) handler = caml_named_value("fault");
  callback2(*handler, Val_int(ec), regs);
  CAMLreturn0;
}

/* claude: the peripherals' registers, by their offset from IO_BASE (the
 * 0x20000000 region where start.s maps it: mini-9pi's EMMC driver). A
 * read gives one 16-bit half of the 32-bit register (loaded whole), a
 * write takes the word's two halves: a word does not fit the Pi1's
 * 31-bit ints. */
value io_get16(value off, value high)
{
  unsigned v = *(volatile unsigned *)(IO_BASE + Long_val(off));
  return Val_int(Bool_val(high) ? v >> 16 : v & 0xffff);
}

value io_set32(value off, value hi, value lo)
{
  *(volatile unsigned *)(IO_BASE + Long_val(off)) = ((unsigned)Long_val(hi) << 16) | ((unsigned)Long_val(lo) & 0xffff);
  return Val_unit;
}

/*****************************************************************************/
/* The images' memory */
/*****************************************************************************/

/* Pixels outside OCaml's heap: principia's 9pi has a pool for them
 * (imagmem, beside mainmem: allocmemimage's), and mini-9pi's images
 * were strings of its heap. Two things asked for another place (the
 * author, 2026-10-13, of two games at 31 frames a second each for one
 * at 50: "I think having the images outside the ML heap makes sense, a
 * bit like we just move the Pages also outside the heap no?"; "this is
 * a bit similar to principia's kernel that have a special allocator
 * for image (imagalloc) separate from the rest"):
 * - the collector neither marks nor moves megabytes of pixels;
 * - a copy of pixels may go on while another core is in the kernel
 *   (imag_out, imag_back: the kernel's lock given back around it):
 *   nothing of OCaml's is read or written by it, and what it reads
 *   and writes does not move. Three quarters of a game's instructions
 *   are such copies, and with one lock two games had each two thirds
 *   of one's speed (plan_multicore.md).
 * A block here is still a string for OCaml, which the kernel's code
 * reads and writes as before (Bytes.get, Bytes.blit): a header before
 * its bytes, as the heap's, and the collectors, ocaml-light's and
 * mini-ml's, pass a pointer that is not in their heap. The arena is
 * the kernel's to give (imag_set: pages of the machine); a block's
 * word before its header is its size, and the free ones are a table of
 * extents, first fit, neighbours joined: images are few and large.
 * No room, or a block past what a header's size says (16 MB with 32
 * bits): the empty string, and the caller takes one of the heap. */
#define IMAG_EXTENTS 512
static uintptr imag_lo, imag_hi, imag_inuse;
static struct { uintptr at, n; } imag_ext[IMAG_EXTENTS];
static int imag_n;
/* (a string of no byte: a header, a word whose last byte says the
 * padding) */
static uintptr imag_none[2];

void imag_set(void *base, uintptr n)
{
  imag_lo = (uintptr)base;
  imag_hi = imag_lo + n;
  imag_ext[0].at = imag_lo;
  imag_ext[0].n = n;
  imag_n = 1;
  imag_none[0] = (1 << 10) | (3 << 8) | String_tag;
  ((unsigned char *)&imag_none[1])[sizeof(uintptr) - 1] = sizeof(uintptr) - 1;
}

int imag_in(value v) { return (uintptr)v >= imag_lo && (uintptr)v < imag_hi; }

value imag_alloc(value vn)
{
  uintptr n = Long_val(vn), words = n / sizeof(uintptr) + 1, total, *p;
  int i;
  total = (words + 2) * sizeof(uintptr);
  total = (total + 15) & ~(uintptr)15;
  if (sizeof(uintptr) == 4 && words >= (1 << 22)) return (value)&imag_none[1];
  for (i = 0; i < imag_n; i++)
    if (imag_ext[i].n >= total) break;
  if (i == imag_n) return (value)&imag_none[1];
  p = (uintptr *)imag_ext[i].at;
  imag_ext[i].at += total;
  imag_ext[i].n -= total;
  if (imag_ext[i].n == 0) imag_ext[i] = imag_ext[--imag_n];
  imag_inuse += total;
  p[0] = total;
  p[1] = (words << 10) | (3 << 8) | String_tag;
  memset(p + 2, 0, words * sizeof(uintptr));
  ((unsigned char *)(p + 2))[words * sizeof(uintptr) - 1] = words * sizeof(uintptr) - 1 - n;
  return (value)(p + 2);
}

/* (one that is not the arena's: the heap's, the collector's to free) */
value imag_free(value v)
{
  uintptr at, n;
  int i, k;
  if (!imag_in(v)) return Val_unit;
  at = (uintptr)v - 2 * sizeof(uintptr);
  n = ((uintptr *)at)[0];
  imag_inuse -= n;
  /* joined to the free extent before it and to the one after */
  for (i = 0; i < imag_n; i++)
    if (imag_ext[i].at + imag_ext[i].n == at) { at = imag_ext[i].at; n += imag_ext[i].n; imag_ext[i] = imag_ext[--imag_n]; break; }
  for (i = 0; i < imag_n; i++)
    if (at + n == imag_ext[i].at) { n += imag_ext[i].n; imag_ext[i] = imag_ext[--imag_n]; break; }
  k = imag_n;
  /* (the table full: the smallest extent is lost, or this one) */
  if (k == IMAG_EXTENTS) {
    for (k = 0, i = 1; i < imag_n; i++) if (imag_ext[i].n < imag_ext[k].n) k = i;
    if (imag_ext[k].n >= n) return Val_unit;
  } else imag_n++;
  imag_ext[k].at = at;
  imag_ext[k].n = n;
  return Val_unit;
}

value imag_stats(value unit) { (void)unit; return Val_long(imag_inuse); }
value imag_size(value unit) { (void)unit; return Val_long(imag_hi - imag_lo); }

/* The kernel's lock given back around a copy of pixels, when the cores
 * run processes, and taken again: the caller is an external of
 * OCaml's that is not "noalloc" (the runtime's view of the stack is
 * the caller's, and travels with the lock: kernel_leave), and touches
 * nothing of the heap in between. */
void imag_out(void)
{
#ifdef CORES
  if (cores_running) kernel_leave();
#endif
}
void imag_back(void)
{
#ifdef CORES
  if (cores_running) kernel_enter();
#endif
}
/* (worth the lock's two exchanges: some pages of pixels) */
#define IMAG_WORTH 16384
/* which copies give the lock back: 1 a copy, 2 a fill's rows, 4 a
 * flush (a switch: 0 is every copy with the lock held, as before) */
#ifndef IMAG_UNLOCK
#define IMAG_UNLOCK 7
#endif
int imag_unlock = IMAG_UNLOCK;

/* What a copy without the lock must not meet (principia's draw device
 * has one lock for all of it, drawlock; here the copies go on side by
 * side, and three things wait for them):
 * - the cursor, drawn by the clock into the screen's pixels: a fill of
 *   the screen was copying its first row down while the clock, on
 *   another core, drew the cursor in that row, and the cursor's
 *   pixels went down the screen with it (a black strip, the first
 *   run of this). The rows of the screen being written are said
 *   (imag_w, a core's own; imag_covers), and the clock leaves them;
 * - an image freed, a window made, moved, restacked or deleted: the
 *   pixels a copy is at are then another's. Such an operation first
 *   waits until no copy is under way (imag_quiet), and none starts
 *   meanwhile (imag_hold: a copy is then done with the lock held).
 * Two programs that draw in the same image at once mix their pixels,
 * as two that write one file. */
static int imag_busy, imag_hold;
static value imag_scr;
static long imag_w[NCORE][2];

value imag_screen(value b) { imag_scr = b; return Val_unit; }
/* (the switch, set while the kernel runs: mini-9pi's "draw N" written to /dev/swap) */
value imag_switch(value n) { imag_unlock = Long_val(n); return Val_unit; }

/* a copy that writes [lo, hi) of dst (hi 0: writes no image) starts:
 * is it to go on without the lock (then imag_end) */
int imag_begin(value dst, long lo, long hi)
{
  if (imag_hold) return 0;
  imag_busy++;
  if (hi > lo && dst == imag_scr) { imag_w[core()][0] = lo; imag_w[core()][1] = hi; }
  imag_out();
  return 1;
}
void imag_end(void)
{
  imag_back();
  imag_busy--;
  imag_w[core()][0] = imag_w[core()][1] = 0;
}

value imag_quiet(value unit)
{
  (void)unit;
  imag_hold++;
  while (imag_busy > 0) { imag_out(); imag_back(); }
  imag_hold--;
  return Val_unit;
}

/* are bytes [lo, hi) of the screen's image being written by a copy */
value imag_covers(value lo, value hi)
{
  int c;
  for (c = 0; c < NCORE; c++)
    if (imag_w[c][1] > Long_val(lo) && imag_w[c][0] < Long_val(hi)) return Val_bool(1);
  return Val_bool(0);
}

/* Rows copied from an image to another (Memdraw's copy):
 * a = [| da; dbw; sa; sbw; n; dy; up |], n bytes a row, dy rows, the
 * last first when up (the two overlap). */
value imag_copy(value dst, value src, value a)
{
  unsigned char *d = (unsigned char *)String_val(dst) + Long_val(Field(a, 0)), *s = (unsigned char *)String_val(src) + Long_val(Field(a, 2));
  long dbw = Long_val(Field(a, 1)), sbw = Long_val(Field(a, 3)), n = Long_val(Field(a, 4)), dy = Long_val(Field(a, 5)), j;
  int up = Long_val(Field(a, 6)) != 0;
  int out = (imag_unlock & 1) && imag_in(dst) && imag_in(src) && n * dy >= IMAG_WORTH;
  if (out) out = imag_begin(dst, Long_val(Field(a, 0)), Long_val(Field(a, 0)) + (dy - 1) * dbw + n);
  for (j = 0; j < dy; j++) {
    long k = up ? dy - 1 - j : j;
    memmove(d + k * dbw, s + k * sbw, n);
  }
  if (out) imag_end();
  return Val_unit;
}

/* An image's row repeated below it (Memdraw's fill, its first row
 * written): [len] bytes at [a0], to the dy - 1 rows after, bw apart. */
value imag_rows(value ds, value a0, value bw, value len, value dy)
{
  unsigned char *p = (unsigned char *)String_val(ds) + Long_val(a0);
  long st = Long_val(bw), n = Long_val(len), rows = Long_val(dy), j;
  int out = (imag_unlock & 2) && imag_in(ds) && n * rows >= IMAG_WORTH;
  if (out) out = imag_begin(ds, Long_val(a0), Long_val(a0) + (rows - 1) * st + n);
  for (j = 1; j < rows; j++) memcpy(p + j * st, p, n);
  if (out) imag_end();
  return Val_unit;
}

/* An image drawn k times larger (Memdraw's scale, the draw device's
 * 'z': docs/plans/done/plan_playground_framebuffer.md, F5): each pixel of
 * src k by k in dst, no blending. a = [| da; dbw; sa; sbw; bpp; k; px;
 * py; w; h |]: dst's w by h pixels from da, the first of them px
 * columns and py rows into its source pixel's k by k (a clipped
 * start), that pixel at sa. A row is made from its source row the
 * first time, the k - 1 after it copies of it. */
value imag_scale(value dst, value src, value a)
{
  unsigned char *d = (unsigned char *)String_val(dst) + Long_val(Field(a, 0));
  unsigned char *s = (unsigned char *)String_val(src) + Long_val(Field(a, 2));
  long dbw = Long_val(Field(a, 1)), sbw = Long_val(Field(a, 3)), bpp = Long_val(Field(a, 4));
  long k = Long_val(Field(a, 5)), px = Long_val(Field(a, 6)), py = Long_val(Field(a, 7));
  long w = Long_val(Field(a, 8)), h = Long_val(Field(a, 9)), n = w * bpp, i, j, c;
  int out = (imag_unlock & 1) && imag_in(dst) && imag_in(src) && n * h >= IMAG_WORTH;
  int aligned = (((long)d | (long)s | dbw | sbw) & (bpp - 1)) == 0;
  if (out) out = imag_begin(dst, Long_val(Field(a, 0)), Long_val(Field(a, 0)) + (h - 1) * dbw + n);
  /* (py: the row in the source pixel's k; c: the columns left of it;
   * counted, not divided: the Pi 1 has no divide instruction) */
  for (j = 0; j < h; j++) {
    unsigned char *p = d + j * dbw, *q = s;
    if (j > 0 && py != 0) memcpy(p, p - dbw, n);
    else if (bpp == 2 && aligned) {
      unsigned short *p2 = (unsigned short *)p, *q2 = (unsigned short *)q;
      for (i = 0, c = k - px; i < w; i++) {
        p2[i] = *q2;
        if (--c == 0) { c = k; q2++; }
      }
    } else if (bpp == 4 && aligned) {
      unsigned int *p4 = (unsigned int *)p, *q4 = (unsigned int *)q;
      for (i = 0, c = k - px; i < w; i++) {
        p4[i] = *q4;
        if (--c == 0) { c = k; q4++; }
      }
    } else
      for (i = 0, c = k - px; i < w; i++) {
        memcpy(p + i * bpp, q, bpp);
        if (--c == 0) { c = k; q += bpp; }
      }
    if (++py == k) { py = 0; s += sbw; }
  }
  if (out) imag_end();
  return Val_unit;
}

/* A string's rows written: [row]'s bytes at [a] in [s], then every
 * [stride] bytes, [n] times: memset's kin, for mini-9pi's Memdraw, whose
 * narrow fills (a game's wall is columns of two or three pixels, two
 * hundred rows each, two hundred of them a frame) were a byte stored
 * at a time by OCaml, 33 instructions a row. Two bytes at a time when
 * they are pairs at even addresses (the screen's 16 bits a pixel). The
 * caller has checked that they are all inside [s]. */
value mem_rows(value s, value a, value stride, value n, value row)
{
  unsigned char *p = (unsigned char *)String_val(s) + Long_val(a), *q = (unsigned char *)String_val(row);
  long len = string_length(row), st = Long_val(stride), i, k;
  if (((len | st | (long)p | (long)q) & 1) == 0) {
    unsigned short *q2 = (unsigned short *)q;
    len >>= 1;
    if (len <= 4) {
      /* (one to four pixels, the column's usual: read once, a store each) */
      unsigned short v0 = q2[0], v1 = len > 1 ? q2[1] : 0, v2 = len > 2 ? q2[2] : 0, v3 = len > 3 ? q2[3] : 0;
      for (i = Long_val(n); i > 0; i--) {
        unsigned short *p2 = (unsigned short *)p;
        p2[0] = v0;
        if (len > 1) { p2[1] = v1; if (len > 2) { p2[2] = v2; if (len > 3) p2[3] = v3; } }
        p += st;
      }
    } else
    for (i = Long_val(n); i > 0; i--) {
      unsigned short *p2 = (unsigned short *)p;
      for (k = 0; k < len; k++) p2[k] = q2[k];
      p += st;
    }
  } else
    for (i = Long_val(n); i > 0; i--) {
      for (k = 0; k < len; k++) p[k] = q[k];
      p += st;
    }
  return Val_unit;
}

/* claude: a device's data port read [n] bytes' worth (n/4 32-bit loads,
 * little-endian), or written with a string's words (the EMMC's DATA) */
value io_read_fifo(value off, value n)
{
  CAMLparam2(off, n);
  CAMLlocal1(s);
  volatile unsigned *r = (volatile unsigned *)(IO_BASE + Long_val(off));
  unsigned char *p;
  long i, len = Long_val(n) & ~3L;
  s = alloc_string(len);
  p = (unsigned char *)String_val(s);
  for (i = 0; i < len; i += 4) {
    unsigned v = *r;
    p[i] = v; p[i + 1] = v >> 8; p[i + 2] = v >> 16; p[i + 3] = v >> 24;
  }
  CAMLreturn(s);
}

value io_write_fifo(value off, value s)
{
  volatile unsigned *r = (volatile unsigned *)(IO_BASE + Long_val(off));
  unsigned char *p = (unsigned char *)String_val(s);
  long i, len = string_length(s) & ~3L;
  for (i = 0; i < len; i += 4)
    *r = p[i] | (p[i + 1] << 8) | (p[i + 2] << 16) | ((unsigned)p[i + 3] << 24);
  return Val_unit;
}

/* claude: the running process's trap frame as bytes (TF_WORDS words,
 * little-endian), read or written whole: its registers' 32 bits (a
 * negative register, the PSR's N flag) survive, which the Pi1's 31-bit
 * ints do not (mini-9pi's notes save and restore them) */
value tf_bytes(value unit)
{
  CAMLparam1(unit);
  CAMLlocal1(s);
  s = alloc_string(TF_WORDS * sizeof(uintptr));
  memmove(String_val(s), (void *)cur_tf, TF_WORDS * sizeof(uintptr));
  CAMLreturn(s);
}

value tf_set_bytes(value s)
{
  memmove((void *)cur_tf, String_val(s), TF_WORDS * sizeof(uintptr));
  return Val_unit;
}
