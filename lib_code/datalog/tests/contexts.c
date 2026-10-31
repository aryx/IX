/* What each pointer analysis can tell apart (lib_code/datalog/points_to),
 * a question a part; run.sh asks, contexts_c.out says. */
void	*malloc(unsigned long);

typedef struct Box Box;
struct Box {
	int	*v;
	void	(*fn)(int*);
};

int	x, y, u, w;
int	*p1, *p2, *q1, *q2, *r1, *r2, *f1, *f2, *o1, *o2, *n1, *n2;

/* one level: one call site is enough */
int*
id(int *a)
{
	return a;
}

/* two levels: two call sites */
int*
id2(int *a)
{
	return id(a);
}

/* a wrapper of malloc: an object known by its caller */
Box*
newbox(void)
{
	return malloc(sizeof(Box));
}

void
set(Box *b, int *v)
{
	b->v = v;
}

int*
get(Box *b)
{
	return b->v;
}

/* three levels to set: too many call sites; one object all the way */
void
set2(Box *b, int *v)
{
	set(b, v);
}

void
set3(Box *b, int *v)
{
	set2(b, v);
}

/* a pointer to a function, given and called */
void
fone(int *a)
{
	f1 = a;
}

void
ftwo(int *a)
{
	f2 = a;
}

void
run(void (*fn)(int*), int *a)
{
	fn(a);
}

void
main(void)
{
	Box *b1, *b2, *d1, *d2, *s1, *s2;
	Box own1, own2;

	p1 = id(&x);
	p2 = id(&y);

	q1 = id2(&x);
	q2 = id2(&y);

	b1 = newbox();
	b2 = newbox();
	b1->v = &x;
	b2->v = &y;
	r1 = b1->v;
	r2 = b2->v;

	s1 = newbox();
	s2 = malloc(sizeof(Box));
	set3(s1, &u);
	set3(s2, &w);
	o1 = get(s1);
	o2 = get(s2);

	/* by object, not by field's name */
	own1.v = &x;
	own2.v = &y;
	n1 = own1.v;
	n2 = own2.v;

	run(fone, &x);
	run(ftwo, &y);
}
