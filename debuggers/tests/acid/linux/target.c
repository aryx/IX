/* the program mini-acid debugs on Linux (debuggers/tests/acid_linux.sh),
 * compiled by gcc: its breakpoints, its stack by the frame pointers,
 * its values by mini-cc -m 7 -a's declarations (gcc's layout and 7c's
 * are arm64's, AAPCS64's). No #include: gcc's and mini-cc's alike */

typedef struct Point Point;
struct Point {
	int x;
	int y;
};

typedef struct Node Node;
struct Node {
	char *name;
	Point p;
	Node *next;
	unsigned char c;
	short s;
};

Node n2 = { "two", { 3, 4 }, 0, 'b', -2 };
Node n1 = { "one", { 1, 2 }, &n2, 'a', 7 };
static int counter = 3;

static int
leaf(int a)
{
	return a * 2 + counter;
}

int
walk(Node *n, int k)
{
	Point q;

	q = n->p;
	return leaf(q.x + q.y + k);
}

int
main(void)
{
	return walk(&n1, 10) + walk(n1.next, 20) == 0;
}
