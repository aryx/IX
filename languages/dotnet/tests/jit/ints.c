/* ints.cs's methods as the JIT compiles them, called as C's functions
 * (5c's convention): the lines its Main prints (ints.expected). */
#include <u.h>
#include <libc.h>

extern int Ints_Gcd(int, int);
extern int Ints_Pow(int, int);
extern int Ints_Bits(int);
extern int Ints_Mix(int, int, int, int);
extern int Ints_Day(int);
extern int Ints_Below(unsigned, unsigned);
extern int Ints_Unsigned(int, int);
extern int Ints_Narrow(int);
extern int Ints_Clamp(int, int, int);
extern int Ints_Collatz(int);
extern int Ints_Ack(int, int);

void
jit_divide_by_zero(void)
{
	exits("DivideByZeroException");
}

static char *
truth(int b)
{
	return b ? "True" : "False";
}

void
main(void)
{
	char buf[512];
	int n;

	/* (ix's libc formats into a buffer only) */
	n = snprint(buf, sizeof buf, "%d\n%d\n%d %d\n%d\n%d %d\n%s %s\n%d\n%d %d\n%d %d %d\n%d\n%d\n",
		Ints_Gcd(1071, 462), Ints_Pow(3, 13), Ints_Bits(-1), Ints_Bits(255),
		Ints_Mix(7, -9, 12, 5), Ints_Day(2), Ints_Day(7),
		truth(Ints_Below(1, 3000000000U)), truth(Ints_Below(3000000000U, 1)),
		Ints_Unsigned(-7, 3), Ints_Narrow(0x1ff80), Ints_Narrow(-1),
		Ints_Clamp(-5, 0, 9), Ints_Clamp(50, 0, 9), Ints_Clamp(4, 0, 9),
		Ints_Collatz(27), Ints_Ack(2, 3));
	write(1, buf, n);
	exits(nil);
}
