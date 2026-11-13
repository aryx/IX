(* A window's console (rio's Qcons, Qconsctl; xix's Virtual_cons; and
 * 9front's kbd): what a program in a window opens as /dev/cons.
 *
 * There are two modes. In cooked mode, the window keeps what is typed,
 * one corrects it there, and a read gets a whole line at the newline.
 * In raw mode, a read gets the keys as they are typed (for an editor, a
 * game, a password).
 *
 * plan9-is-cleaner:
 * A program asks for raw by writing the word rawon in a second
 * file, /dev/consctl, and gets cooked back with rawoff, or by
 * closing it. On Unix the same is done by an ioctl on the terminal,
 * with a structure of dozens of flags (termios; stty prints them).
 * The kernel keeps those flags after the program dies, which is why
 * a terminal is left unusable when one is killed in raw mode. A
 * control file of words needs no call of its own and no header to
 * compile against, and it works from the shell and across the
 * network. *)

(* A read gets a line typed in the window, when there is one (or the
 * keys as they come, in raw mode). A write gives text to the window,
 * and it is answered when the window shows the text: at once, except
 * in a window that does not scroll and is full. When the last one who
 * has the file open closes it, a window made with a command goes away,
 * its command being done. rio does that too, but it counts the opens
 * of all the window's files, so a program that only reads another
 * window's label would keep that window there. *)
val cons : Device.t
(* Writing "rawon" gives the keys as they are typed, with no line kept
 * and no echo; writing "rawoff", or closing the file, gives lines
 * again. *)
val consctl : Device.t
(* the keys held down, for a program that asks for them (a game). A
 * read gets the next change, written as the kernel's /dev/kbd writes
 * it. The changes are kept from when the file is opened. *)
val kbd : Device.t
