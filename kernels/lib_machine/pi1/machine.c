/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* mini-xv6 on the Pi1 (plan_kernel.md): the machine as the OCaml kernel
 * sees it (Machine.ml's externals), built up in kernels/steps/step1-5/:
 * physical memory by physical address, the user's translation table
 * (TTBR0), the system timer, the PL011, the file system's image; and
 * the aborts from user mode, as runtime.c's user_fault wants them.
 * Physical memory is reached by physical address, which fits an OCaml
 * int: the kernel's own addresses (KERNBASE and up) never reach OCaml. */

#include <mlvalues.h>
#include <alloc.h>
#ifdef __GNUC__
#include <string.h>
#endif
#include "board.h"

/* the system's registers and instructions, which C cannot say: the
 * board's assembly (start.s; l.s for mini-asm) */
void set_ttbr0(unsigned table);         /* the user's table, the TLB emptied */
void wait_for_interrupt(void);
unsigned fault_address(int instruction);   /* FAR, or IFAR */
unsigned fault_status(int instruction);    /* DFSR, or IFSR */
unsigned empty_table(void);             /* the table of no process: its physical address */

#define MAILBOX 0x2000B880UL
#define REG(pa) (*(volatile unsigned *)((unsigned long)(pa) + 0xDE000000UL))   /* the devices at 0xFE000000 */

void exit(int status);
extern unsigned long *cur_tf;
void user_fault(int ec, unsigned long esr, unsigned long elr, unsigned long far);

/*****************************************************************************/
/* The primitives */
/*****************************************************************************/

/* The caches. On the board the processor is some thirty times slower
 * without them (every instruction and every word is read from the
 * memory itself); the emulators have none, and nothing below changes
 * what they do. NOT RUN ON A BOARD YET (2026-10-08): written from the
 * ARM1176's manual, for the first boot on one
 * (docs/plans/plan_playground_speed.md). They are on when the kernel
 * says so (caches_on: mini-9pi's Main); until then, and for a kernel
 * that never does, the lines below do nothing.
 *
 * With the data cache on, what the kernel writes is in the cache for a
 * while and not in the memory, and three readers do not look in the
 * cache:
 * - the processor's own walk of the translation tables: an entry
 *   written (phys_set32) and a new table's zeros (phys_zero) are
 *   written through to the memory (cache_clean_range);
 * - the instructions' cache, which is another one: a page of a
 *   program's code (phys_write, phys_write_sub, phys_copy) is written
 *   through, and its lines taken out of the instructions' cache, which
 *   may hold what the page was before (cache_sync_range);
 * - the devices that read and write memory themselves: the VideoCore
 *   (the framebuffer, the mailbox's request) and the USB controller
 *   (its DMA pages). Their memory is not cached at all: start.s maps
 *   the RAM a second time, at UNCACHED_BASE, without the cache, and
 *   these ranges (uncached_add) are reached there and only there.
 * A process's page seen at two addresses, the kernel's and its own, is
 * no trouble on this processor: the data cache's ways are a page each
 * (16 KB, 4 ways), so the two addresses name the same line. */
void caches_enable(void);
void cache_clean_range(unsigned long from, unsigned long to);
void cache_sync_range(unsigned long from, unsigned long to);

#define UNCACHED_BASE 0xA0000000UL
static unsigned long unc_lo[4], unc_hi[4];
static int unc_n;
void uncached_add(unsigned long pa, unsigned long n)
{
  if (unc_n < 4) { unc_lo[unc_n] = pa; unc_hi[unc_n] = pa + n; unc_n++; }
}
static int uncached(unsigned long pa)
{
  int i;
  for (i = 0; i < unc_n; i++) if (pa >= unc_lo[i] && pa < unc_hi[i]) return 1;
  return 0;
}
static volatile unsigned char *p2v(unsigned long pa)
{
  return (volatile unsigned char *)(pa + (uncached(pa) ? UNCACHED_BASE : KERNBASE));
}
/* old: #define P2V(pa) ((volatile unsigned char *)((unsigned)(pa) + KERNBASE)) */
#define P2V(pa) p2v((unsigned)(pa))
/* what was written at [pa], [n] bytes: through to the memory (clean),
 * and out of the instructions' cache too (sync) */
static void written(unsigned long pa, unsigned long n, int code)
{
  unsigned long va = pa + KERNBASE;
  if (n == 0 || uncached(pa)) return;
  if (code) cache_sync_range(va, va + n); else cache_clean_range(va, va + n);
}

value caches_on(value unit) { (void)unit; caches_enable(); return Val_unit; }

/* physical memory: bytes and words (a word's bit 31 lost: Int32 when it
 * matters; the kernel's page table entries and addresses stay below) */
value phys_get8(value pa) { return Val_int(*P2V(Long_val(pa))); }
value phys_set8(value pa, value v) { *P2V(Long_val(pa)) = Long_val(v); return Val_unit; }
value phys_get32(value pa) { return Val_int(*(volatile unsigned *)P2V(Long_val(pa))); }
value phys_set32(value pa, value v) { *(volatile unsigned *)P2V(Long_val(pa)) = Long_val(v); written(Long_val(pa), 4, 0); return Val_unit; }
value phys_get16(value pa) { return Val_int(*(volatile unsigned short *)P2V(Long_val(pa))); }
value phys_set16(value pa, value v) { *(volatile unsigned short *)P2V(Long_val(pa)) = Long_val(v); return Val_unit; }
value phys_zero(value pa, value n)
{
  volatile unsigned *p = (volatile unsigned *)P2V(Long_val(pa));
  int i;
  for (i = 0; i < Long_val(n) / 4; i++) p[i] = 0;
  written(Long_val(pa), Long_val(n), 0);
  return Val_unit;
}

/* bytes between OCaml and physical memory: a page copied, a string
 * written, one read */
value phys_copy(value dst, value src, value n)
{
  memmove((void *)P2V(Long_val(dst)), (void *)P2V(Long_val(src)), Long_val(n));
  written(Long_val(dst), Long_val(n), 1);
  return Val_unit;
}
value phys_write(value pa, value s)
{
  memmove((void *)P2V(Long_val(pa)), String_val(s), string_length(s));
  written(Long_val(pa), string_length(s), 1);
  return Val_unit;
}
value phys_write_sub(value pa, value s, value off, value n)
{
  memmove((void *)P2V(Long_val(pa)), String_val(s) + Long_val(off), Long_val(n));
  written(Long_val(pa), Long_val(n), 1);
  return Val_unit;
}
value phys_read(value pa, value n)
{
  value s = alloc_string(Long_val(n));
  memmove(String_val(s), (void *)P2V(Long_val(pa)), Long_val(n));
  return s;
}

/* the user's translation table: TTBR0 at [pa] (0: the empty one), the
 * TLB emptied */
value mmu_switch(value pa)
{
  set_ttbr0(Long_val(pa) ? (unsigned)Long_val(pa) : empty_table());
  return Val_unit;
}

/* the file system's image (start.s; the mkfile's images.s): its
 * physical address and size */
extern char fs_image[];
extern unsigned fs_image_size;
value fs_base(value unit) { (void)unit; return Val_int((unsigned)fs_image - KERNBASE); }
value fs_size(value unit) { (void)unit; return Val_int(fs_image_size); }

/* the console: the PL011, at 0xFE201000 now */
value uart_putc(value c)
{
  while (*(volatile unsigned *)0xFE201018 & 0x20)
    ;
  *(volatile unsigned *)0xFE201000 = Int_val(c) & 0xff;
  return Val_unit;
}

/* the PL011's input: a character or -1; its receive interrupt (the
 * controller's IRQ 57, bank 2's bit 25) on */
#define UART ((volatile unsigned *)0xFE201000)
value uart_getc(value unit) { (void)unit; return Val_int((UART[6] & 0x10) ? -1 : (int)(UART[0] & 0xff)); }
value uart_rx_enable(value unit)
{
  (void)unit;
  UART[14] = 1 << 4;                               /* IMSC: RXIM */
  ((volatile unsigned *)0xFE00B200)[5] = 1 << 25;  /* enable IRQs 2: 57 */
  return Val_unit;
}

value machine_halt(value unit) { (void)unit; exit(0); return Val_unit; }

/*****************************************************************************/
/* The framebuffer (the mailbox's channel 1, as xv6 arm-pi1's initframebuf) */
/*****************************************************************************/

/* the request: width, height, virtual width and height, pitch, depth,
 * offsets x and y, the buffer and its size (the last three answered) */
/* (aligned by hand: mini-cc has no attribute; on a cache's line, 32
 * bytes, and alone on its two: the VideoCore reads and writes it, so it
 * is reached where the memory is not cached, and nothing else is in
 * the lines it has.
 * old: static volatile unsigned fbinfo_[14];
 *   #define fbinfo ((volatile unsigned *)(((unsigned long)fbinfo_ + 15) & ~15UL))) */
static volatile unsigned fbinfo_[32];
#define fbinfo ((volatile unsigned *)((((unsigned long)fbinfo_ + 31) & ~31UL) - KERNBASE + UNCACHED_BASE))
static unsigned fb_pitch_;

/* a framebuffer of [w] x [h] pixels of [depth] bits: its physical
 * address, or 0. The request's address is the VideoCore's (BUS_ALIAS);
 * the answer is one too on the board (its alias masked off), a physical
 * one under QEMU. (On the real board the data cache would need a clean
 * around the exchange; the emulators have none.) */
value fb_init(value w, value h, value depth)
{
  unsigned long a = (unsigned long)fbinfo - UNCACHED_BASE;
  int k;
  fbinfo[0] = Long_val(w); fbinfo[1] = Long_val(h); fbinfo[2] = Long_val(w); fbinfo[3] = Long_val(h);
  fbinfo[5] = Long_val(depth);
  for (k = 4; k < 10; k++) if (k != 5) fbinfo[k] = 0;
  while (REG(MAILBOX + 0x18) & 0x80000000)        /* FULL */
    ;
  cache_drain();
  REG(MAILBOX + 0x20) = (unsigned)((a + BUS_ALIAS) & 0xfffffff0) | 1;
  for (;;) {
    unsigned v;
    while (REG(MAILBOX + 0x18) & 0x40000000)      /* EMPTY */
      ;
    v = REG(MAILBOX);
    if ((v & 0xf) == 1) break;
  }
  fb_pitch_ = fbinfo[4];
  /* (the screen's memory is the VideoCore's to read: never cached) */
  if (fbinfo[8] != 0) uncached_add(fbinfo[8] & 0x3fffffff, fbinfo[9] ? fbinfo[9] : fbinfo[4] * Long_val(h));
  return Val_long(fbinfo[8] & 0x3fffffff);
}

value fb_pitch(value unit) { (void)unit; return Val_long(fb_pitch_); }

/* A question to the firmware (the VideoCore, which set the board up and
 * stays there): the mailbox's channel 8, a list of tagged requests in
 * memory, one here: [tag], two words given ([a], [b]), the second word
 * of its answer, or 0 when it does not answer (*ok 0 then). 9pi's
 * vcreq. The request as the framebuffer's: its own cache lines, reached
 * where the memory is not cached (the VideoCore reads and writes it). */
static volatile unsigned vcreq_[24];
#define vcreq ((volatile unsigned *)((((unsigned long)vcreq_ + 31) & ~31UL) - KERNBASE + UNCACHED_BASE))
static unsigned property(unsigned tag, unsigned a, unsigned b, int *ok)
{
  unsigned long pa = (unsigned long)vcreq - UNCACHED_BASE;
  unsigned v;
  int k;
  vcreq[0] = 8 * 4; vcreq[1] = 0;                     /* the size, a request */
  vcreq[2] = tag; vcreq[3] = 8; vcreq[4] = 0;         /* the tag, its room, a request */
  vcreq[5] = a; vcreq[6] = b;
  vcreq[7] = 0;                                       /* the end */
  for (k = 0; k < 1000000 && (REG(MAILBOX + 0x18) & 0x80000000); k++)        /* FULL */
    ;
  cache_drain();
  REG(MAILBOX + 0x20) = (unsigned)((pa + BUS_ALIAS) & 0xfffffff0) | 8;
  for (k = 0; k < 1000000; k++) {
    if (REG(MAILBOX + 0x18) & 0x40000000) continue;   /* EMPTY */
    v = REG(MAILBOX);
    if ((v & 0xf) == 8) break;
  }
  *ok = k < 1000000 && vcreq[1] == 0x80000000 && (vcreq[4] & 0x80000000);
  return *ok ? vcreq[6] : 0;
}

/* A clock's rate in Hz (the tag 0x00030002, get clock rate; 9pi's
 * getclkrate), or 0 when the firmware does not say. [id]: 1 the SD
 * controller's, which is not the same on every board and firmware
 * (QEMU says 50 MHz; 9pi guesses 100 when it is not told). */
value clock_rate(value id)
{
  int ok;
  unsigned hz = property(0x00030002, Long_val(id), 0, &ok);
  return Val_long(ok ? (hz & 0x3fffffff) : 0);
}

/* The USB controller powered (the tag 0x00028001, set power state: the
 * device 3, on, and the answer when it is; 9pi's setpower(PowerUsb,
 * 1)): the firmware may have left it off, and an emulator's is always
 * on. */
void usb_power(void)
{
  int ok;
  property(0x00028001, 3, 1 | 2, &ok);
}

/* the font (start.s): its physical address */
extern char font_image[];
value font_base(value unit) { (void)unit; return Val_long((unsigned long)font_image - KERNBASE); }

/*****************************************************************************/
/* The timer */
/*****************************************************************************/

#define TIMER ((volatile unsigned *)0xFE003000)    /* CS, CLO, CHI, C0-C3 */
#define INTC ((volatile unsigned *)0xFE00B200)     /* basic pending, pending 1 ... */

/* the next tick in [us] microseconds: compare 3's match cleared, the
 * compare set; its IRQ (3) enabled */
value timer_arm(value us)
{
  TIMER[0] = 1 << 3;
  TIMER[6] = TIMER[1] + Long_val(us);
  INTC[4] = 1 << 3;                               /* enable IRQs 1 */
  return Val_unit;
}

value timer_pending(value unit) { (void)unit; return Val_bool((TIMER[0] & (1 << 3)) != 0); }

/* the timer's microseconds (CLO), their 30 low bits: a clock that goes
 * on whatever the kernel does, to count the ticks by (mini-9pi's
 * Main.devices; 18 minutes before it turns round) */
value timer_now(value unit) { (void)unit; return Val_long(TIMER[1] & 0x3fffffff); }

/* wait for an interrupt, IRQs masked: wfi returns when one is pending */
value wait_interrupt(value unit) { (void)unit; wait_for_interrupt(); return Val_unit; }

/* a user's abort (start.s: kind 2 a prefetch abort, 3 a data abort;
 * claude: 1 an undefined instruction):
 * runtime.c's user_fault, as arm64 says it: the exception class of an
 * abort from user mode (0x20 an instruction's, 0x24 a data's), a
 * syndrome (the class, and the FSR: its status), the faulting
 * instruction (the abort's lr less 8 or 4), the fault's address (FAR,
 * IFAR) */
void user_abort(int kind)
{
  unsigned far, fsr;
  int ec = kind == 3 ? 0x24 : 0x20;
  /* claude: the saved pc back on the faulting instruction (the abort's
   * lr 8 or 4 past it), so that a fault the kernel resolves (mini-9pi's
   * demand paging) restarts it */
  cur_tf[15] -= kind == 3 ? 8 : 4;
  if (kind == 1) {
    /* claude: an undefined instruction (arm64's class 0, "unknown"), no
     * address */
    user_fault(0, 0, cur_tf[15], 0);
    return;
  }
  far = fault_address(kind != 3);
  fsr = fault_status(kind != 3);
  /* claude: a data abort's write (the DFSR's bit 11) as arm64's WnR (ISS
   * bit 6) */
  user_fault(ec, ((unsigned long)ec << 26) | (fsr & 0x40f) | (kind == 3 && (fsr & 0x800) ? 0x40 : 0),
             cur_tf[15], far);
}

/* a kernel's fault: the machine stops, saying which and where */
static void puts_(const char *s) { while (*s) uart_putc(Val_int(*s++)); }

static void puthex(unsigned v)
{
  char hex[9];
  int i;
  for (i = 0; i < 8; i++) hex[i] = "0123456789abcdef"[(v >> (28 - 4 * i)) & 15];
  hex[8] = 0;
  puts_(hex);
}

void kfault(int kind, unsigned lr)
{
  static const char *names[] = { "", "undefined instruction", "prefetch abort", "data abort" };
  unsigned far = fault_address(0);
  puts_("mini-xv6: in the kernel, ");
  puts_(names[kind]);
  puts_(", lr ");
  puthex(lr);
  puts_(", far ");
  puthex(far);
  puts_("\n");
  exit(3);
}

/* a delay of [us] microseconds: the system timer's counter (CLO) */
void delay_us(unsigned us)
{
  volatile unsigned *clo = (volatile unsigned *)(IO_BASE + 0x3004);
  unsigned t = *clo;
  while (*clo - t < us)
    ;
}
