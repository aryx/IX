/* The example of lib_code/datalog/FACTS.md: each kind of fact mini-cc says. */
void	*malloc(unsigned long);

typedef struct Node Node;
struct Node {
	int	*val;
	Node	*next;
};

int	x;
int	*gp = &x;
int	table[4];
void	(*handler)(int*);

int*
id(int *a)
{
	return a;
}

void
show(int *p)
{
	*p = 1;
}

Node*
cons(int *v, Node *rest)
{
	Node *n;

	n = malloc(sizeof(Node));
	n->val = v;
	n->next = rest;
	return n;
	n = 0;
}

/* the -flow facts are shown of this one */
int
sum(int n)
{
	int s;

	s = 0;
	while(n > 0){
		s = s + n;
		n = n - 1;
	}
	return s;
}

void
main(void)
{
	int y;
	int *p, **pp;
	char *s;
	Node *l;

	p = &y;
	pp = &p;
	*pp = id(&x);
	p = *pp;
	s = "hello";
	p = &table[1];
	p = table[2] ? p : 0;
	l = cons(p, 0);
	p = l->val;
	pp = &l->val;
	handler = show;
	handler(p);
	sum(3);
}
