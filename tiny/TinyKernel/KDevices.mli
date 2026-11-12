(* TinyKernel's devices, except the disk and the network:
 * - the screen, with its image and the font;
 * - the mouse, a box that the kernel writes;
 * - the clock: the timer's ticks, the date, and an alarm;
 * - the speaker: a ring of samples into which each voice's sounds are
 *   mixed.
 *
 * The screen is tiny-machine's 1024 by 768 bytes. KGraphics draws in
 * it and in the images stacked below it. A program asks for drawing by
 * sending messages on its /dev/draw connection: no pixel of the screen
 * is in the program's own partition.
 *
 * The speaker plays the ring, 8,192 samples at 8,000 a second. Each
 * open of /dev/audio is a voice. A voice's sounds (see KAudio) are
 * added to what the ring already holds, so two programs are heard at
 * once and neither waits for the other:
 *
 *     the ring   ...[played]....[lead][voice 1's next]......[voice 2's]...
 *                     ^ the speaker          ^ where voice 1's next
 *                                              sound goes
 *
 * plan9-is-cleaner:
 * As in Plan 9, each device is a file that a program opens (/dev/draw,
 * /dev/mouse, /dev/audio), and a window system serves files with the
 * same names to its windows. Here the kernel mixes the voices, whereas
 * Plan 9 allows one writer of /dev/audio at a time (its devaudio can
 * be opened by one process only, from memory).
 *)

(* The font's image is a mask made at boot. *)
val screen : KGraphics.image
val font : KGraphics.image

(* The kernel writes x, y and the buttons (a word each) to this box when
 * the machine's mouse word changes. *)
val mouse : KFiles.box

(* [ticks] counts timer interrupts, 400 a second; [date] is the boot's
 * date plus the seconds since. [alarm] is the earliest tick a waiting
 * process asked for (0: none). [counted] is the time of the last tick. *)
val ticks : int ref
val date : unit -> int
val alarm : int ref
val counted : int ref

(* [ring] is in samples. A voice starts again [lead] (5 ms) ahead of the
 * speaker after a silence. *)
val ring : int
val lead : int
val played : unit -> int

(* [speak v sounds] mixes sounds after v's last one and returns 0 if
 * they fit within a second ahead of the speaker. Otherwise it returns
 * the samples missing, and the write waits for the speaker to play them. *)
val speak : KFiles.voice -> KAudio.sound list -> int
