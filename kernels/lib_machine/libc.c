/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* What ocaml-light's runtime asks of a C library, bare-metal on the Pi1
 * (plan_kernel.md, step 1), as ~/xix/kernel/fakes.c did for the
 * bytecode runtime: writes to stdout and stderr go to the PL011, malloc
 * takes the RAM after the kernel (a bump pointer: the runtime frees
 * little, and its heap only grows), sprintf formats the integers
 * (string_of_int, Printf), and the rest -- files, signals, the maths,
 * reading floats -- panics, naming itself: nothing mini-xv6 runs calls
 * it yet. The list is what the linker reported undefined. */

#include <stdarg.h>
#include <stddef.h>
#include "board.h"

void kmain(void);
void caml_main(char **argv);

/*****************************************************************************/
/* The console: the PL011 */
/*****************************************************************************/

/* the PL011, where the board's start.s maps it (board.h) */
#define UART_DR ((volatile unsigned int *)(UART_BASE + 0x00))
#define UART_FR ((volatile unsigned int *)(UART_BASE + 0x18))

static void putc_(char c)
{
  while (*UART_FR & 0x20)          /* the transmit FIFO full */
    ;
  *UART_DR = (unsigned char)c;
}

static void puts_(const char *s) { while (*s) putc_(*s++); }

void exit(int status);

static void panic(const char *what)
{
  puts_("mini-xv6: panic: ");
  puts_(what);
  puts_("\n");
  exit(2);
}

void exit(int status)
{
  (void)status;
  for (;;)
    __asm__ volatile("wfi");      /* wait for an interrupt: none comes */
}

void abort(void) { panic("abort"); }

/*****************************************************************************/
/* Memory */
/*****************************************************************************/

extern char end[];
static char *brk_ = end;

/* a block: its size in the word before it (realloc needs it) */
void *malloc(size_t n)
{
  char *p = (char *)(((size_t)brk_ + 7) & ~(size_t)7) + 8;
  if (p + n > (char *)HEAP_LIMIT) return NULL;   /* board.h: the processes' pages above */
  ((size_t *)p)[-1] = n;
  brk_ = p + n;
  return p;
}

void free(void *p) { (void)p; }

/* how far the kernel's own memory goes, and how far it may (physical
 * addresses): what /dev/swap says, and where the processes' pages
 * start (Arch.pages) */
unsigned long kernel_heap_top(void) { return (unsigned long)brk_ - KERNBASE; }
unsigned long kernel_heap_limit(void) { return (unsigned long)HEAP_LIMIT - KERNBASE; }

/* The kernel built for a page (make WEB=1, web/host.s): the bytes
 * moved and filled by the emulator itself when it will, the loops
 * below otherwise and for a few bytes (the request is some
 * instructions too) */
#ifdef WEB
int host_move(void *d, const void *s, size_t n);
int host_fill(void *d, int c, size_t n);
#define HOST_MOVE(d, s, n) if ((n) >= 16 && host_move(d, s, n)) return d
#define HOST_FILL(d, c, n) if ((n) >= 16 && host_fill(d, c, n)) return d
#else
#define HOST_MOVE(d, s, n)
#define HOST_FILL(d, c, n)
#endif

