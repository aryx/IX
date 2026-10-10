(* '#m', the mouse (principia's devmouse.c): /dev/mouse, its state as
 * rio reads it ("m x y buttons msec", a read waiting for a change; a
 * button's change queued), mousein (usb/kb writes a USB mouse's moves:
 * "m dx dy buttons [msec]"), mousectl (buttonmap, swap, scrollswap,
 * accelerated, linear), cursor (the cursor's image: 9pi's arrow at
 * first, drawn by Swcursor). The position is kept within the screen
 * (without one, moves are dropped, as 9pi's without a gscreen).
 *
 *     a USB mouse moves 3 right, 1 down, the left button held
 *       usbd (a program), or Kusb (the kernel): Hid reads the report
 *       "m 3 1 1" written to mousein, or [track 3 1 1]
 *       the position moved, kept inside the screen; Mouse_change
 *     the window system, asleep in a read of /dev/mouse, gets
 *       m, then x, y, buttons, msec: four numbers each in 11
 *       columns and a blank, 49 bytes
 *
 * A read gives the state now, not each move since the last: a slow
 * reader skips positions and never falls behind. Only a button's
 * change is queued, so that a click is not lost between two reads.
 * The buttons are bits: 1 left, 2 middle, 4 right, 8 and 16 the
 * wheel.
 *
 * design:
 * Text again, and a reason beyond taste: the bytes mean the same on
 * every processor, so a mouse can be read over a network from a
 * machine of another kind, and by a script. A window system gives
 * each window a /dev/mouse of this exact shape, with the window's
 * moves only; a program cannot tell, and need not know, whether it
 * has the screen or a window. *)

(* the screen's rectangle (min x, min y, max x, max y), once there is one *)
val screen : (int * int * int * int) option ref

(* mousexy: the mouse's position *)
val xy : unit -> int * int

(* claude: the mouse moved by so much, its buttons now (what a write to
 * mousein says, from the kernel's own driver: Kusb) *)
val track : int -> int -> int -> unit

(* mouseresize: the screen changed (its next read an 'r') *)
val resize : unit -> unit

(* the device registered; the arrow cursor loaded and drawn *)
val init : unit -> unit
