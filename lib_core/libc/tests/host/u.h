/* the host's u.h for tests/fmt.sh: ix/fmt.c compiled by gcc beside glibc */
#include <stdarg.h>
#include <string.h>
typedef unsigned long long uvlong;
typedef long long vlong;
typedef unsigned int uint;
typedef unsigned long ulong;
#define nil ((void*)0)
#define USED(x) ((void)(x))
#define snprint ix_snprint
#define sprint ix_sprint
#define vsnprint ix_vsnprint
#define strtod ix_strtod
#define NaN ix_NaN
#define Inf ix_Inf
#define isNaN ix_isNaN
#define isInf ix_isInf
