(* '#m' is the mouse (principia's devmouse.c). Its files are:
 * - /dev/mouse, the mouse's state as rio reads it ("m x y buttons
 *   msec"). A read waits for a change, and a button's change is queued;
 * - mousein, where usb/kb writes a USB mouse's moves ("m dx dy buttons
 *   [msec]");
 * - mousectl, which takes buttonmap, swap, scrollswap, accelerated and
 *   linear;
 * - cursor, the cursor's image, which is 9pi's arrow at first and is
 *   drawn by Swcursor.
 * The position is kept within the screen. Without a screen, moves are
 * dropped, as 9pi drops them without a gscreen.
 *
 *     a USB mouse moves 3 right, 1 down, the left button held
 *       usbd (a program) or Kusb (the kernel): Hid reads the report,
 *       and "m 3 1 1" is written to mousein, or [track 3 1 1] is called
 *       the position moves, kept inside the screen; Mouse_change
 *     the window system, asleep in a read of /dev/mouse, gets
 *       m, then x, y, buttons and msec: four numbers, each in 11
 *       columns followed by a blank, 49 bytes in all
 *
 * A read gives the state now, not each move since the last read, so a
 * slow reader skips positions and never falls behind. Only a button's
 * change is queued, so that a click is not lost between two reads. The
 * buttons are bits: 1 is left, 2 middle, 4 right, and 8 and 16 are the
 * wheel.
 *
 * design:
 * The file is text again, and for a reason beyond taste: the bytes mean
 * the same on every processor, so a mouse can be read over a network
 * from a machine of another kind, and by a script. A window system gives
 * each window a /dev/mouse of this exact shape, with only the window's
 * moves; a program cannot tell, and need not know, whether it has the
 * screen or a window. *)

(* the screen's rectangle (min x, min y, max x, max y), once there is one *)
val screen : (int * int * int * int) option ref

(* mousexy: the mouse's position *)
val xy : unit -> int * int

(* the mouse moved by so much, and these are its buttons now (what a
 * write to mousein says, here from the kernel's own driver: Kusb) *)
val track : int -> int -> int -> unit

(* the mouse is at (x, y) of the screen, and these are its buttons now:
 * for a mouse that says where it is (a web page's: Kweb) *)
val at : int -> int -> int -> unit

(* mouseresize: the screen changed (the next read gives an 'r') *)
val resize : unit -> unit

(* registers the device, and loads and draws the arrow cursor *)
val init : unit -> unit
