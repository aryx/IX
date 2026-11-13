(* This is mini-xv6's console on the framebuffer, pixel for pixel the
 * one of xv6 arm-pi1's gpuputc and initframebuf. The screen is 1024 x
 * 768, at 16 bits a pixel, and is asked of the VideoCore on the
 * mailbox's channel 1 (on both boards, by machine.c). Each character is
 * an 8 x 16 cell of xv6's font (font1.bin), of which 15 rows are drawn,
 * white on black. The cell is cleared first, and for a space that is
 * all that is done. A newline, or reaching the right edge, moves to the
 * next row; at the bottom, the screen scrolls up a row and the cells of
 * its last row are cleared. Everything the console prints, the kernel's
 * messages and the programs' output, is drawn, so the screen shows the
 * serial console's last 48 lines, as arm-pi1's C kernel does.
 *
 * 1024 / 8 by 768 / 16 gives 128 columns and 48 lines. A character's
 * picture is 16 bytes of the font, one byte for each row, with bit 0
 * the leftmost pixel. Here is A, where the font has it:
 *
 *     font.[65 * 16 + k], k = 0..14    a row of 8 pixels, each
 *                                      written as 2 bytes, 0xffff
 *                                      or 0, at fb + y * pitch + 2x
 *
 * It installs itself as Machine.screen, which Machine.print calls
 * for each character after writing it to the UART, so nothing above
 * knows there is a screen. Scrolling copies the framebuffer up by a
 * row of cells, which is why a console of pixels is slow: 1.5 MB are
 * moved for each line past the last.
 *
 * others:
 * The PC had this in hardware. In the VGA's text mode, a character's
 * code and its colour are two bytes written at 0xB8000, the card holds
 * the font, and xv6's x86 console is those few lines. A board that has
 * only a framebuffer, as the Pi and every machine since, must draw its
 * letters itself. mini-oberon draws Oberon's own proportional letters,
 * of any width, read from a file (its Fonts). *)

(* asks for the framebuffer, and from then on draws the console there
 * (Machine.screen); it does nothing when there is no framebuffer *)
val init : unit -> unit

(* the mouse moved by dx, dy (and its buttons are given): the cursor,
 * an arrow drawn by inverting the pixels under it, is moved there,
 * within the screen. It is shown from the first move on, and hidden
 * while the console draws. *)
val pointer : int -> int -> int -> unit
