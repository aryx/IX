(* tiny-machine's window (tiny-machine -window runs it; TinyMachine.ml
 * says why it is a program apart: this one links SDL, by mini-qemu's
 * Sdl_display, and that one nothing of C's). It knows nothing of the
 * machine: it shows the pictures it reads on its standard input, each
 * a PPM (P6: a header's three lines, then red, green and blue bytes),
 * and writes what is done in the window on its standard output, an
 * event a line:
 *
 *     m x y buttons    the mouse's place, and its buttons (1 left, 2
 *                      middle, 4 right, as Plan 9's)
 *     k \ddd           a key typed, its byte
 *
 * Its input's end, or its window closed, is its end. The window starts
 * at the largest whole number of times the picture that three quarters
 * of the screen's height hold, and can be resized: the picture is
 * drawn as large as fits, and the mouse's place is still in the
 * picture's pixels.
 *
 *     tiny-machine  --- a PPM a frame, on a pipe -->  this program
 *     (no C linked) <-- an event a line, on a pipe --  (SDL)
 *
 * design:
 * A display as a separate program on two pipes costs a megabyte
 * copied a frame and buys three things: tiny-machine stays a program
 * of OCaml alone, built by mini-ml and run where there is no SDL;
 * the events' lines are the same ones a recorded session has
 * (tiny-machine -events), so a test and a person drive the machine
 * the same way; and any program that reads PPMs and writes such
 * lines is a display. It is the shape of Plan 9's terminals and of
 * a web page's canvas (TinyMachineWeb), the picture on one side and
 * what computes it on the other. *)

(* A program: it reads its standard input until its end, and gives
 * nothing to another file. *)
