/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* mini-xv6 on the Pi1 (ARMv6, arm32): what runtime.c asks of the board.
 *
 * The trap frame (start.s saves it): r0-r12, sp (13), lr (14), the pc
 * (15), the CPSR (16). A context (start.s's swtch): r4-r11, sp, lr. */

/* the C's words, by Plan 9's names: the kernel's C is for two
 * compilers, gcc and mini-cc (plan_kernel_mini_ml.md, decision 5), and
 * a long is 32 bits for 7c on arm64. mini-cc has them from <u.h>. */
#ifdef __GNUC__
typedef unsigned long uintptr;
typedef unsigned long long uvlong;
typedef unsigned int uint;
typedef unsigned char uchar;
#endif

#define TF_WORDS 34              /* r0-r15, the PSR; the FPSCR, d0-d7 (start.s's save_user) */
#define TF_PSR 16
#define TF_USER_PSR 0x10        /* USR, IRQs and FIQs on (no FIQ is ever enabled) */

/* the kernel's addresses: the RAM seen from KERNBASE (start.s) */
#define KERNBASE 0x80000000UL

#define CONTEXT_REGS 10
#define CONTEXT_SP 8
#define CONTEXT_LR 9

/* libc.c's: the PL011 (the devices at 0xFE000000: start.s), the OCaml
 * heap's end (KERNBASE + 96MB: the pages above are the processes'.
 * old: 256MB, half of the board for the kernel, a number never
 * measured; the kernel has taken 16 MB at its prompt (/dev/swap's
 * "kernel malloc"), its images and what it reads being the rest: the
 * author, 2026-10-10: "I would expect the kernel to use 10%, max 20%
 * and the rest for user programs (well images are stored kernel side,
 * so maybe 15% max 25%)") */
#define UART_BASE 0xFE201000UL
#define HEAP_LIMIT 0x86000000UL

/* usb.c's: the peripherals (IO_PHYS) where start.s maps them; the
 * VideoCore's address of the RAM (a DMA's) */
#define IO_BASE 0xFE000000UL
/* (the Pi 2's, a BCM2836 or 2837: the same devices from 0x3F000000,
 * and the RAM's other address for a device 0xC0000000) */
/* (and where the RAM ends at most, and its second view, not cached:
 * start.s) */
#ifdef PI2
#define IO_PHYS 0x3F000000UL
#define BUS_ALIAS 0xC0000000UL
#define RAM_MAX 0x3F000000UL
#define UNCACHED_BASE 0x40000000UL
/* the cores' controller (the BCM2836's, at 0x40000000), where start.s
 * maps it */
#define LOCAL_BASE 0xFF000000UL
/* several cores (docs/plans/plan_multicore.md): the kernel by gcc
 * only, start.s's; ix's own assembler has no ldrex yet, and l2.s
 * stops the other cores. (mini-cc has #ifdef and no #if) */
#ifdef __GNUC__
#define CORES 4
#endif
#else
#define IO_PHYS 0x20000000UL
#define BUS_ALIAS 0x40000000UL
#define RAM_MAX 0x20000000UL
#define UNCACHED_BASE 0xA0000000UL
#endif

/* machine.c's, for usb.c: memory a device reads and writes by itself is
 * never cached; the writes to it in memory before the device is told */
void uncached_add(unsigned long pa, unsigned long n);
void cache_drain(void);
/* usb.c's: the USB controller powered, where the firmware is to be asked */
void usb_power(void);
