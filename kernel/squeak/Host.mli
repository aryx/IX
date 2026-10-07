(* mini-squeak's host on the bare Pi 4: what Smalltalk's machine asks
 * of what is under it (St_interp.host), given by the board: the
 * mouse and the keys of a USB keyboard and mouse (machine/Usbhost),
 * the serial line's characters as keys too, the generic timer as the
 * clock, the serial line as the host's Transcript; and the Display
 * shown on the board's framebuffer, 800 by 600 in 32 bits.
 * docs/plans/plan_system_squeak.md. *)

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
