// Claude Code, Copyright (C) 2026 Yoann Padioleau, LGPL (see TinyC.ml)
//
// paint: TinyKernel.ml's program that draws. The mouse paints with a
// button down (the left one black, the middle one red, the right one
// white), a ball goes across the top by the clock, c clears, q quits.
// One loop waiting for the three at once: ready on the mouse and the
// keys, until the ball's next move. Its pixels are the kernel's: it
// writes messages to its descriptor 3 (draw.h) and reads its mouse, 4:
// the screen's, or its window's.
#include "user.h"
#include "draw.h"

enum { Grey = 1, Black, Red, White, Blue, Yellow, Period = 50 };

void
clear(void)
{
	d_fill(SCREEN, Grey, 0, 0, 640, 480);
	d_fill(SCREEN, Blue, 0, 0, 640, 20);
	d_text(SCREEN, White, 8, 2, "paint: the mouse paints with a button down; c clears, q quits");
	d_line(SCREEN, Black, 0, 60, 639, 60);
}

void
main(void)
{
	int m[3], fds[2], mouse, k, x, dx, next, ink;
	char c;

	mouse = MOUSE;
	d_colour(Grey, GREY); d_colour(Black, BLACK); d_colour(Red, RED);
	d_colour(White, WHITE); d_colour(Blue, BLUE); d_colour(Yellow, YELLOW);
	clear();
	fds[0] = mouse;
	fds[1] = 0;
	x = 0;
	dx = 4;
	next = ticks() + Period;
	for(;;){
		if(d_flush() < 0)
			exit(1);
		k = ready(fds, 2, next);
		if(k == mouse){
			if(read(mouse, (char*)m, 12) != 12)
				break;
			ink = m[2] & 1 ? Black : m[2] & 2 ? Red : m[2] & 4 ? White : 0;
			if(ink && m[1] > 60)
				d_fill(SCREEN, ink, m[0] - 4, m[1] - 4, m[0] + 4, m[1] + 4);
		} else if(k == 0){
			if(read(0, &c, 1) != 1 || c == 'q')
				break;
			if(c == 'c')
				clear();
		} else {
			// the ball: a square of 16, between the title and the line
			d_fill(SCREEN, Grey, x, 32, x + 16, 48);
			if(x + dx < 0 || x + dx > 624)
				dx = -dx;
			x += dx;
			d_fill(SCREEN, Yellow, x, 32, x + 16, 48);
			// (from now, not from when it was due: a ball that is late
			// does not run to catch up, and flood who shows it)
			next = ticks() + Period;
		}
	}
	exit(0);
}
