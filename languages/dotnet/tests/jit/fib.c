/* Fib's methods as the JIT compiles them (mini-dotnet -S -jit fib.dll,
 * assembled by mini-asm): called as C's functions, as their code is
 * 5c's convention. It prints what survey/programs/fib.expected says
 * (tests/run.sh's jit job). */
#include <u.h>
#include <libc.h>

extern int Fib_Rec(int);
extern int Fib_Loop(int);

/* the runtime's, for a division by zero: not reached here */
void
jit_divide_by_zero(void)
{
	exits("DivideByZeroException");
}

void
main(void)
{
	char buf[64];
	int n;

	/* (ix's libc formats into a buffer only) */
	n = snprint(buf, sizeof buf, "%d\n%d\n%d\n", Fib_Rec(20), Fib_Loop(40), Fib_Loop(47));
	write(1, buf, n);
	exits(nil);
}
