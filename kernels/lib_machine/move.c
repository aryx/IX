/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* memmove and memcpy for the kernels, by words: included by libc.c
 * (the Makefile's build, by gcc) and by shim.c (ix's tools': the C
 * library's memmove, Plan 9's, is a byte at a time, and the Pi 4's
 * kernel by ix's tools reached its prompt in 65 s under mini-qemu, 49%
 * of it in memmove, where gcc's took 14 on the Pi 1). The includer
 * says what a word is (MWORD: gcc's unsigned long; Plan 9's uintptr,
 * a long being 32 bits for 7c), what a size is (MSIZE), and HOST_MOVE
 * (libc.c's page). C that both compilers take: declarations first. */

/* memmove's words: the two do not overlap, which memmove's forward
 * copy is right for. A byte at a time, it was 27% of mini-9pi's time
 * under mini-netscape with the mouse over a link: Memdraw's fill
 * (imag_rows) repeats a row with it, a frame's white 1.2 MB.
 * old: char *dd = d; const char *ss = s;
 *      HOST_MOVE(d, s, n);
 *      while (n--) *dd++ = *ss++;
 *      return d; */
void *memmove(void *d, const void *s, MSIZE n);
void *memcpy(void *d, const void *s, MSIZE n)
{
  return memmove(d, s, n);
}

/* A word at a time whenever d and s share their alignment (a
 * framebuffer's scroll moves a megabyte and a half), else a byte.
 *
 * old (words only when d, s and n were all aligned, else bytes):
 *   if (((d | s | n) & (sizeof(long) - 1)) == 0) { ... words ... }
 *   else while (n--) *dd++ = *ss++;
 * Now words whenever d and s share their alignment: the unaligned
 * bytes at the head, the words, the bytes at the tail. mini-9pi's OCaml
 * pixels blit rows of 16-bit pixels (String.blit is memmove) starting
 * at any even address and of any even length: all of them went a byte
 * at a time, memmove was 28% of the kernel's time drawing a console
 * (rows scrolled, the image flushed to the framebuffer) */
void *memmove(void *d, const void *s, MSIZE n)
{
  char *dd = d; const char *ss = s;
  MWORD m = sizeof(MWORD) - 1;
  MWORD *dw; const MWORD *sw;
  MWORD a, b, c, e;
  HOST_MOVE(d, s, n);
  if ((((MWORD)dd ^ (MWORD)ss) & m) == 0) {
    /* (forward too when d is after s and they do not overlap: one
     * string's bytes to another's, which the eight words a turn are for) */
    if (dd < ss || dd >= ss + n) {
      while (n && ((MWORD)dd & m)) { *dd++ = *ss++; n--; }
      dw = (MWORD *)dd; sw = (const MWORD *)ss;
      /* (eight words a turn first: a game's frame is copied whole
       * twice, to the window then to the framebuffer, half a megabyte
       * each; a word a turn was four instructions a word) */
      for (; n >= 8 * sizeof(MWORD); n -= 8 * sizeof(MWORD)) {
        a = sw[0]; b = sw[1]; c = sw[2]; e = sw[3];
        dw[0] = a; dw[1] = b; dw[2] = c; dw[3] = e;
        a = sw[4]; b = sw[5]; c = sw[6]; e = sw[7];
        dw[4] = a; dw[5] = b; dw[6] = c; dw[7] = e;
        dw += 8; sw += 8;
      }
      for (; n > m; n -= sizeof(MWORD)) *dw++ = *sw++;
      dd = (char *)dw; ss = (const char *)sw;
      while (n--) *dd++ = *ss++;
    } else {
      dd += n; ss += n;
      while (n && ((MWORD)dd & m)) { *--dd = *--ss; n--; }
      dw = (MWORD *)dd; sw = (const MWORD *)ss;
      for (; n > m; n -= sizeof(MWORD)) *--dw = *--sw;
      dd = (char *)dw; ss = (const char *)sw;
      while (n--) *--dd = *--ss;
    }
    return d;
  }
  if (dd < ss) while (n--) *dd++ = *ss++;
  else { dd += n; ss += n; while (n--) *--dd = *--ss; }
  return d;
}
