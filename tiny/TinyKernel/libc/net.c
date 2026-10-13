// Claude Code, Copyright (C) 2026 Yoann Padioleau, LGPL (see TinyC.ml)
//
// reach(host, port): dial, by an address ("10.0.0.1") or by a name
// ("example.com"). A name's address is asked of the wire's other end,
// on its port 53: the name written, the address read, as text. That is
// all there is of DNS here: who has names is the other end
// (tiny-machine -net-out asks its host; the page has none).
#include "user.h"

int
reach(char *host, int port)
{
	char address[64], *p;
	int fd, n;

	for(p = host; *p == '.' || (*p >= '0' && *p <= '9'); p++)
		;
	if(*p == 0)
		return dial(host, port);
	fd = dial("10.0.0.1", 53);
	if(fd < 0)
		return -1;
	write(fd, host, strlen(host));
	n = read(fd, address, 63);
	close(fd);
	if(n <= 0)
		return -1;
	address[n] = 0;
	return dial(address, port);
}
