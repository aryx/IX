(* TinyKernel's devices but the disk and the network: the screen (its
 * image, the font), the mouse (a box the kernel writes), the clock (the
 * timer's ticks, the date, an alarm), the speaker (its ring of
 * samples, each voice's sounds mixed in).
 *
 * The screen is tiny-machine's 640 by 480 bytes; TinyKernelGraphics
 * draws in it and in the images below it, a program's /dev/draw
 * connection asking by messages: no pixel is in its partition. The
 * speaker plays the ring, 8,192 samples, 8,000 a second; each open of
 * /dev/audio is a voice, whose sounds (TinyKernelAudio's) are added to
 * what the ring has, so two programs are heard at once and neither
 * waits for the other:
 *
 *     the ring   ...[played]....[lead][voice 1's next]......[voice 2's]...
 *                     ^ the speaker          ^ where its next sound goes
 *
 * plan9-is-cleaner:
 * as Plan 9's, each device is a file a program opens (/dev/draw,
 * /dev/mouse, /dev/audio), and a window system serves files of the same
 * names to its windows; here the kernel mixes the voices, where Plan 9
 * has one writer of /dev/audio at a time (its devaudio is opened by
 * one, from memory).
 *)

(* the screen's image, and the font's, a mask made at the boot *)
val screen : TinyKernelGraphics.image
val font : TinyKernelGraphics.image

(* the mouse: a box the kernel writes (x, y, the buttons, a word each)
 * when the machine's word changed *)
val mouse : TinyKernelFiles.box

(* the timer's interrupts counted; the date (the boot's, and the seconds
 * since, 400 ticks each); the earliest tick a waiting process asked to
 * be told of (0: none); the machine's time at the last tick counted *)
val ticks : int ref
val date : unit -> int
val alarm : int ref
val counted : int ref

(* the ring's samples, and how far ahead of the speaker a voice starts
 * again (5 ms); the samples played so far *)
val ring : int
val lead : int
val played : unit -> int

(* a voice's sounds mixed into the ring after its last one, if they all
 * fit (a second ahead of the speaker at most): 0; else the samples
 * missing, the write waits until the speaker played them *)
val speak : TinyKernelFiles.voice -> TinyKernelAudio.sound list -> int
