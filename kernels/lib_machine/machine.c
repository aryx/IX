/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* The machine as the OCaml kernel sees it (Machine.ml's externals): the
 * part every board has, the same C. Not compiled by itself: a board's
 * machine.c (pi1/, pi4/) includes it, after it has said
 *   P2V(pa)        the address the kernel reaches physical memory by
 *   written(pa, n, code)   n bytes written there (code: a program's),
 *                  for a board whose caches must be told
 *   REG(pa)        a device's register, MAILBOX the VideoCore's
 *   VC(array)      where in a static array a request to the VideoCore
 *                  is, VC_PA(p) its physical address
 * (and board.h: UART_BASE, BUS_ALIAS, cache_drain, uncached_add), and
 * before what is its own: the caches, the interrupts' controller, the
 * timer, the faults. */

/*****************************************************************************/
/* Physical memory */
/*****************************************************************************/

/* bytes, halves and words (a word's bit 31 lost on a machine of 32
 * bits: Int32 when it matters; the kernel's page table entries and
 * addresses stay below) */
value phys_get8(value pa) { return Val_long(*P2V(Long_val(pa))); }
value phys_set8(value pa, value v) { *P2V(Long_val(pa)) = Long_val(v); return Val_unit; }
value phys_get16(value pa) { return Val_long(*(volatile unsigned short *)P2V(Long_val(pa))); }
value phys_set16(value pa, value v) { *(volatile unsigned short *)P2V(Long_val(pa)) = Long_val(v); return Val_unit; }
value phys_get32(value pa) { return Val_long(*(volatile unsigned *)P2V(Long_val(pa))); }
value phys_set32(value pa, value v) { *(volatile unsigned *)P2V(Long_val(pa)) = Long_val(v); written(Long_val(pa), 4, 0); return Val_unit; }
value phys_zero(value pa, value n)
{
  volatile uintptr *p = (volatile uintptr *)P2V(Long_val(pa));
  long i;
  /* (the kernel built for a page: libc.c's memset, the emulator's own;
   * old, and the Pi's: the loop of words) */
#ifdef WEB
  memset((void *)p, 0, Long_val(n));
#else
  for (i = 0; i < Long_val(n) / (long)sizeof(uintptr); i++) p[i] = 0;
#endif
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

/* the file system's image and the font (the board's assembly: start.s,
 * the mkfile's images.s): their physical addresses, the image's size */
extern char fs_image[];
extern uintptr fs_image_size;
extern char font_image[];
extern unsigned long kernel_heap_top(void), kernel_heap_limit(void);
value heap_top(value unit) { (void)unit; return Val_long(kernel_heap_top()); }
value heap_limit(value unit) { (void)unit; return Val_long(kernel_heap_limit()); }
/* where the memory given to the ARM ends, if the board's machine.c asks
 * the firmware (0: it does not, and Arch says a number) */
#ifdef BOARD_RAM_TOP
unsigned long board_ram_top(void), board_ram_all(void);
#else
static unsigned long board_ram_top(void) { return 0; }
static unsigned long board_ram_all(void) { return 0; }
#endif
value ram_top(value unit) { (void)unit; return Val_long(board_ram_top()); }
value ram_all(value unit) { (void)unit; return Val_long(board_ram_all()); }
value fs_base(value unit) { (void)unit; return Val_long((uintptr)fs_image - KERNBASE); }
value fs_size(value unit) { (void)unit; return Val_long(fs_image_size); }
value font_base(value unit) { (void)unit; return Val_long((uintptr)font_image - KERNBASE); }

/*****************************************************************************/
/* The console: the PL011 */
/*****************************************************************************/

#define UART ((volatile unsigned *)UART_BASE)    /* DR; 6 FR, 12 CR, 14 IMSC */

value uart_putc(value c)
{
  while (UART[6] & 0x20)                 /* the transmit FIFO full */
    ;
  UART[0] = Long_val(c) & 0xff;
  return Val_unit;
}

/* a character, or -1 */
value uart_getc(value unit) { (void)unit; return Val_long((UART[6] & 0x10) ? -1 : (long)(UART[0] & 0xff)); }

/* for a kernel's fault: the machine says which and where, and stops */
static void puts_(const char *s) { while (*s) uart_putc(Val_long(*s++)); }

static void puthex(uintptr v)
{
  char hex[2 * sizeof(uintptr) + 1];
  int i, n = 2 * sizeof(uintptr);
  for (i = 0; i < n; i++) hex[i] = "0123456789abcdef"[(v >> (4 * (n - 1 - i))) & 15];
  hex[n] = 0;
  puts_(hex);
}

value machine_halt(value unit) { (void)unit; exit(0); return Val_unit; }

/* wait for an interrupt, IRQs masked: wfi returns when one is pending */
value wait_interrupt(value unit) { (void)unit; wait_for_interrupt(); return Val_unit; }

/*****************************************************************************/
/* The framebuffer (the mailbox's channel 1, as xv6 arm-pi1's initframebuf) */
/*****************************************************************************/

/* the request: width, height, virtual width and height, pitch, depth,
 * offsets x and y, the buffer and its size (the last three answered).
 * (Aligned by hand, VC: mini-cc has no attribute.) */
static volatile unsigned fbinfo_[32];
#define fbinfo VC(fbinfo_)
static unsigned fb_pitch_;

/* a framebuffer of [w] x [h] pixels of [depth] bits: its physical
 * address, or 0. The request's address is the VideoCore's (BUS_ALIAS);
 * the answer is one too on the board (its alias masked off), a physical
 * one under QEMU. */
value fb_init(value w, value h, value depth)
{
  uintptr a = VC_PA(fbinfo);
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
