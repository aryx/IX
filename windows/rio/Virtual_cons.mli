(* A window's console (rio's Qcons, Qconsctl; xix's Virtual_cons; and
 * 9front's kbd): what a program in a window opens as /dev/cons.
 *
 * Two modes. Cooked: the window keeps what is typed, one corrects it
 * there, and a read gets a whole line at the newline. Raw: a read
 * gets the keys as they are typed (an editor, a game, a password).
 *
 * plan9-is-cleaner:
 * A program asks for raw by writing the word rawon in a second
 * file, /dev/consctl, and gets cooked back with rawoff, or by
 * closing it. On Unix the same is an ioctl on the terminal with a
 * structure of dozens of flags (termios; stty prints them), kept
 * by the kernel after the program dies, which is why a terminal is
 * left unusable when one is killed in raw mode. A control file of
 * words needs no call of its own, no header to compile against, and
 * works from the shell and across the network. *)

(* read: a line typed in the window, when there is one (the keys as
 * they come, when raw); written: text for the window (a write
 * answered when the window shows it: at once, but in one that does
 * not scroll and is full) *)
val cons : Device.t
(* "rawon" and "rawoff" written: the keys as they are typed, no line
 * kept and no echo; closed: the lines again *)
val consctl : Device.t
(* the keys held, for a program that asks (a game): a read is the next
 * change, as the kernel's /dev/kbd says it; kept from when it is opened *)
val kbd : Device.t
