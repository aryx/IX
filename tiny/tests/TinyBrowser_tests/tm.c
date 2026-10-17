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

// tiny-kernel's calls, which the browser's screen part names
// (TinyBrowser.browse, calls.ml's externals). The test does not draw, so
// here they do nothing: no screen, no keys, no network.
value u_write(value fd, value s) { return 1; }
value u_read(value fd, value n) { return string_alloc(0); }
value u_ready(value fds, value n, value until) { return -1 * 2 + 1; }
value u_ticks(value unit) { return 1; }
value u_dial(value address, value port) { return -1 * 2 + 1; }
value u_close(value fd) { return 1; }

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
	ml_run(vstack, space0, space1, 88000, 65536);
	flush();
	exit(0);
}
