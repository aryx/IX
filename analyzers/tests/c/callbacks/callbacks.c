/* function pointers set at run time: returned, stored in the heap,
 * passed as a callback */
typedef struct Timer Timer;
struct Timer {
	int	when;
	void	(*fire)(Timer*);
	Timer	*next;
};

void	*malloc(unsigned long);

Timer	*timers;

void	ring(Timer *t) { t->when = 0; }
void	blink(Timer *t) { t->when = 1; }
void	tick(Timer *t) { t->when++; }

void	(*choose(int loud))(Timer*)
{
	if(loud)
		return ring;
	return blink;
}

void
add(int when, void (*f)(Timer*))
{
	Timer *t;

	t = malloc(sizeof(Timer));
	t->when = when;
	t->fire = f;
	t->next = timers;
	timers = t;
}

void
each(void (*visit)(Timer*))
{
	Timer *t;

	for(t = timers; t != 0; t = t->next)
		visit(t);
}

void
run(void)
{
	Timer *t;

	for(t = timers; t != 0; t = t->next)
		t->fire(t);
}

void
main(void)
{
	add(10, choose(1));
	add(20, choose(0));
	each(tick);
	run();
}
