#include "libc.h"

/* every width and sign: wrapping, division, shifts, conversions */
void
main(int argc, char *argv[])
{
	int i, j;
	unsigned int u;
	char c;
	uchar uc;
	short s;
	unsigned short us;
	long l;

	i = 2147483647;
	i = i + 1;
	print("%d\n", i);
	u = 0;
	u = u - 1;
	print("%ud\n", u);
	print("%d %d %d %d\n", -7 / 2, -7 % 2, 7 / -2, 7 % -2);
	u = 4000000000;
	print("%ud %ud\n", u / 3, u % 7);
	print("%d %d\n", -16 >> 2, (int)((unsigned)-16 >> 2));
	c = 200;
	uc = 200;
	print("%d %d\n", c, uc);
	s = 40000;
	us = 40000;
	print("%d %d\n", s, us);
	c = 127;
	c++;
	print("%d\n", c);
	l = 1;
	for(j = 0; j < 31; j++)
		l = l * 2;
	print("%ld\n", l);
	i = 5;
	i += 3; i -= 1; i *= 6; i /= 4; i %= 7; i <<= 3; i >>= 1; i &= 13; i |= 32; i ^= 5;
	print("%d\n", i);
	print("%d %d %d\n", ~5, !5, !0);
	print("%d %d\n", (char)300, (uchar)(-1));
	print("%d %d %d\n", 3 < 5, -1 < 1, (unsigned)-1 < 1);
	print("%d\n", sizeof(int) + sizeof(long) + sizeof(short));
	exits(0);
}
