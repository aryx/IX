// Claude Code, Copyright (C) 2026 Yoann Padioleau, LGPL (see TinyC.ml)
//
// The C side of TinyBrowser.ml on tiny-cpu (TinyBrowser_test.sh): it
// gives ML's runtime its memory, and defines the two externals that
// Tm.ml uses: the width (the first argument) and reading a message
// from the standard input. The memory itself is in heap.c, which is
// linked last: large arrays between the start and main would put main
// out of reach of the start's call.
#include "../../TinyMLRuntime/core.c"

extern int read(int, char*, int);
extern value vstack[], space0[], space1[];

static char buf[4096];
static int width = 80;

value
www_width(value unit)
{
	return width * 2 + 1;
}

// up to n bytes of the standard input; "" at its end
value
www_read(value n)
{
	value s;
	int k, i;

	n = n >> 1;
	if(n > sizeof buf)
		n = sizeof buf;
	k = read(0, buf, n);
	if(k < 0)
		k = 0;
	s = string_alloc(k);
	for(i = 0; i < k; i++)
		((uchar*)s)[i] = buf[i];
	return s;
}

void
main(int argc, char **argv)
{
	if(argc > 1)
		width = atoi(argv[1]);
	ml_run(vstack, space0, space1, 90000, 65536);
	flush();
	exit(0);
}
