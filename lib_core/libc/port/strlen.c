/* Plan 9's, by principia and goken (libc's README.md; LICENSE). */
#include    <u.h>
#include    <libc.h>
long
strlen(char *s)
{

    return strchr(s, '\0') - s;
}
