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

#include <mlvalues.h>
#include <callback.h>
#include <memory.h>
#include <alloc.h>
#ifndef MINI_ML
#include <roots.h>
#include <stack.h>
#include <string.h>
#endif
#include "board.h"

#define NPROC 64                      /* xv6's param.h */
#define KSTACK 16384

void user_return(void);
void exit(int status);

/* the trap frames; the board's trap entry uses the running process's */
uintptr trapframes[NPROC][TF_WORDS];
uintptr *cur_tf;

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
  struct caml__roots_block *local_roots;
#endif
};

/* the processes' slots, and one more: the scheduler's, on the boot stack */
static struct context contexts[NPROC + 1];
static char kstacks[NPROC][KSTACK];
static int current = NPROC;
static int started[NPROC + 1];

void swtch(struct context *from, struct context *to);

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
  c->local_roots = local_roots;
}

static void restore_view(struct context *c)
{
  caml_bottom_of_stack = c->bottom_of_stack;
  caml_last_return_address = c->last_return_address;
  caml_gc_regs = c->gc_regs;
  caml_exception_pointer = c->exception_pointer;
  local_roots = c->local_roots;
}

/* the collector's hook: the stacks that do not run (a process not yet
 * started has no OCaml frames) */
static void scan_stacks(scanning_action f)
{
  int i;
  for (i = 0; i <= NPROC; i++)
    if (i != current && started[i] && contexts[i].bottom_of_stack != NULL)
      do_local_roots(f, contexts[i].bottom_of_stack, contexts[i].last_return_address,
                     contexts[i].gc_regs, contexts[i].local_roots);
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
  c->exception_pointer = NULL; c->local_roots = NULL;
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
#ifdef MINI_ML
  ml_stack_switch(t < NPROC ? t + 1 : 0);
#else
  static int hooked = 0;
  if (!hooked) { scan_roots_hook = scan_stacks; started[NPROC] = 1; hooked = 1; }
#endif
  save_view(&contexts[from]);
  current = t;
  if (t < NPROC) cur_tf = trapframes[t];
  swtch(&contexts[from], &contexts[t]);
  /* back in [from] */
  restore_view(&contexts[from]);
  return Val_unit;
}

value k_current(value unit) { (void)unit; return Val_int(current); }

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
