void	*malloc(unsigned long);
void	free(void*);

typedef struct Op Op;
struct Op { char *name; int (*run)(int); };

int	twice(int x) { return 2*x; }
int	square(int x) { return x*x; }
int	negate(int x) { return -x; }

Op	ops[] = { { "twice", twice }, { "square", square } };

int
apply(Op *o, int x)
{
	return o->run(x);
}

int
main(void)
{
	char *s = "done";

	apply(&ops[1], 3);
	free(s);
	return 0;
}
