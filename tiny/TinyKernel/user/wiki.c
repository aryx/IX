// Claude Code, Copyright (C) 2026 Yoann Padioleau, LGPL (see TinyC.ml)
//
// wiki words...: what the other end of the wire has on those words: a
// text, on the standard output, and a picture, painted on the screen
// (or in its window) a row at a time, as its packets arrive. A
// connection to port 70 as get's, the line "wiki words"; the first
// message back is "t w h": t messages of text follow, then h rows of w
// pixels, each row a message of IL's and a message of TinyKernelGraphics's
// (draw.h's d_pixels), written at once: nothing here looks for where a
// row ends. The picture's top left corner is the screen's (8, 8).
#include "user.h"
#include "draw.h"

char buf[1024];

// the number at *s, s after it and the spaces
int
number(char **s)
{
	int n;

	n = 0;
	while(**s >= '0' && **s <= '9')
		n = n * 10 + *(*s)++ - '0';
	while(**s == ' ')
		(*s)++;
	return n;
}

void
main(int argc, char *argv[])
{
	char line[128], *p;
	int fd, i, n, t, w, h, y;

	if(argc < 2){
		print("usage: wiki words...\n");
		exit(1);
	}
	n = 0;
	for(p = "wiki"; *p; p++)
		line[n++] = *p;
	for(i = 1; i < argc; i++){
		line[n++] = ' ';
		for(p = argv[i]; *p && n < 126; p++)
			line[n++] = *p;
	}
	fd = dial("10.0.0.1", 70);
	if(fd < 0){
		print("wiki: nothing answers at 10.0.0.1\n");
		exit(1);
	}
	write(fd, line, n);
	n = read(fd, buf, 1023);
	if(n <= 0){
		print("wiki: no answer\n");
		exit(1);
	}
	buf[n] = 0;
	p = buf;
	t = number(&p);
	w = number(&p);
	h = number(&p);
	for(i = 0; i < t && (n = read(fd, buf, 1024)) > 0; i++)
		write(1, buf, n);
	for(y = 0; y < h && (n = read(fd, buf, 1024)) > 0; y++){
		d_pixels(SCREEN, 8, 8 + y, buf, n < w ? n : w);
		if(d_flush() < 0)
			exit(1);
	}
	exit(y < h);
}
