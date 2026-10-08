/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* goken's, around Plan 9's libc (libc's README.md; LICENSE). */
#include <u.h>
#include <libc.h>
#include "stat9p.h"

/* dirfstat and dirfwstat for Plan 9, over the kernel's fstat and
 * fwstat and their format (convM2D.c, convD2M.c). DIRSIZE is a guess,
 * as principia's: if the kernel says more is needed, once more with
 * what it said. */
extern int fstat(int fd, uchar *buf, int nbuf);
extern int fwstat(int fd, uchar *buf, int nbuf);

enum {
	DIRSIZE = STATFIXLEN + 16*4
};

Dir*
dirfstat(fdt fd)
{
	Dir *d;
	uchar *buf;
	int n, nd, i;

	nd = DIRSIZE;
	for (i = 0; i < 2; i++) {
		d = malloc(sizeof(Dir) + BIT16SZ + nd);
		if (d == nil)
			return nil;
		buf = (uchar*)&d[1];
		n = fstat(fd, buf, BIT16SZ+nd);
		if (n < BIT16SZ) {
			free(d);
			return nil;
		}
		nd = GBIT16(buf);
		if (nd <= n) {
			convM2D(buf, n, d, (char*)&d[1]);
			return d;
		}
		free(d);
	}
	return nil;
}

/* The fields left as nulldir made them are left alone by the kernel
 * itself (all ones), and a name is a rename. */
int
dirfwstat(fdt fd, Dir *d)
{
	uchar *buf;
	int r;

	r = sizeD2M(d);
	buf = malloc(r);
	if (buf == nil)
		return -1;
	convD2M(d, buf, r);
	r = fwstat(fd, buf, r);
	free(buf);
	return r;
}
