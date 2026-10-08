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
/* (the Pi1's: its caches told of what is written; nothing here) */
#define written(pa, n, code)
/* a request to the VideoCore: its address a multiple of 16, the first
 * one inside a longer array */
#define VC(a) ((volatile unsigned *)(((uintptr)(a) + 15) & ~(uintptr)15))
#define VC_PA(p) ((uintptr)(p) - KERNBASE)

/* what every board has: physical memory, the console, the framebuffer */
#include "../machine.c"

/*****************************************************************************/
/* The primitives */
/*****************************************************************************/

/* physical memory's doublewords (OCaml's ints have 63 bits: the top
 * bit lost, none of the kernel's page table entries has it) */
value phys_get64(value pa) { return Val_long(*(volatile uintptr *)P2V(Long_val(pa))); }
value phys_set64(value pa, value v) { *(volatile uintptr *)P2V(Long_val(pa)) = Long_val(v); return Val_unit; }

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
/* the Pi1's (pi1/machine.c: its caches on); here start.s's business */
value caches_on(value unit) { (void)unit; return Val_unit; }
/* (the Pi1's: its speed measured; not here) */
value cpu_mhz(value unit) { (void)unit; return Val_long(0); }
value caches_careful(value on) { (void)on; return Val_unit; }

/*****************************************************************************/
/* The PL011, the GIC-400 */
/*****************************************************************************/

#define GICD 0xFF841000UL                /* the distributor */
#define GICC 0xFF842000UL                /* the CPU interface */
#define UART_IRQ 153                     /* an SPI */
#define TIMER_IRQ 27                     /* the virtual timer's PPI */

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
  UART[14] = 1 << 4;                     /* IMSC: RXIM */
  gic_enable(UART_IRQ);
  return Val_unit;
}

/* the board's start, before OCaml's (start.s): the PL011 on (nothing
 * else on the Pi4 turns it on, and QEMU drops what a disabled one is
 * sent), the GIC's distributor and CPU interface on, every priority
 * let through */
void board_init(void)
{
  UART[12] = 0x301;                      /* CR: UARTEN, TXE, RXE */
  REG(GICD) = 1;                         /* GICD_CTLR */
  REG(GICC + 0x04) = 0xff;               /* GICC_PMR */
  REG(GICC) = 1;                         /* GICC_CTLR */
}

/*****************************************************************************/
/* The firmware */
/*****************************************************************************/

/* (the Pi1's: a clock's rate asked of the firmware; not asked here,
 * the SD controller's said as QEMU has it) */
value clock_rate(value id) { return Val_long(Long_val(id) == 1 ? 50000000 : 0); }
/* (the Pi1's: the USB controller's power asked of the firmware) */
void usb_power(void) { }

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

/* the timer's count in microseconds, their 30 low bits (the Pi1's CLO's) */
value timer_now(value unit)
{
  (void)unit;
  return Val_long((timer_count() / (timer_frequency() / 1000000)) & 0x3fffffff);
}

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
