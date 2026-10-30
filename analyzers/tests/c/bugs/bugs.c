/* bugs the pointer analysis shows, and what looks like them but is not */
void	*malloc(unsigned long);
void	free(void*);

typedef struct Buf Buf;
struct Buf {
	char	*data;
	int	n;
};

char	table[16];
Buf	global;
void	(*onerror)(char*);

char*
fresh(int n)
{
	return malloc(n);
}

char*
scratch(void)
{
	char tmp[32];

	return tmp;		/* the frame's: gone when scratch returns */
}

int*
counter(void)
{
	static int count;

	return &count;		/* a static: no bug */
}

int*
pick(int which, int *p)
{
	int mine;

	if(which)
		return p;
	return &mine;		/* the frame's */
}

void
release(Buf *b)
{
	free(b->data);
}

void
main(void)
{
	Buf b;
	char *s;
	int x;

	b.data = fresh(10);
	release(&b);		/* the heap's: no bug */
	global.data = table;
	release(&global);	/* table is no heap */
	s = "hello";
	free(s);		/* a string */
	free(scratch());
	pick(1, &x);
	onerror("no handler");	/* nothing ever put in onerror */
}
