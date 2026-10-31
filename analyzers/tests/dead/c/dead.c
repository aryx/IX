/* mini-analyze -dead: what is dead, and what only looks it. */
void	qsort(void*, int, int, int (*)(void*, void*));
void	exits(char*);

int	used, unused_global = 1;

/* called by name */
int	direct(void) { return used; }

/* no line calls these by name: a call through a pointer reaches them */
void	onlyptr(void) { used = 1; }
void	intable(void) { used = 2; }
void	(*table[])(void) = { intable };

/* given to a C function with no body: taken as called */
int	cmp(void *a, void *b) { return 0; }

/* its address taken and kept, and no call through it */
void	orphan(void) { used = 3; }

/* nothing names it */
void	unused(void) { used = 4; }

/* only dead code calls it; two that keep each other are dead too */
void	onlybydead(void) { used = 5; }
void	deadcaller(void) { onlybydead(); }
void	ping(void);
void	pong(void) { ping(); }
void	ping(void) { pong(); }

typedef struct S S;
struct S {
	int	*read;
	int	*neverread;
};

int
jumps(int x)
{
	if(x)
		return 1;
	return 2;
	used = 6;		/* dead */
}

void
main(void)
{
	void (*f)(void);
	void (*kept)(void);
	S s;
	int *r;

	f = onlyptr;
	f();
	table[0]();
	kept = orphan;
	s.read = &used;
	s.neverread = &used;
	r = s.read;
	direct();
	jumps(1);
	qsort(0, 0, 0, cmp);
	exits(0);
}
