/* variables live across calls, in loops and round a test, and those
 * no register may hold (an address taken) */
int twice(int x) { return x + x; }

int sum(int n)
{
	int i, s, unused;

	s = 0;
	unused = n;
	for(i = 0; i < n; i++)
		s = s + twice(i);
	return s;
}

int pick(int a, int b, int c)
{
	int r;

	if(a > 0)
		r = twice(b);
	else
		r = c;
	return r + a;
}

void set(int *p) { *p = 1; }

int taken(void)
{
	int x, y;

	y = 2;
	set(&x);
	return x + y;
}
