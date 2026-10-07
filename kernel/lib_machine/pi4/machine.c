/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* mini-xv6 on the Pi4 (plan_kernel.md): the machine as the OCaml kernel
 * sees it (Machine.ml's externals, the Pi1's names): physical memory
 * by physical address (KERNBASE added here: OCaml never holds a
 * kernel's address), the user's translation table (TTBR0), the PL011,
 * the ARM generic timer (the virtual one, as xv6 arm64-pi4), the
 * GIC-400 in front of both, the file system's image; and the
 * exceptions from EL0 (start.s), as runtime.c's user_fault wants them. */

#include <mlvalues.h>
#include <alloc.h>
#ifdef __GNUC__
#include <string.h>
#endif
#include "board.h"

/* the system's registers and instructions, which C cannot say: the
 * board's assembly (start.s; l.s for mini-asm) */
void set_ttbr0(uintptr table);
uintptr timer_frequency(void);
uintptr timer_count(void);
void timer_set(uintptr ticks);
uintptr timer_control(void);
void wait_for_interrupt(void);
uintptr fault_address(void);
uintptr empty_table(void);       /* the table of no process: its physical address */

void exit(int status);
extern uintptr *cur_tf;
void user_fault(int ec, uintptr esr, uintptr elr, uintptr far);
void irq(void);

#define P2V(pa) ((volatile unsigned char *)((uintptr)(pa) + KERNBASE))
#define REG(pa) (*(volatile unsigned *)P2V(pa))
#define MAILBOX 0xFE00B880UL

/*****************************************************************************/
/* The primitives */
/*****************************************************************************/

/* physical memory: bytes, halves, words, doublewords (OCaml's ints have
 * 63 bits: a doubleword's top bit lost, none of the kernel's page table
 * entries has it) */
value phys_get8(value pa) { return Val_long(*P2V(Long_val(pa))); }
value phys_set8(value pa, value v) { *P2V(Long_val(pa)) = Long_val(v); return Val_unit; }
value phys_get16(value pa) { return Val_long(*(volatile unsigned short *)P2V(Long_val(pa))); }
value phys_set16(value pa, value v) { *(volatile unsigned short *)P2V(Long_val(pa)) = Long_val(v); return Val_unit; }
value phys_get32(value pa) { return Val_long(*(volatile unsigned *)P2V(Long_val(pa))); }
value phys_set32(value pa, value v) { *(volatile unsigned *)P2V(Long_val(pa)) = Long_val(v); return Val_unit; }
value phys_get64(value pa) { return Val_long(*(volatile uintptr *)P2V(Long_val(pa))); }
value phys_set64(value pa, value v) { *(volatile uintptr *)P2V(Long_val(pa)) = Long_val(v); return Val_unit; }
value phys_zero(value pa, value n)
{
  volatile uintptr *p = (volatile uintptr *)P2V(Long_val(pa));
  long i;
  for (i = 0; i < Long_val(n) / 8; i++) p[i] = 0;
  return Val_unit;
}

/* bytes between OCaml and physical memory: a page copied, a string
 * written, one read */
value phys_copy(value dst, value src, value n)
{
  memmove((void *)P2V(Long_val(dst)), (void *)P2V(Long_val(src)), Long_val(n));
  return Val_unit;
}
value phys_write(value pa, value s)
{
  memmove((void *)P2V(Long_val(pa)), String_val(s), string_length(s));
  return Val_unit;
}
value phys_write_sub(value pa, value s, value off, value n)
{
  memmove((void *)P2V(Long_val(pa)), String_val(s) + Long_val(off), Long_val(n));
  return Val_unit;
}
value phys_read(value pa, value n)
{
  value s = alloc_string(Long_val(n));
  memmove(String_val(s), (void *)P2V(Long_val(pa)), Long_val(n));
  return s;
}

/* the user's translation table: TTBR0 at [pa] (0: the empty one), the
 * TLB emptied, the instruction cache too (exec wrote the program
 * through the data side: on the real Pi4 the data cache would need a
 * clean to the point of unification first; the emulators have none) */
value mmu_switch(value pa)
{
  uintptr t = Long_val(pa) ? (uintptr)Long_val(pa) : empty_table();
  set_ttbr0(t);
  return Val_unit;
}

/* the file system's image (the board's assembly): its physical address
 * and size */
extern char fs_image[];
extern uintptr fs_image_size;
value fs_base(value unit) { (void)unit; return Val_long((uintptr)fs_image - KERNBASE); }
value fs_size(value unit) { (void)unit; return Val_long(fs_image_size); }

/*****************************************************************************/
/* The PL011, the GIC-400 */
/*****************************************************************************/

#define UART 0xFE201000UL
#define GICD 0xFF841000UL                /* the distributor */
#define GICC 0xFF842000UL                /* the CPU interface */
#define UART_IRQ 153                     /* an SPI */
#define TIMER_IRQ 27                     /* the virtual timer's PPI */

value uart_putc(value c)
{
  while (REG(UART + 0x18) & 0x20)        /* FR: the transmit FIFO full */
    ;
  REG(UART) = Long_val(c) & 0xff;
  return Val_unit;
}

value uart_getc(value unit) { (void)unit; return Val_long((REG(UART + 0x18) & 0x10) ? -1 : (long)(REG(UART) & 0xff)); }

/* an interrupt to CPU 0 at the highest priority, enabled */
static void gic_enable(int irq)
{
  *(volatile unsigned char *)P2V(GICD + 0x400 + irq) = 0;       /* IPRIORITYR */
  if (irq >= 32) *(volatile unsigned char *)P2V(GICD + 0x800 + irq) = 1;   /* ITARGETSR */
  REG(GICD + 0x100 + 4 * (irq / 32)) = 1u << (irq % 32);         /* ISENABLER */
}

value uart_rx_enable(value unit)
{
  (void)unit;
  REG(UART + 0x38) = 1 << 4;             /* IMSC: RXIM */
  gic_enable(UART_IRQ);
  return Val_unit;
}

value machine_halt(value unit) { (void)unit; exit(0); return Val_unit; }

/* the board's start, before OCaml's (start.s): the PL011 on (nothing
 * else on the Pi4 turns it on, and QEMU drops what a disabled one is
 * sent), the GIC's distributor and CPU interface on, every priority
 * let through */
void board_init(void)
{
  REG(UART + 0x30) = 0x301;              /* CR: UARTEN, TXE, RXE */
  REG(GICD) = 1;                         /* GICD_CTLR */
  REG(GICC + 0x04) = 0xff;               /* GICC_PMR */
  REG(GICC) = 1;                         /* GICC_CTLR */
}

/*****************************************************************************/
/* The framebuffer (the mailbox's channel 1, as xv6 arm-pi1's initframebuf) */
/*****************************************************************************/

/* the request: width, height, virtual width and height, pitch, depth,
 * offsets x and y, the buffer and its size (the last three answered) */
/* (its address a multiple of 16: the first one inside a longer array) */
static volatile unsigned fbinfo_[14];
#define fbinfo ((volatile unsigned *)(((uintptr)fbinfo_ + 15) & ~(uintptr)15))
static unsigned fb_pitch_;

/* a framebuffer of [w] x [h] pixels of [depth] bits: its physical
 * address, or 0. The request's address is the VideoCore's (BUS_ALIAS);
 * the answer is one too on the board (its alias masked off), a physical
 * one under QEMU. (On the real board the data cache would need a clean
 * around the exchange; the emulators have none.) */
value fb_init(value w, value h, value depth)
{
  uintptr a = (uintptr)fbinfo - KERNBASE;
  int k;
  fbinfo[0] = Long_val(w); fbinfo[1] = Long_val(h); fbinfo[2] = Long_val(w); fbinfo[3] = Long_val(h);
  fbinfo[5] = Long_val(depth);
  for (k = 4; k < 10; k++) if (k != 5) fbinfo[k] = 0;
  while (REG(MAILBOX + 0x18) & 0x80000000)        /* FULL */
    ;
  REG(MAILBOX + 0x20) = (unsigned)((a + BUS_ALIAS) & 0xfffffff0) | 1;
  for (;;) {
    unsigned v;
    while (REG(MAILBOX + 0x18) & 0x40000000)      /* EMPTY */
      ;
    v = REG(MAILBOX);
    if ((v & 0xf) == 1) break;
  }
  fb_pitch_ = fbinfo[4];
  return Val_long(fbinfo[8] & 0x3fffffff);
}

value fb_pitch(value unit) { (void)unit; return Val_long(fb_pitch_); }

/* the font (start.s): its physical address */
extern char font_image[];
value font_base(value unit) { (void)unit; return Val_long((uintptr)font_image - KERNBASE); }

/*****************************************************************************/
/* The timer */
/*****************************************************************************/

/* the next tick in [us] microseconds: the virtual timer's value, from
 * its frequency; its interrupt on */
value timer_arm(value us)
{
  timer_set(timer_frequency() / 1000000 * Long_val(us));
  gic_enable(TIMER_IRQ);
  return Val_unit;
}

value timer_pending(value unit)
{
  (void)unit;
  return Val_bool((timer_control() & 5) == 5);         /* enabled, ISTATUS */
}

/* wait for an interrupt, IRQs masked: wfi returns when one is pending */
value wait_interrupt(value unit) { (void)unit; wait_for_interrupt(); return Val_unit; }

/*****************************************************************************/
/* The exceptions from EL0 (start.s) */
/*****************************************************************************/

/* an IRQ: acknowledged and ended at the GIC first (the devices'
 * interrupts are levels: they stay until OCaml handles them, and the
 * GIC must not keep this one active while the process gives up the
 * CPU, the scheduler waiting for the next), then the kernel's "irq" */
void pi4_irq(void)
{
  unsigned iar = REG(GICC + 0x0c);       /* GICC_IAR */
  if ((iar & 0x3ff) != 1023) REG(GICC + 0x10) = iar;   /* GICC_EOIR */
  irq();
}

/* a synchronous exception other than a system call: the process's
 * fault, with ESR_EL1's class and syndrome, the pc, FAR_EL1 */
void user_abort64(uintptr esr)
{
  user_fault((int)(esr >> 26) & 0x3f, esr, cur_tf[32], fault_address());
}

/* a kernel's exception: the machine stops, saying which and where */
static void puts_(const char *s) { while (*s) uart_putc(Val_long(*s++)); }

static void puthex(uintptr v)
{
  char hex[17];
  int i;
  for (i = 0; i < 16; i++) hex[i] = "0123456789abcdef"[(v >> (60 - 4 * i)) & 15];
  hex[16] = 0;
  puts_(hex);
}

void kfault64(uintptr esr, uintptr elr, uintptr far)
{
  puts_("mini-xv6: in the kernel, esr ");
  puthex(esr);
  puts_(", elr ");
  puthex(elr);
  puts_(", far ");
  puthex(far);
  puts_("\n");
  exit(3);
}

/* a delay of [us] microseconds: the generic timer's virtual count */
void delay_us(unsigned us)
{
  uintptr f = timer_frequency(), t0 = timer_count();
  while ((timer_count() - t0) * 1000000 / f < us)
    ;
}
