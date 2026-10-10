(* mini-xv6's console on the framebuffer (xv6 arm-pi1's gpuputc and
 * initframebuf, pixel for pixel): 1024 x 768, 16 bits a pixel, asked of
 * the VideoCore on the mailbox's channel 1 (both boards: machine.c); a
 * character an 8 x 16 cell of xv6's font (font1.bin), 15 rows drawn,
 * white on black; the cell cleared first (a space: only that); a
 * newline (or the right edge) the next row, the screen scrolled up a
 * row at the bottom and its last row's cells cleared. Everything the
 * console prints, the kernel's messages and the programs' output, is
 * drawn: the screen shows the serial console's last 48 lines, as
 * arm-pi1's C kernel's does.
 *
 * 1024 / 8 by 768 / 16: 128 columns of 48 lines. A character's
 * picture is 16 bytes of the font, a byte a row, bit 0 the leftmost
 * pixel; A, where the font has it:
 *
 *     font.[65 * 16 + k], k = 0..14    a row of 8 pixels, each
 *                                      written as 2 bytes, 0xffff
 *                                      or 0, at fb + y * pitch + 2x
 *
 * It installs itself as Machine.screen, which Machine.print calls
 * after the UART for each character: nothing above knows there is a
 * screen. Scrolling copies the framebuffer up by a row of cells,
 * which is why a console of pixels is slow: 1.5 MB moved at each
 * line past the last.
 *
 * others:
 * The PC had this in hardware: in the VGA's text mode a character's
 * code and its colour are two bytes written at 0xB8000, the card
 * holding the font, and xv6's x86 console is those few lines. A
 * board with a framebuffer only, as the Pi and every machine since,
 * draws its letters. mini-oberon's are Oberon's own proportional
 * ones, of any width, read from a file (its Fonts). *)

(* the framebuffer asked for, the console drawn there from now on
 * (Machine.screen); nothing when there is none *)
val init : unit -> unit

(* the mouse moved (dx, dy; its buttons): the cursor, an arrow drawn by
 * inverting the pixels under it, moved there within the screen (shown
 * from the first move on; hidden while the console draws) *)
val pointer : int -> int -> int -> unit
