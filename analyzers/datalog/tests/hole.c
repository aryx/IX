/* The hole object sensitivity had in C (object1.dl): a call is followed in
 * the context of its first argument's object, so a first argument with no
 * object in any context reached was not followed at all, when the first
 * pass, which also reads dead code, said it has one. Here that first pass
 * sees via given &x by never_called, which never runs; the only run gives
 * it 0. dynamic.sh -c: target runs, so an analysis must reach it. */
int	x;
int	ran;

void
target(void)
{
	ran = 1;
}

void
sink(int *p)
{
	if(p == 0)
		target();
}

void
via(int *p)
{
	sink(p);
}

void
never_called(void)
{
	via(&x);
}

int
main(void)
{
	via(0);
	return ran == 1 ? 0 : 1;
}
