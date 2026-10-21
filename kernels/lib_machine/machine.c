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
#ifdef WEB
int host_move(void *d, const void *s, unsigned long n);
#endif
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
  /* (the kernel built for a page: by the emulator whatever the length,
   * libc.c's memmove asking it from 16 bytes; mini-9pi's pixels reach
   * the framebuffer here, and the emulator's host shows the rows it
   * was asked to write) */
#ifdef WEB
  if (host_move((void *)P2V(Long_val(pa)), String_val(s) + Long_val(off), Long_val(n))) { written(Long_val(pa), Long_val(n), 1); return Val_unit; }
#endif
  memmove((void *)P2V(Long_val(pa)), String_val(s) + Long_val(off), Long_val(n));
  written(Long_val(pa), Long_val(n), 1);
  return Val_unit;
}
/* The images' memory (runtime.c): the arena, [n] bytes of physical
 * memory at [pa]; and an image's rows written to the framebuffer
 * (mini-9pi's flush), a = [| pa; pitch; off; bw; n; rows |]: n bytes
 * of each row, the image's bw apart from off, the screen's pitch apart
 * from pa. With the kernel's lock given back when the image is the
 * arena's. (old: phys_write_sub, a call a row.) */
void imag_set(void *base, uintptr n);
int imag_in(value v);
int imag_begin(value dst, long lo, long hi);
void imag_end(void);
extern int imag_unlock;
value imag_init(value pa, value n) { imag_set((void *)P2V(Long_val(pa)), Long_val(n)); return Val_unit; }
value imag_flush(value s, value a)
{
  unsigned long pa = Long_val(Field(a, 0));
  long pitch = Long_val(Field(a, 1)), bw = Long_val(Field(a, 3)), n = Long_val(Field(a, 4)), rows = Long_val(Field(a, 5)), y;
  const char *from = String_val(s) + Long_val(Field(a, 2));
  int out = (imag_unlock & 4) && imag_in(s) && n * rows >= 16384;
  if (out) out = imag_begin(s, 0, 0);
  for (y = 0; y < rows; y++) {
#ifdef WEB
    if (host_move((void *)P2V(pa + y * pitch), from + y * bw, n)) { written(pa + y * pitch, n, 1); continue; }
#endif
    memmove((void *)P2V(pa + y * pitch), from + y * bw, n);
    written(pa + y * pitch, n, 1);
  }
  if (out) imag_end();
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
/* the top 16 bits of the RAM's address as a device that reads memory
 * by itself names it (board.h's BUS_ALIAS: the word is past an OCaml
 * int on arm) */
value bus_alias16(value unit) { (void)unit; return Val_long((BUS_ALIAS >> 16) & 0xffff); }
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
/* a web page's keys, mouse and cursor (the kernel built for a page:
 * web/host.s asks the emulator); none on a board */
#ifdef WEB
int host_input(void *buf);
int host_cursor(void *buf);
value web_input(value s) { return Val_long(host_input(String_val(s))); }
value web_cursor(value s) { return Val_long(host_cursor(String_val(s))); }
/* memdraw's general loop by the host (mini-9pi's Memdraw.hosted): the
 * 49 words of d, and in each image's first two where its bytes are
 * and how many */
int host_draw(void *desc);
value web_draw(value d, value dst, value src, value mask)
{
  unsigned *w = (unsigned *)String_val(d);
  w[0] = (unsigned)String_val(dst); w[1] = string_length(dst);
  w[12] = (unsigned)String_val(src); w[13] = string_length(src);
  w[24] = (unsigned)String_val(mask); w[25] = string_length(mask);
  return Val_long(host_draw(w));
}
#else
value web_draw(value d, value dst, value src, value mask) { (void)d; (void)dst; (void)src; (void)mask; return Val_long(-1); }
value web_input(value s) { (void)s; return Val_long(0); }
value web_cursor(value s) { (void)s; return Val_long(0); }
#endif
value uart_getc(value unit) { (void)unit; return Val_long((UART[6] & 0x10) ? -1 : (long)(UART[0] & 0xff)); }

/* for a kernel's fault: the machine says which and where, and stops */
/* (and on the screen: lastwords, below) */
void lastwords_putc(int c);
static void puts_(const char *s) { while (*s) { lastwords_putc(*s); uart_putc(Val_long(*s++)); } cache_drain(); }

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
/* (with several cores: runtime.c's, the kernel's lock given back
 * meanwhile) */
#ifndef CORES
/* (old: wait_for_interrupt() itself; runtime.c's idle_wait counts the wait) */
void idle_begin(void);
unsigned idle_wait(void);
void idle_end(unsigned t);
value wait_interrupt(value unit) { (void)unit; idle_begin(); idle_end(idle_wait()); return Val_unit; }
#endif

/*****************************************************************************/
/* The framebuffer (the mailbox's channel 1, as xv6 arm-pi1's initframebuf) */
/*****************************************************************************/

/* the request: width, height, virtual width and height, pitch, depth,
 * offsets x and y, the buffer and its size (the last three answered).
 * (Aligned by hand, VC: mini-cc has no attribute.) */
static volatile unsigned fbinfo_[32];
#define fbinfo VC(fbinfo_)
static unsigned fb_pitch_;
/* (the framebuffer as lastwords, below, writes it: its physical address,
 * 0 before fb_init, and its size) */
static uintptr fb_pa_;
static unsigned fb_w_, fb_h_, fb_depth_;

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
  fb_pa_ = fbinfo[8] & 0x3fffffff; fb_w_ = Long_val(w); fb_h_ = Long_val(h); fb_depth_ = Long_val(depth);
  /* (the screen's memory is the VideoCore's to read: never cached) */
  if (fbinfo[8] != 0) uncached_add(fbinfo[8] & 0x3fffffff, fbinfo[9] ? fbinfo[9] : fbinfo[4] * Long_val(h));
  return Val_long(fbinfo[8] & 0x3fffffff);
}

