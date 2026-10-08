/* Plan 9's, by principia and goken (libc's README.md; LICENSE). */
#include    <u.h>
#include    <libc.h>
void*
memccpy(void *a1, void *a2, int c, ulong n)
{
    uchar *s1, *s2;

    s1 = a1;
    s2 = a2;
    c &= 0xFF;
    while(n > 0) {
        if((*s1++ = *s2++) == c)
            return s1;
        n--;
    }
    return nil;
}
