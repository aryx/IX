/* Plan 9's, by principia and goken (libc's README.md; LICENSE). */
#include    <u.h>
#include    <libc.h>
double
fabs(double arg)
{

    if(arg < 0)
        return -arg;
    return arg;
}
