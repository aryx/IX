(* The mouse and the keyboard (Oberon's Input), as Oberon's loop asks
 * them: where the mouse is and which of its keys are down, whether a
 * character was typed, and it.
 *
 * Oberon's reads the hardware's registers when asked. Here the
 * drivers are the other kernels' (machine/Usbhost: a USB keyboard and
 * mouse, asked at each tick; the serial line), which call [moved] and
 * [typed]; this module keeps what they said. *)

(* the mouse's keys, a set as Oberon's: left 4, middle 2, right 1 *)
val left : int
val middle : int
val right : int

(* the keys down, x, y (the origin at the bottom left, as Display's) *)
val mouse : unit -> int * int * int

(* the characters typed and not read yet; the first of them *)
val available : unit -> int
val read : unit -> char

(* The drivers' side: the mouse moved by (dx, dy), dy downwards, its
 * buttons as USB says them (1 left, 2 right, 4 middle); a character
 * typed *)
val moved : int -> int -> int -> unit
val typed : char -> unit