value fb_pitch(value unit) { (void)unit; return Val_long(fb_pitch_); }

/*****************************************************************************/
/* Last words: the machine's end on the screen */
/*****************************************************************************/

/* What the kernel says when it stops or is stuck (a panic, a kernel's
 * fault, the runtime's fatal error, the watchdog: runtime.c), written
 * on the screen too, where the UART's cable is often not plugged: the
 * board's monitor is all one sees (the author, 2026-10-21, the Pi 2's
 * screen frozen under rio: "we should find a way to display some kernel
 * panic info even after running under rio"). Not the console's window
 * (Swconsole: OCaml, the draw device's memory, which the trouble may
 * be in the middle of), but the framebuffer's bytes here, white on
 * red lines from the screen's top, over whatever rio drew, in the
 * kernel's font (font1.bin: 128 characters of 8 x 16, a byte a row, its
 * lowest bit the leftmost pixel), twice as big on a big screen. Nothing
 * taken, no lock, no allocation: it works with the rest broken. The
 * lines wrap at the screen's right, and start again at its top past
 * its bottom. Nothing before fb_init. */
static unsigned lw_x, lw_y;

static void lw_pixel(volatile unsigned char *fb, unsigned x, unsigned y, int on)
{
  volatile unsigned char *p = fb + y * fb_pitch_ + x * (fb_depth_ / 8);
  if (fb_depth_ == 16) *(volatile unsigned short *)p = on ? 0xffff : 0xa000;
  else if (fb_depth_ == 32) *(volatile unsigned *)p = on ? 0xffffffff : 0xffa00000;
}

static void lw_newline(volatile unsigned char *fb, unsigned scale)
{
  unsigned x, y;
  lw_x = 0;
  lw_y += 16 * scale;
  if (lw_y + 16 * scale > fb_h_) lw_y = 0;
  /* (the new line's band red already, the end of a line not wrapped
   * then red too) */
  for (y = lw_y; y < lw_y + 16 * scale; y++)
    for (x = 0; x < fb_w_; x++) lw_pixel(fb, x, y, 0);
}

void lastwords_putc(int c)
{
  volatile unsigned char *fb;
  unsigned scale, k, b, i, j;
  if (fb_pa_ == 0 || (fb_depth_ != 16 && fb_depth_ != 32)) return;
  fb = (volatile unsigned char *)P2V(fb_pa_);
  scale = fb_w_ >= 1600 ? 2 : 1;
  if (lw_x == 0 && lw_y == 0) { lw_y = fb_h_; lw_newline(fb, scale); }   /* the first line's band */
  if (c == '\n') { lw_newline(fb, scale); return; }
  if (lw_x + 8 * scale > fb_w_) lw_newline(fb, scale);
  for (k = 0; k < 16; k++) {
    unsigned bits = (c > ' ' && c < 128) ? (unsigned char)font_image[c * 16 + k] : 0;
    for (b = 0; b < 8; b++)
      for (i = 0; i < scale; i++)
        for (j = 0; j < scale; j++)
          lw_pixel(fb, lw_x + b * scale + j, lw_y + k * scale + i, (bits >> b) & 1);
  }
  lw_x += 8 * scale;
}

void lastwords(const char *s) { while (*s) lastwords_putc(*s++); cache_drain(); }

/* Machine.last_words: an OCaml string's bytes, the same */
value last_words(value s)
{
  long i, n = string_length(s);
  for (i = 0; i < n; i++) lastwords_putc(String_val(s)[i]);
  cache_drain();
  return Val_unit;
}
