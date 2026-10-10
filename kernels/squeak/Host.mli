(* mini-squeak's host on the bare Pi 4: what Smalltalk's machine asks
 * of what is under it (St_interp.host), given by the board: the
 * mouse and the keys of a USB keyboard and mouse (machine/Usbhost),
 * the serial line's characters as keys too, the generic timer as the
 * clock, the serial line as the host's Transcript; and the Display
 * shown on the board's framebuffer, 800 by 600, in 32 bits or in 16
 * (Which.depth: the mkfile's DEPTH), painted the world's grey at the
 * start.
 * docs/plans/plan_system_squeak.md.
 *
 * The third host of the same Squeak (languages/smalltalk's
 * Squeak.mli draws the three): a window on Linux, a window of
 * mini-rio under mini-9pi, and this one, where the "window" is the
 * board's whole screen and the events come from drivers that this
 * kernel polls itself.
 *
 *     Usbhost's key, move ---> a queue of keys; x, y, buttons
 *     the UART's characters -'      | St_interp.host's mouse and
 *     the timer's tick ------> ms   | keys, asked by primitives
 *                                   v
 *     Squeak.cycle ...  the Display changed ---> show32: its rows
 *                                                copied to the
 *                                                framebuffer
 *
 * Nothing is pushed into Smalltalk: its primitives ask (as the
 * first Squeak's did, with primitives for the mouse's point and the
 * next key; from memory), and as Oberon's loop asks its Input. An
 * event queue filled by interrupts is what later systems put here.
 *
 * design:
 * The Display is an object of Smalltalk's, a Form whose bits the
 * machine lets the host see; the framebuffer is another memory. A
 * copy of the whole picture at each change is the simple thing
 * (800 by 600 in 32 bits: 1.9 MB), and what the Alto did not need:
 * its display was the Smalltalk bitmap itself, read by the
 * hardware. *)

(* the devices started: the framebuffer asked, the USB devices found,
 * the timer armed. What the machine is given. *)
val init : unit -> St_interp.host

(* the devices asked, once a pass of the world: waits for the tick if
 * it has not come (10 ms: a hundred passes a second at most), then the
 * keyboard's and the mouse's reports and the serial line's characters.
 * True when Control-C was typed. *)
val poll : unit -> bool

(* the Display's pixels (Squeak.pixels': red, green, blue, alpha)
 * copied to the framebuffer *)
val show : int * int * Bytes.t -> unit

(* the same from a Display of 32 bits as it is (Squeak.bits32's: its
 * width, its height, a row's bytes, its pixels alpha, red, green,
 * blue): the same bytes one further on *)
val show32 : int * int * int * Bytes.t -> unit

(* The pointer, which Squeak does not draw: whether the mouse moved
 * since this was last asked; and an arrow drawn where it is, over the
 * picture (after each one shown; nothing before the mouse first moves) *)
val pointer_moved : unit -> bool
val pointer : unit -> unit
