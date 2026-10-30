#include "dev.h"

Dev *devtab[] = { &consdev, &nulldev, 0 };

void	(*atexit_hook)(void);

int
sysread(int fd, char *buf, int n)
{
	Dev *d;

	d = devtab[fd];
	return d->read(buf, n);
}

int
syswrite(int fd, char *buf, int n)
{
	return devtab[fd]->write(buf, n);
}

int
twice(int (*f)(char*, int), char *buf, int n)
{
	f(buf, n);
	return f(buf, n);
}

void
main(void)
{
	char buf[8];

	sysread(0, buf, 8);
	syswrite(1, buf, 8);
	twice(conswrite, buf, 1);
	atexit_hook();
}
