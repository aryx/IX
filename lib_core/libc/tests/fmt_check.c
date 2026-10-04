/* tests/fmt.sh: ix/fmt.c against glibc, on random and chosen doubles.
 * usage: fmt_check [count] */
#include "host/u.h"
#include "../ix/fmt.c"
#undef snprint
#undef sprint
#undef strtod
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

static int bad;
static uint64_t seed = 88172645463325252ULL;
static uint64_t rnd(void) { seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17; return seed; }

static void
print1(char *f, double d)
{
	char a[2048], b[2048];

	snprintf(a, sizeof a, f, d);
	ix_snprint(b, sizeof b, f, d);
	if(strcmp(a, b) != 0 && bad++ < 20)
		printf("print %s of %a: glibc %s, ix %s\n", f, d, a, b);
}

static void
read1(char *s)
{
	char *e1, *e2;
	double a, b;

	a = strtod(s, &e1);
	b = ix_strtod(s, &e2);
	if((memcmp(&a, &b, sizeof a) != 0 && !(a != a && b != b)) || e1 != e2)
		if(bad++ < 20)
			printf("read %.60s: glibc %a (%d read), ix %a (%d)\n", s, a, (int)(e1-s), b, (int)(e2-s));
}

static char *fmts[] = {
	"%g", "%.12g", "%.15g", "%.17g", "%f", "%.0f", "%.1f", "%.3f", "%.10f", "%e", "%.0e", "%.3e", "%.20e", "%E", "%G",
	"%10.2f", "%-12.4e|", "%+g", "% g", "%010.3f", "%#.0f", "%#.0e", "%.0g", "%.1g", "%.40g", "%.100f", "%+.3e", "%-8.1f|", "%08.2g",
};

static void
all(double d)
{
	char s[2048];
	int i;
	static char *rf[] = { "%.17g", "%.16g", "%.18e", "%.3e", "%.25e", "%f", "%.800e", "%.1100f" };

	for(i = 0; i < sizeof fmts / sizeof fmts[0]; i++)
		print1(fmts[i], d);
	for(i = 0; i < sizeof rf / sizeof rf[0]; i++){
		snprintf(s, sizeof s, rf[i], d);
		read1(s);
	}
}

int
main(int argc, char **argv)
{
	static char *strs[] = {
		"0", "-0", "1", "1.", ".5", ".", "e5", "1e", "1e+", "1e5x", "  12.5abc", "+3.25", "-.0e9", "inf", "-Infinity", "INFx", "nan", "NaN(", "infinit",
		"1e400", "1e-400", "1e309", "1.7976931348623157e308", "1.7976931348623158e308", "1.7976931348623159e308",
		"179769313486231580793728971405303415079934132710037826936173778980444968292764750946649017977587207096330286416692887910946555547851940402630657488671505820681908902000708383676273854845817711531764475730270069855571366959622842914819860834936475292719074168444365510704342711559699508093042880177904174497791.9999999999999999999999999999999999999999999999999999999999999999999999",
		"179769313486231580793728971405303415079934132710037826936173778980444968292764750946649017977587207096330286416692887910946555547851940402630657488671505820681908902000708383676273854845817711531764475730270069855571366959622842914819860834936475292719074168444365510704342711559699508093042880177904174497792",
		"4.9e-324", "2.4703282292062327e-324", "2.4703282292062328e-324", "2.5e-324", "2.4e-324", "2.2250738585072011e-308", "2.2250738585072014e-308",
		"9007199254740993", "9007199254740992.5", "9007199254740993.0000000000000000000000000000000001", "0.1", "0.30000000000000004", "123456789012345678901234567890",
		"1e22", "1e23", "8.5", "0.000001", "100000000000000000000000000000000000000000000000000e-50", "0.00000000000000000000000000000000000001e38", "1e999999999999", "1e-999999999999",
		"1_000", "5e-1", "12e3", "1E5", "1.5e+3", "-1.5E-3",
	};
	double specials[] = { 0, -0.0, 1, -1, 0.5, 1.5, 2.5, 0.125, 9.5, 9.95, 99.5, 0.0001, 0.00001, 123456, 1234567, 1e15, 1e16, 1e17, 1e21, 1e22, 1e23, 1e100,
		1.7976931348623157e308, 2.2250738585072014e-308, 4.9e-324, 1.0/3, 2.0/3, 0.1, 0.2, 0.3, 1e-5, 9.999999e-5, 999999.5, 0.15, 0.25, 0.35, 5e-324*12345,
		1.0/0, -1.0/0, 0.0/0 };
	long i, n;
	uint64_t b;
	double d;

	n = argc > 1 ? atol(argv[1]) : 100000;
	for(i = 0; i < sizeof strs / sizeof strs[0]; i++)
		read1(strs[i]);
	for(i = 0; i < sizeof specials / sizeof specials[0]; i++)
		all(specials[i]);
	for(i = 0; i < n; i++){
		b = rnd();				/* any bits */
		memcpy(&d, &b, 8);
		all(d);
		all((double)(int64_t)(rnd() % 2000001 - 1000000) / 1000);	/* decimals */
		d = (double)(rnd() % 100000) * 0.01;
		all(d);
		b = (rnd() & 0x800fffffffffffffULL) | ((1023 + rnd() % 80 - 40) << 52);	/* the usual sizes */
		memcpy(&d, &b, 8);
		all(d);
		b = rnd() & 0x800fffffffffffffULL;	/* denormals */
		memcpy(&d, &b, 8);
		all(d);
	}
	printf("%ld doubles, %d differences\n", 5*n + (long)(sizeof specials / sizeof specials[0]), bad);
	return bad != 0;
}
