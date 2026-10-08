/* Plan 9's, by principia and goken (libc's README.md; LICENSE). */
#include    <u.h>
#include    <libc.h>
char*
strdup(char *s)
{
    char *ns;

    ns = malloc(strlen(s) + 1);
    if(ns == nil)
        return nil;
    setmalloctag(ns, getcallerpc(&s));

    return strcpy(ns, s);
}
