/* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. */
/* memmove and memset, the machines' assembly (arch/arm, arch/arm64),
 * against a byte's loop: every alignment of the two places, forward,
 * backward and overlapping, the sizes around a turn of the loops; and
 * each called after a call that left all ones where the size goes (a
 * ulong is 32 bits: 9front's arm64 file read 64, and the kernel's
 * heap was overwritten, plan_pi4.md). Exits "bad" at the first wrong
 * byte. Built and run by mem_check.sh. */
#include <u.h>
#include <libc.h>

static char a[600], b[600];

static int
movecheck(void)
{
	int d, s, n, i;

	for(d = 0; d < 300; d += 1 + (d > 20) * 37)
	for(s = 0; s < 300; s += 1 + (s > 20) * 41)
	for(n = 0; n < 200; n += 1 + (n > 40) * 13){
		for(i = 0; i < 600; i++)
			a[i] = b[i] = i * 7 + 3;
		memmove(a + d, a + s, n);
		if(d < s)
			for(i = 0; i < n; i++) b[d + i] = b[s + i];
		else
			for(i = n - 1; i >= 0; i--) b[d + i] = b[s + i];
		for(i = 0; i < 600; i++)
			if(a[i] != b[i])
				return 1;
	}
	return 0;
}

static int
setcheck(void)
{
	int d, n, i;

	for(d = 0; d < 40; d++)
	for(n = 0; n < 100; n++){
		for(i = 0; i < 600; i++)
			a[i] = b[i] = i;
		memset(a + d, 0x5a + n, n);
		for(i = 0; i < n; i++)
			b[d + i] = 0x5a + n;
		for(i = 0; i < 600; i++)
			if(a[i] != b[i])
				return 1;
	}
	return 0;
}

/* a call that leaves all ones in the slots of the next call's arguments */
static void
dirty(uvlong x, uvlong y, uvlong z)
{
	USED(x, y, z);
}

static int
slotcheck(void)
{
	int i;

	for(i = 0; i < 64; i++)
		a[i] = b[i] = i;
	dirty(~0ULL, ~0ULL, ~0ULL);
	memmove(b, a + 8, 40);
	dirty(~0ULL, ~0ULL, ~0ULL);
	memset(a, 7, 20);
	for(i = 0; i < 64; i++)
		if(b[i] != (i < 40 ? i + 8 : i) || a[i] != (i < 20 ? 7 : i))
			return 1;
	return 0;
}

void
main(void)
{
	if(movecheck() || setcheck() || slotcheck())
		exits("bad");
	exits(nil);
}
