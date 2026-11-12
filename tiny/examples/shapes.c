// Claude Code, Copyright (C) 2026 Yoann Padioleau, LGPL (see TinyC.ml)
//
// shapes: a program that draws, in /examples on tiny-kernel, the
// smallest one: a few rectangles, lines and a text, then a key quits.
// Its pixels are the kernel's: draw.o gathers the messages (draw.h),
// d_flush writes them to its descriptor 3, the screen, or its window
// when windows runs it. The Buildfile beside it builds it, with
// /lib/c's runtime and draw.o:
//
//	cd /examples; build shapes; ./shapes
//	trace ./shapes          its writes of the messages, on 3
#include "user.h"
#include "draw.h"

// a colour is an image of one pixel, its number the program's own
enum { Grey = 1, Black, Red, Blue, Yellow, White };

void
main(void)
{
	int i;
	char c;

	d_colour(Grey, GREY); d_colour(Black, BLACK); d_colour(Red, RED);
	d_colour(Blue, BLUE); d_colour(Yellow, YELLOW); d_colour(White, WHITE);

	d_fill(SCREEN, Grey, 0, 0, 1024, 768);
	d_fill(SCREEN, Blue, 0, 0, 1024, 20);
	d_text(SCREEN, White, 8, 2, "shapes: a key quits");

	// a red square in a black frame, and the sun
	d_fill(SCREEN, Black, 96, 96, 264, 264);
	d_fill(SCREEN, Red, 100, 100, 260, 260);
	d_fill(SCREEN, Yellow, 400, 80, 480, 160);

	// a fan of lines from a corner
	for(i = 0; i <= 8; i++)
		d_line(SCREEN, Black, 320, 440, 320 + 40 * i, 300);

	d_text(SCREEN, Black, 100, 280, "hello, world, in pixels");
	if(d_flush() < 0){
		print("shapes: no screen\n");
		exit(1);
	}
	read(0, &c, 1);
	exit(0);
}
