/* mini-xv6, step 0: C on the bare Pi 4 or Pi 1, by mini-cc, over goken's C
 * library and shim.c: a line formatted (a double in it: the floating
 * point is on), written, then exits. */
#include <u.h>
#include <libc.h>

#ifdef arm
#define BOARD "Pi 1", "1 core", 0.7
#else
#define BOARD "Pi 4", "4 cores", 1.5
#endif

void
main(void)
{
	char line[64];
	int n;

	n = snprint(line, sizeof line, "mini-xv6: C on the %s, %s, %.2f GHz\n", BOARD);
	write(1, line, n);
	exits(nil);
}
