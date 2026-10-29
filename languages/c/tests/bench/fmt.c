/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */

/* the libc's C at work: print's formatting (snprint, %d %x %s %f),
 * strcpy, strlen, memcmp, strcmp; a loop of a few calls each */
#include <u.h>
#include <libc.h>

void
main(void)
{
	char buf[64], b2[64];
	int i, n;

	n = 0;
	for(i = 0; i < 20000; i++){
		snprint(buf, sizeof buf, "%d %x %s %5.2f", i, i * 7, "abc", i / 3.0);
		strcpy(b2, buf);
		n += strlen(b2) + (memcmp(buf, b2, 8) == 0) + (strcmp(buf, "zzz") < 0);
	}
	print("%d\n", n);
	exits(0);
}
