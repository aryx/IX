/* Plan 9's, by principia and goken (libc's README.md; LICENSE). */
#include    <u.h>
#include    <libc.h>
/*
 * floor and ceil-- greatest integer <= arg
 * (resp least >=)
 */
double
floor(double d)
{
    double fract;

    if(d < 0) {
        fract = modf(-d, &d);
        if(fract != 0.0)
            d += 1;
        d = -d;
    } else
        modf(d, &d);
    return d;
}
double
ceil(double d)
{
    return -floor(-d);
}
