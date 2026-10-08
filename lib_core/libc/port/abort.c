/* goken's, around Plan 9's libc (libc's README.md; LICENSE). */
#include <u.h>
#include <libc.h>

/* no signal to raise yet: the process ends */
void
abort(void)
{
	exit(1);
}
