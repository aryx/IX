#include "dev.h"

int
nullread(char *buf, int n)
{
	return 0;
}

int
nullwrite(char *buf, int n)
{
	return n;
}

Dev nulldev = { "null", nullread, nullwrite };