void *memcpy(void *d, const void *s, size_t n)
{
  char *dd = d; const char *ss = s;
  HOST_MOVE(d, s, n);
  while (n--) *dd++ = *ss++;
  return d;
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
void *memmove(void *d, const void *s, size_t n)
{
  char *dd = d; const char *ss = s;
  unsigned long m = sizeof(long) - 1;
  HOST_MOVE(d, s, n);
  if ((((unsigned long)dd ^ (unsigned long)ss) & m) == 0) {
    /* (forward too when d is after s and they do not overlap: one
     * string's bytes to another's, which the eight words a turn are for) */
    if (dd < ss || dd >= ss + n) {
      while (n && ((unsigned long)dd & m)) { *dd++ = *ss++; n--; }
      long *dw = (long *)dd; const long *sw = (const long *)ss;
      /* (eight words a turn first: a game's frame is copied whole
       * twice, to the window then to the framebuffer, half a megabyte
       * each; a word a turn was four instructions a word) */
      for (; n >= 8 * sizeof(long); n -= 8 * sizeof(long)) {
        long a = sw[0], b = sw[1], c = sw[2], e = sw[3];
        dw[0] = a; dw[1] = b; dw[2] = c; dw[3] = e;
        a = sw[4]; b = sw[5]; c = sw[6]; e = sw[7];
        dw[4] = a; dw[5] = b; dw[6] = c; dw[7] = e;
        dw += 8; sw += 8;
      }
      for (; n > m; n -= sizeof(long)) *dw++ = *sw++;
      dd = (char *)dw; ss = (const char *)sw;
      while (n--) *dd++ = *ss++;
    } else {
      dd += n; ss += n;
      while (n && ((unsigned long)dd & m)) { *--dd = *--ss; n--; }
      long *dw = (long *)dd; const long *sw = (const long *)ss;
      for (; n > m; n -= sizeof(long)) *--dw = *--sw;
      dd = (char *)dw; ss = (const char *)sw;
      while (n--) *--dd = *--ss;
    }
    return d;
  }
  if (dd < ss) while (n--) *dd++ = *ss++;
  else { dd += n; ss += n; while (n--) *--dd = *--ss; }
  return d;
}

void *memset(void *d, int c, size_t n)
{
  char *dd = d;
  HOST_FILL(d, c, n);
  while (n--) *dd++ = (char)c;
  return d;
}

void bcopy(const void *s, void *d, size_t n) { memmove(d, s, n); }

int memcmp(const void *a, const void *b, size_t n)
{
  const unsigned char *x = a, *y = b;
  for (; n; n--, x++, y++) if (*x != *y) return *x - *y;
  return 0;
}

void *realloc(void *p, size_t n)
{
  void *q = malloc(n);
  if (p && q) { size_t old = ((size_t *)p)[-1]; memcpy(q, p, old < n ? old : n); }
  return q;
}

void *calloc(size_t k, size_t n) { void *p = malloc(k * n); if (p) memset(p, 0, k * n); return p; }

size_t strlen(const char *s) { size_t n = 0; while (s[n]) n++; return n; }
int strcmp(const char *a, const char *b) { while (*a && *a == *b) a++, b++; return (unsigned char)*a - (unsigned char)*b; }
char *strcpy(char *d, const char *s) { char *r = d; while ((*d++ = *s++)) ; return r; }

long strtol(const char *s, char **endp, int base)
{
  long v = 0; int neg = 0;
  while (*s == ' ') s++;
  if (*s == '-' || *s == '+') neg = *s++ == '-';
  if (base == 0) base = (s[0] == '0' && (s[1] == 'x' || s[1] == 'X')) ? (s += 2, 16) : 10;
  for (;; s++) {
    int d = *s >= '0' && *s <= '9' ? *s - '0' : *s >= 'a' && *s <= 'z' ? *s - 'a' + 10 : *s >= 'A' && *s <= 'Z' ? *s - 'A' + 10 : 99;
    if (d >= base) break;
    v = v * base + d;
  }
  if (endp) *endp = (char *)s;
  return neg ? -v : v;
}

/*****************************************************************************/
/* Division: the Pi1's ARMv6 has no divide instruction, and the
 * compilers call these (ARM's run-time ABI). Not libgcc's: the armhf
 * one is Thumb-2, for ARMv7, and an ARMv6 cannot run it (the runtime's
 * first division jumped into Thumb and took an undefined instruction).
 * A quotient and remainder come back in r0 and r1: a 64-bit result's
 * two halves. */
/*****************************************************************************/

#ifdef __arm__
/* claude: the ARM EABI's divisions (arm32 has no divide instruction on
 * the Pi1, and Ubuntu's libgcc is Thumb-2: plan_kernel.md) */
static unsigned long long udivmod(unsigned n, unsigned d)
{
  unsigned q = 0, r = 0;
  int i;
  if (d == 0) panic("division by zero");
  for (i = 31; i >= 0; i--) {
    r = (r << 1) | ((n >> i) & 1);
    if (r >= d) { r -= d; q |= 1u << i; }
  }
  return ((unsigned long long)r << 32) | q;
}

unsigned __aeabi_uidiv(unsigned n, unsigned d) { return (unsigned)udivmod(n, d); }
unsigned long long __aeabi_uidivmod(unsigned n, unsigned d) { return udivmod(n, d); }

/* signed: the quotient toward zero, the remainder of the dividend's sign */
unsigned long long __aeabi_idivmod(int n, int d)
{
  unsigned long long qr = udivmod(n < 0 ? -(unsigned)n : (unsigned)n, d < 0 ? -(unsigned)d : (unsigned)d);
  unsigned q = (unsigned)qr, r = (unsigned)(qr >> 32);
  if ((n < 0) != (d < 0)) q = -q;
  if (n < 0) r = -r;
  return ((unsigned long long)r << 32) | q;
}

int __aeabi_idiv(int n, int d) { return (int)(unsigned)__aeabi_idivmod(n, d); }

/* the older names, which ocaml-light's arm backend calls for / and mod */
int __divsi3(int n, int d) { return __aeabi_idiv(n, d); }
int __modsi3(int n, int d) { return (int)(__aeabi_idivmod(n, d) >> 32); }
#endif

/*****************************************************************************/
/* Formatting: the integers, as the runtime's formats ask (flags, width,
 * precision, l); no floats */
/*****************************************************************************/

static int format(char *out, const char *fmt, va_list ap)
{
  char *o = out;
  for (; *fmt; fmt++) {
    if (*fmt != '%') { *o++ = *fmt; continue; }
    int left = 0, zero = 0, plus = 0, space = 0, alt = 0, width = 0, prec = -1;
    for (fmt++;; fmt++) {
      if (*fmt == '-') left = 1; else if (*fmt == '0') zero = 1; else if (*fmt == '+') plus = 1;
      else if (*fmt == ' ') space = 1; else if (*fmt == '#') alt = 1; else break;
    }
    if (*fmt == '*') { width = va_arg(ap, int); fmt++; } else while (*fmt >= '0' && *fmt <= '9') width = width * 10 + *fmt++ - '0';
    if (*fmt == '.') { prec = 0; fmt++; if (*fmt == '*') { prec = va_arg(ap, int); fmt++; } else while (*fmt >= '0' && *fmt <= '9') prec = prec * 10 + *fmt++ - '0'; }
    int longs = 0;
    while (*fmt == 'l' || *fmt == 'h' || *fmt == 'z') { if (*fmt != 'h') longs++; fmt++; }
    char buf[40], *b = buf + sizeof buf, sign = 0;
    const char *str = NULL; int len;
    switch (*fmt) {
    case 'd': case 'i': case 'u': case 'x': case 'X': case 'o': case 'p': {
      unsigned long u; int base = *fmt == 'o' ? 8 : (*fmt == 'x' || *fmt == 'X' || *fmt == 'p') ? 16 : 10;
      /* claude: an int read as an int (on arm64 its register's upper half
       * is not the value's), a long as a long */
      if (*fmt == 'd' || *fmt == 'i') { long v = longs ? va_arg(ap, long) : va_arg(ap, int); if (v < 0) { sign = '-'; u = -(unsigned long)v; } else { u = v; if (plus) sign = '+'; else if (space) sign = ' '; } }
      else if (*fmt == 'p') { u = (unsigned long)va_arg(ap, void *); alt = 1; }
      else u = longs ? va_arg(ap, unsigned long) : va_arg(ap, unsigned);
      const char *digits = *fmt == 'X' ? "0123456789ABCDEF" : "0123456789abcdef";
      do { *--b = digits[u % base]; u /= base; } while (u);
      while (buf + sizeof buf - b < prec) *--b = '0';
      if (alt && base == 16) { *--b = *fmt == 'X' ? 'X' : 'x'; *--b = '0'; }
      if (alt && base == 8 && *b != '0') *--b = '0';
      str = b; len = buf + sizeof buf - b;
      break;
    }
    case 'c': buf[0] = (char)va_arg(ap, int); str = buf; len = 1; break;
    case 's': str = va_arg(ap, const char *); if (!str) str = "(null)"; len = strlen(str); if (prec >= 0 && prec < len) len = prec; break;
    case '%': str = "%"; len = 1; break;
    default: panic("printf: a float or an unknown conversion");
    }
    int pad = width - len - (sign ? 1 : 0);
    if (!left && !(zero && prec < 0)) while (pad-- > 0) *o++ = ' ';
    if (sign) *o++ = sign;
    if (!left && zero && prec < 0) while (pad-- > 0) *o++ = '0';
    while (len--) *o++ = *str++;
    if (left) while (pad-- > 0) *o++ = ' ';
  }
  *o = 0;
  return o - out;
}

int sprintf(char *out, const char *fmt, ...)
{
  va_list ap; va_start(ap, fmt);
  int n = format(out, fmt, ap);
  va_end(ap);
  return n;
}

/* the runtime's fatal errors and GC messages: to the console */
typedef struct { int fd; } FILE;
static FILE stderr_ = { 2 };
FILE *stderr = &stderr_;

int fprintf(FILE *f, const char *fmt, ...)
{
  char buf[512];
  va_list ap; va_start(ap, fmt);
  int n = format(buf, fmt, ap);
  va_end(ap);
  (void)f;
  puts_(buf);
  return n;
}

int fflush(FILE *f) { (void)f; return 0; }

/*****************************************************************************/
/* The system: stdout and stderr, and nothing else */
/*****************************************************************************/

int errno_;
int *__errno_location(void) { return &errno_; }

int write(int fd, const void *p, size_t n)
{
  const char *s = p;
  if (fd != 1 && fd != 2) panic("write: not stdout or stderr");
  for (size_t i = 0; i < n; i++) putc_(s[i]);
  return n;
}

/* getenv: CAMLRUNPARAM only, given when the kernel is built (make
 * CAMLRUNPARAM=s=256k,v=1): ocaml-light's collector's parameters, as
 * OCAMLRUNPARAM gives OCaml's (s the minor heap, i the major heap's
 * increment, both in words, o the space overhead in %, v its messages:
 * < > a minor collection, $ a major cycle's end); none, its defaults
 * (plan_9pi_gc.md) */
char *getenv(const char *name)
{
#ifdef CAMLRUNPARAM
  if (strcmp(name, "CAMLRUNPARAM") == 0) return CAMLRUNPARAM;
#endif
  (void)name;
  return NULL;
}

/* sscanf, for asmrun/startup.c's scanmult only: "=%lu%c", a number and
 * its multiplier (k, M, G) */
int __isoc99_sscanf(const char *s, const char *fmt, ...)
{
  va_list ap;
  int n = 0;

  va_start(ap, fmt);
  for (; *fmt; fmt++) {
    if (*fmt != '%') { if (*s != *fmt) break; s++; continue; }
    fmt++;
    if (fmt[0] == 'l' && fmt[1] == 'u') {
      unsigned long v = 0;
      if (*s < '0' || *s > '9') break;
      while (*s >= '0' && *s <= '9') v = v * 10 + (unsigned long)(*s++ - '0');
      *va_arg(ap, unsigned long *) = v;
      n++;
      fmt++;
    } else if (fmt[0] == 'u') {     /* OCaml 4.14's scanmult: "=%u%c" */
      unsigned v = 0;
      if (*s < '0' || *s > '9') break;
      while (*s >= '0' && *s <= '9') v = v * 10 + (unsigned)(*s++ - '0');
      *va_arg(ap, unsigned *) = v;
      n++;
    } else if (fmt[0] == 'x') {     /* (its "=0x%x%c": no parameter is written so) */
      break;
    } else if (fmt[0] == 'c') {
      if (!*s) break;
      *va_arg(ap, char *) = *s++;
      n++;
    } else panic("sscanf: only =%lu%c");
  }
  va_end(ap);
  return n;
}
int sigemptyset(void *set) { (void)set; return 0; }
int sigaction(int s, const void *a, void *o) { (void)s; (void)a; (void)o; return 0; }
int sigprocmask(int h, const void *s, void *o) { (void)h; (void)s; (void)o; return 0; }
long times(void *t) { (void)t; return 0; }
char *strerror(int e) { (void)e; return "error"; }

#define STUB(name) void name(void) { panic(#name); }
STUB(read) STUB(open64) STUB(open) STUB(close) STUB(stat)
#ifndef OCAML4
STUB(lseek64) STUB(lseek)
#endif
STUB(unlink) STUB(rename) STUB(chdir) STUB(getcwd)
STUB(system) STUB(__stat64_time64) STUB(strtod)
STUB(acos) STUB(asin) STUB(atan) STUB(atan2) STUB(ceil) STUB(cos) STUB(cosh) STUB(exp) STUB(fabs)
STUB(floor) STUB(fmod) STUB(frexp) STUB(ldexp) STUB(log) STUB(log10) STUB(modf) STUB(pow) STUB(sin)
STUB(sinh) STUB(tan) STUB(tanh)

/* What OCaml 4.14's runtime asks more (kernel.mk's COMPILER=ocaml);
 * again the list is what the linker reported undefined. A few do
 * something: the formats into a buffer of a given size (string_of_int:
 * the runtime tries 128 bytes, then asks for the length said), the
 * fatal errors' vfprintf, and ffs, the lowest bit set, 1 the first
 * (the best-fit free list's map of its small sizes); and fmin. The system's
 * calls fail (-1: the runtime's start asks for its executable's name,
 * readlink, and an alternate stack for the stack overflows, mmap and
 * sigaltstack, and goes on without), or say nothing (0: no locale, no
 * terminal); the rest panics, as above. */
#ifdef OCAML4
int vsnprintf(char *out, size_t size, const char *fmt, va_list ap)
{
  char buf[512];
  int n = format(buf, fmt, ap);
  if (size > 0) {
    size_t k = (size_t)n < size - 1 ? (size_t)n : size - 1;
    memcpy(out, buf, k);
    out[k] = 0;
  }
  return n;
}

int snprintf(char *out, size_t size, const char *fmt, ...)
{
  va_list ap; va_start(ap, fmt);
  int n = vsnprintf(out, size, fmt, ap);
  va_end(ap);
  return n;
}

int vfprintf(FILE *f, const char *fmt, va_list ap)
{
  char buf[512];
  int n = format(buf, fmt, ap);
  (void)f;
  puts_(buf);
  return n;
}

int ffs(int x)
{
  int n = 1;
  if (x == 0) return 0;
  while ((x & 1) == 0) { x = (int)((unsigned)x >> 1); n++; }
  return n;
}

/* (the major collector's slice: the smaller of two amounts of work) */
double fmin(double a, double b) { return a < b ? a : b; }

long __isoc23_strtol(const char *s, char **endp, int base) { return strtol(s, endp, base); }
char *secure_getenv(const char *name) { return getenv(name); }

#define FAIL(name) long name(void) { return -1; }
#define NONE(name) long name(void) { return 0; }
FAIL(readlink) FAIL(mmap) FAIL(munmap) FAIL(sigaltstack) FAIL(getrusage) FAIL(gettimeofday) FAIL(ioctl)
/* (a channel's start asks where its descriptor is: nowhere, and it goes on) */
FAIL(lseek) FAIL(lseek64)
FAIL(mkdir) FAIL(rmdir) FAIL(kill) FAIL(fork) FAIL(waitpid) FAIL(shmat)
NONE(newlocale) NONE(uselocale) NONE(freelocale) NONE(isatty) NONE(__sigsetjmp)
NONE(sigaddset) NONE(sigdelset) NONE(sigismember) NONE(opendir) NONE(readdir) NONE(closedir)
NONE(dlopen) NONE(dlsym) NONE(dlclose) NONE(dlerror)
long getpid(void) { return 1; }
long getppid(void) { return 1; }
STUB(strtod_l)
STUB(acosh) STUB(asinh) STUB(atanh) STUB(cbrt) STUB(copysign) STUB(erf) STUB(erfc) STUB(exp2)
STUB(expm1) STUB(fma) STUB(hypot) STUB(log1p) STUB(log2) STUB(nextafter) STUB(round) STUB(trunc)
#endif

/* the square root (the draw device's thick lines and discs: Memshape),
 * by Newton's steps from above, until they no longer go down */
double sqrt(double x)
{
  double r, next;
  if (x <= 0) return 0;
  r = x > 1 ? x : 1;
  for (;;) {
    next = 0.5 * (r + x / r);
    if (next >= r) return r;
    r = next;
  }
}

/*****************************************************************************/
/* The start */
/*****************************************************************************/

void kmain(void)
{
  static char *argv[] = { "mini-xv6", NULL };
  caml_main(argv);
  exit(0);
}
