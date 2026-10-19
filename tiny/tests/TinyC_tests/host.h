// Claude Code
// Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
//
// libc.h for the host's cc, the reference of TinyC_test.sh (RECORD=1):
// the program's #include "libc.h" made this file's, the program built
// with -fsigned-char -fwrapv (tiny-c's char is signed, its arithmetic
// wraps). Plan 9's C on a 32-bit machine, on a 64-bit host: a long is
// an int, print's verbs are printf's (an l dropped; %u is a verb, as
// in TinyCRuntime/libc.c and goken's libc, so %ud is the number, then
// a d), and exits ends with 0 for nil or "", 1 otherwise, as
// start.tm's. What still differs is a pointer's size: the tests print
// none.
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>

typedef unsigned char uchar;
#define ulong unsigned int
#define long int
#define strlen(s) ((int)strlen(s))

static void
plan9fmt(char *out, char *fmt)
{
	for(; *fmt; fmt++){
		*out++ = *fmt;
		if(*fmt != '%')
			continue;
		while(fmt[1] == 'l')
			fmt++;
	}
	*out = 0;
}

static int
print(char *fmt, ...)
{
	char f[256];
	va_list ap;
	int n;

	plan9fmt(f, fmt);
	va_start(ap, fmt);
	n = vprintf(f, ap);
	va_end(ap);
	return n;
}

static int
sprint(char *buf, char *fmt, ...)
{
	char f[256];
	va_list ap;
	int n;

	plan9fmt(f, fmt);
	va_start(ap, fmt);
	n = vsprintf(buf, f, ap);
	va_end(ap);
	return n;
}

static void
exits(char *s)
{
	fflush(stdout);
	exit(s && *s ? 1 : 0);
}
