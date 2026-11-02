/* A file for mini-cc -facts: each way a pointer is made, moved, and
 * called through. What the author's pointer analysis then finds is in
 * pointers.out (run.sh). */
typedef struct Node Node;
struct Node {
	int	val;
	Node	*next;
	void	(*visit)(Node*);
};

int	x, y;
int	*gp = &x;
int	arr[4];
Node	root;

void	*malloc(unsigned long);

void	show(Node *n) { n->val = 1; }
void	hide(Node *n) { n->val = 0; }

/* a table of functions: a call through it reaches both */
void	(*table[])(Node*) = { show, hide };

int*
id(int *a)
{
	return a;
}

void
swap(int **a, int **b)
{
	int *t;

	t = *a;
	*a = *b;
	*b = t;
}

Node*
cons(int v, Node *rest)
{
	Node *n;

	n = malloc(sizeof(Node));
	n->val = v;
	n->next = rest;
	n->visit = show;
	return n;
}

void
walk(Node *l, void (*f)(Node*))
{
	for(; l != 0; l = l->next)
		f(l);
}

void
main(void)
{
	int *p, *q, *r;
	int **pp;
	Node *l;
	char *s;

	p = &x;
	q = &y;
	swap(&p, &q);
	pp = &p;
	r = id(*pp);
	r = &arr[2];
	s = "hello";
	l = cons(1, cons(2, 0));
	walk(l, hide);
	l->visit(l);
	(*table[0])(&root);
	gp = x ? p : q;
}
