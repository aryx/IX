// Claude Code, Copyright (C) 2026 Yoann Padioleau, LGPL (see TinyC.ml)
//
// draw.h's functions: each a message of TinyGraphics.ml's (a letter,
// then numbers of 16 bits, the low byte first) put in a buffer, which
// d_flush writes whole, as the kernel wants its messages.
#include "user.h"
#include "draw.h"

char d_buf[2048];
int d_n, d_fd;

int
d_open(void)
{
	d_n = 0;
	return d_fd = open("/draw", O_WRONLY);
}

int
d_flush(void)
{
	int n;

	n = d_n;
	d_n = 0;
	return n > 0 && write(d_fd, d_buf, n) != n ? -1 : 0;
}

// room for a message of n bytes, its letter put
void
d_start(int letter, int n)
{
	if(d_n + n > sizeof d_buf)
		d_flush();
	d_buf[d_n++] = letter;
}

void
d_put(int v)
{
	d_buf[d_n++] = v;
	d_buf[d_n++] = v >> 8;
}

void
d_image(int id, int x0, int y0, int x1, int y1, int colour)
{
	d_start('a', 15);
	d_put(id); d_put(x0); d_put(y0); d_put(x1); d_put(y1); d_put(0); d_put(colour);
}

void
d_colour(int id, int colour)
{
	d_start('a', 15);
	d_put(id); d_put(0); d_put(0); d_put(1); d_put(1); d_put(1); d_put(colour);
}

void
d_free(int id)
{
	d_start('f', 3);
	d_put(id);
}

void
d_draw(int dst, int src, int mask, int x0, int y0, int x1, int y1, int px, int py)
{
	d_start('d', 19);
	d_put(dst); d_put(src); d_put(mask); d_put(x0); d_put(y0); d_put(x1); d_put(y1); d_put(px); d_put(py);
}

void
d_fill(int dst, int src, int x0, int y0, int x1, int y1)
{
	d_draw(dst, src, NOMASK, x0, y0, x1, y1, 0, 0);
}

void
d_line(int dst, int src, int x0, int y0, int x1, int y1)
{
	d_start('l', 13);
	d_put(dst); d_put(src); d_put(x0); d_put(y0); d_put(x1); d_put(y1);
}

void
d_text(int dst, int src, int x, int y, char *s)
{
	int n;

	n = strlen(s);
	d_start('s', 11 + n);
	d_put(dst); d_put(src); d_put(x); d_put(y); d_put(n);
	while(*s)
		d_buf[d_n++] = *s++;
}
