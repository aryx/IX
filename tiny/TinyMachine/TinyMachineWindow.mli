(* tiny-machine's window. tiny-machine -window runs it as a separate
 * program (TinyMachine.ml says why): this one links SDL, through
 * TinyMachineSDL, while tiny-machine links no C at all. The window
 * knows nothing of the machine. It shows the pictures it reads on its
 * standard input, each a PPM (P6: a header of three lines, then red,
 * green and blue bytes), and writes what the user does in the window
 * on its standard output, one event per line:
 *
 *     m x y buttons    the mouse's position and its buttons (1 left,
 *                      2 middle, 4 right, as in Plan 9)
 *     k \ddd           a key typed, as its byte (a step of the wheel
 *                      becomes an arrow key, up or down)
 *
 * Between two pictures, the input may also contain:
 * - a line "C n", which sets the mouse cursor: 0 is the arrow, 1 a
 *   hand. A program of the machine asked for it by writing to the
 *   mouse's word (www does it when the mouse is over a link);
 * - a line "A n" followed by n bytes, the speaker's samples since the
 *   last such line, which the window plays (TinyMachineSDL's play).
 *
 * The program ends when its input ends or its window is closed. The
 * window starts at the largest whole multiple of the picture's size
 * that fits in three quarters of the screen's height. It can be
 * resized: the picture is then drawn as large as fits, and the mouse's
 * position is still given in the picture's pixels.
 *
 *     tiny-machine  --- one PPM per frame, on a pipe -->  this program
 *     (no C linked) <-- one event per line, on a pipe --  (SDL)
 *
 * design:
 * Making the display a separate program on two pipes costs a megabyte
 * copied per frame, and buys three things:
 * - tiny-machine stays a program in OCaml alone, built by mini-ml, and
 *   runs where there is no SDL;
 * - the event lines are the same ones a recorded session has
 *   (tiny-machine -events), so a test and a person drive the machine
 *   the same way;
 * - any program that reads PPMs and writes such lines can be a
 *   display.
 * It is the shape of Plan 9's terminals and of a web page's canvas
 * (TinyMachineWeb): the picture on one side, and what computes it on
 * the other. *)
