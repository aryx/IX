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

#ifdef CORES
/* the kernel's lock (the board's: ldrex and strex); held by the first
 * core from its start */
void klock_take(void);
void klock_give(void);
void wait_for_interrupt(void);
/* the board's: a core's own timer and the cores' mailboxes */
void core_timer(int on);
int core_timer_fired(void);
void core_mail(int c);
void core_mail_clear(void);

/* the other cores run processes (cores_run), and which wait for one:
 * 1 waiting, 2 told to look (cores_wake) */
static volatile int cores_running;
static int waiting[NCORE];

void kernel_enter(void) { klock_take(); restore_view(&contexts[current]); }
void kernel_leave(void) { save_view(&contexts[current]); klock_give(); }

/* a process is about to run: another core's own timer, for its slice
 * (the first core has the board's, the clock's) */
void core_slice(void) { if (core() != 0) core_timer(1); }

/* nothing to run: the lock given back while the core waits for an
 * interrupt (masked: wfi returns when one is pending). The first
 * core's are the devices' and the clock's; another's is its mailbox,
 * written by a core that made a process ready (its timer is off: a
 * timer left pending would end each wait at once). */
value wait_interrupt(value unit)
{
  int c = core();
  unsigned t;
  (void)unit;
  if (c != 0) core_timer(0);
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
