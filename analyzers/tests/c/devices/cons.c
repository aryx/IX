#include "dev.h"

static char	line[64];

int
consread(char *buf, int n)
{
	buf[0] = line[0];
	return n;
}

int
conswrite(char *buf, int n)
{
	line[0] = buf[0];
	return n;
}

Dev consdev = { "cons", consread, conswrite };
