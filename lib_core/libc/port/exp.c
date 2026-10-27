/* Plan 9's, by principia and goken (libc's README.md; LICENSE). */
/*
    exp returns the exponential function of its
    floating-point argument.

    The coefficients are #1069 from Hart and Cheney. (22.35D)
*/

#include    <u.h>
#include    <libc.h>
#define p0  .2080384346694663001443843411e7
#define p1  .3028697169744036299076048876e5
#define p2  .6061485330061080841615584556e2
#define q0  .6002720360238832528230907598e7
#define q1  .3277251518082914423057964422e6
#define q2  .1749287689093076403844945335e4
#define log2e  1.4426950408889634073599247
#define sqrt2  1.4142135623730950488016887
#define maxf  10000

double
exp(double arg)
{
    double fract, temp1, temp2, xsq;
    int ent, e;
    FPdbleword r;

    if(arg == 0)
        return 1;
    if(arg < -maxf)
        return 0;
    if(arg > maxf)
        return Inf(1);

    arg *= log2e;
    /* ix: floor and ldexp without their calls, the same bits: arg is
     * within 14,427 of 0 here, so the cast and one step down are floor;
     * and the result's exponent moved by ent in its bits is ldexp's own
     * way when the result is a normal number (ldexp then for the rest).
     * exp is 200 instructions a call on arm, half of them in floor,
     * modf and ldexp; the mixer's tanh calls it twice a sample
     * (plan_virtuaracing.md, stage 5).
     * old: ent = floor(arg); ...; return ldexp(r, ent); */
    ent = arg;
    if(ent > arg)
        ent--;
    fract = (arg-ent) - 0.5;
    xsq = fract*fract;
    temp1 = ((p2*xsq+p1)*xsq+p0)*fract;
    temp2 = ((xsq+q2)*xsq+q1)*xsq + q0;
    r.x = sqrt2*(temp2+temp1)/(temp2-temp1);
    e = ((r.hi >> 20) & 0x7ff) + ent;
    if(e < 1 || e >= 0x7ff)
        return ldexp(r.x, ent);
    r.hi = (r.hi & ~(0x7ffL << 20)) | ((long)e << 20);
    return r.x;
}
