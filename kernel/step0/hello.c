/* mini-xv6, step 0: C on the bare Pi 4, by mini-cc, over goken's C
 * library and shim.c: a line formatted (a double in it: the floating
 * point is on), written, then exits. */
#include <u.h>
#include <libc.h>

void
main(void)
{
	char line[64];
	int n;

	n = snprint(line, sizeof line, "mini-xv6: C on the Pi 4, %d cores, %.2f GHz\n", 4, 1.5);
	write(1, line, n);
	exits(nil);
}
