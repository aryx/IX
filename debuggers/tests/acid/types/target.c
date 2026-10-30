#include <u.h>
#include <libc.h>

/* the program mini-acid prints the values of, by their types
 * (debuggers/tests/acid_proc.sh): target.acid is what 5c -a writes of
 * it, the structs as acid's aggr */

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
	uchar c;
	short s;
};

Node n2 = { "two", { 3, 4 }, nil, 'b', -2 };
Node n1 = { "one", { 1, 2 }, &n2, 'a', 7 };

int
walk(Node *n, int k)
{
	Point q;

	q = n->p;
	return q.x + q.y + k;
}

void
main(void)
{
	int t;

	t = walk(&n1, 10) + walk(n1.next, 20);
	exits(t == 40 ? nil : "wrong");
}
