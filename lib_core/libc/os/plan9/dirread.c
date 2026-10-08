/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* Plan 9's, by principia and goken (libc's README.md; LICENSE). */
#include <u.h>
#include <libc.h>
#include "stat9p.h"

/* dirread and dirreadall: principia's 9sys/dirread.c. A directory is
 * a file whose read gives entries one after the other, in fstat's
 * format; dirpackage finds each and unpacks it in a Dir. */
static long
dirpackage(uchar *buf, long ts, Dir **d)
{
	char *s;
	long ss, i, n, nn, m;

	*d = nil;
	if (ts <= 0)
		return 0;

	/* first find the number of entries, checking each looks like a
	 * well-formed stat buffer, and size all their associated strings.
	 */
	ss = 0;
	n = 0;
	for (i = 0; i < ts; i += m) {
		m = BIT16SZ + GBIT16(&buf[i]);
		if (statcheck(&buf[i], m) < 0)
			break;
		ss += m;
		n++;
	}

	if (i != ts)
		return -1;

	*d = malloc(n*sizeof(Dir) + ss);
	if (*d == nil)
		return -1;

	/* then convert all of them */
	s = (char*)*d + n*sizeof(Dir);
	nn = 0;
	for (i = 0; i < ts; i += m) {
		m = BIT16SZ + GBIT16((uchar*)&buf[i]);
		if (nn >= n || convM2D(&buf[i], m, *d + nn, s) != m) {
			free(*d);
			*d = nil;
			return -1;
		}
		nn++;
		s += m;
	}

	return nn;
}

long
dirread(fdt fd, Dir **d)
{
	uchar *buf;
	long ts;

	buf = malloc(DIRMAX);
	if (buf == nil)
		return -1;
	ts = read(fd, buf, DIRMAX);
	if (ts >= 0)
		ts = dirpackage(buf, ts, d);
	free(buf);
	return ts;
}

long
dirreadall(fdt fd, Dir **d)
{
	uchar *buf, *nbuf;
	long n, ts;

	buf = nil;
	ts = 0;
	n = 0;
	for (;;) {
		nbuf = realloc(buf, ts+DIRMAX);
		if (nbuf == nil) {
			free(buf);
			return -1;
		}
		buf = nbuf;
		n = read(fd, buf+ts, DIRMAX);
		if (n <= 0)
			break;
		ts += n;
	}
	if (ts >= 0)
		ts = dirpackage(buf, ts, d);
	free(buf);
	if (ts == 0 && n < 0)
		return -1;
	return ts;
}
