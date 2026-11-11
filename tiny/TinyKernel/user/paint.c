// Claude Code, Copyright (C) 2026 Yoann Padioleau, LGPL (see TinyC.ml)
//
// paint: TinyKernel.ml's program that draws. The mouse paints with a
// button down (the left one black, the middle one red, the right one
// white), a ball goes across the top by the clock, c clears, q quits.
// The ball's place is the clock's: 4 pixels a period since the boot,
// back and forth, so the screen at a time does not depend on when
// paint started (old: 4 pixels a move since paint started, the ball a
// few pixels further when the boot was longer, its test's screen
// recorded again after changes elsewhere).
// One loop waiting for the three at once: ready on the mouse and the
// keys, until the ball's next move. Its pixels are the kernel's: it
// writes messages to its descriptor 3 (draw.h) and reads its mouse, 4:
// the screen's, or its window's.
#include "../libc/user.h"
#include "../libc/draw.h"

enum { Grey = 1, Black, Red, White, Blue, Yellow, Period = 50 };

// the ball's x at the n-th period: 0 to 1008 and back, 4 pixels a step
int
ball(int n)
{
	n = n % 504;
	return 4 * (n < 252 ? n : 504 - n);
}

void
clear(void)
{
	d_fill(SCREEN, Grey, 0, 0, 1024, 768);
	d_fill(SCREEN, Blue, 0, 0, 1024, 20);
	d_text(SCREEN, White, 8, 2,
		"paint: the mouse paints with a button down; c clears, q quits");
	d_line(SCREEN, Black, 0, 60, 1023, 60);
}

void
main(void)
{
	int m[3], fds[2], mouse, k, x, next, ink;
	char c;

	mouse = MOUSE;
	d_colour(Grey, GREY); d_colour(Black, BLACK); d_colour(Red, RED);
	d_colour(White, WHITE); d_colour(Blue, BLUE); d_colour(Yellow, YELLOW);
	clear();
	fds[0] = mouse;
	fds[1] = 0;
	x = ball(ticks() / Period);
	next = (ticks() / Period + 1) * Period;
	for(;;){
		if(d_flush() < 0)
			exit(1);
		k = ready(fds, 2, next);
		if(k == mouse){
			if(read(mouse, (char*)m, 12) != 12)
				break;
			ink = m[2] & 1 ? Black : m[2] & 2 ? Red :
				m[2] & 4 ? White : 0;
			if(ink && m[1] > 60)
				d_fill(SCREEN, ink, m[0] - 4, m[1] - 4,
					m[0] + 4, m[1] + 4);
		} else if(k == 0){
			if(read(0, &c, 1) != 1 || c == 'q')
				break;
			if(c == 'c')
				clear();
		} else {
			// the ball: a square of 16, between the title and the line
			d_fill(SCREEN, Grey, x, 32, x + 16, 48);
			x = ball(ticks() / Period);
			d_fill(SCREEN, Yellow, x, 32, x + 16, 48);
			// (the next period's start: a ball that is late jumps to
			// its place, one move drawn, not each one it missed)
			next = (ticks() / Period + 1) * Period;
		}
	}
	exit(0);
}
