/* Plan 9's, by principia and goken (libc's README.md; LICENSE). */
#include    <u.h>
#include    <libc.h>
/* arm64's: nothing reads it (setmalloctag, which keeps nothing). arm
 * has a real one, arch/arm/getcallerpc.s. */
#ifndef arm
uintptr
getcallerpc(void *v)
{
    USED(v);
    return 0;
}
#endif
