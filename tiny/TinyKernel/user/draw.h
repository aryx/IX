// Claude Code, Copyright (C) 2026 Yoann Padioleau, LGPL (see TinyC.ml)
//
// What a program that draws has (draw.c): TinyGraphics.ml's messages,
// gathered and written to /draw. The kernel has the pixels; an image is
// a number of the program's, 0 the screen (640 by 480); a colour is an
// image of one pixel that repeats, its byte one of Plan 9's 256.

#define SCREEN 0
#define NOMASK (-1)
#define BLACK 0
#define WHITE 255
#define GREY 0xaa
#define RED 0xf0
#define GREEN 0x3f
#define BLUE 0x36
#define YELLOW 0xfc

// /draw opened; -1 without one
int d_open(void);
// the messages gathered, written; -1 if the kernel refused one
int d_flush(void);
// an image of that rectangle, filled with a colour's byte; a colour
void d_image(int id, int x0, int y0, int x1, int y1, int colour);
void d_colour(int id, int colour);
void d_free(int id);
// dst's rectangle: src's pixels from (px, py), where mask's are set
void d_draw(int dst, int src, int mask, int x0, int y0, int x1, int y1, int px, int py);
// a rectangle of a colour
void d_fill(int dst, int src, int x0, int y0, int x1, int y1);
void d_line(int dst, int src, int x0, int y0, int x1, int y1);
// a text (a character is 8 by 16), its top left corner at (x, y)
void d_text(int dst, int src, int x, int y, char *s);
