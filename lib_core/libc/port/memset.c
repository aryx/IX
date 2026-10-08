/* Plan 9's, by principia and goken (libc's README.md; LICENSE). */
#include    <u.h>
#include    <libc.h>
void*
memset(void *ap, int c, ulong n)
{
    char *p;

    p = ap;
    while(n > 0) {
        *p++ = c;
        n--;
    }
    return ap;
}
