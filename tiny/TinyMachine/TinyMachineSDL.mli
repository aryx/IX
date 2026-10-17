(* The SDL window of tiny-machine-window (tsdl): the one module of t-ix
 * that links a C library. It shows frames of RGB bytes, gives what is
 * done in the window as events, and sets the mouse's look.
 *
 * The window opens at the first frame, at the largest whole number of
 * times the frame that three quarters of the screen's height hold (the
 * machine's 640 by 480 is small on a large screen). It can be resized:
 * the frame is drawn as large as fits, its proportions kept, and the
 * mouse's place is still given in the frame's pixels.
 *
 * mini-qemu has its own (raspberry/video/Sdl_display.ml), which does
 * more: sound, a meter under the screen, a mouse grabbed and relative
 * as a USB mouse is. This one is what tiny-machine needs, so that t-ix
 * depends on nothing of mini-qemu's. *)

(* What is done in the window: closed; the mouse's place (in the frame's
 * pixels); a mouse button (1 left, 2 middle, 4 right, as Plan 9's),
 * down or up; a key (its USB HID usage, which is SDL's scancode), down
 * or up; a step of the wheel or of two fingers on a trackpad (negative
 * up). *)
type event = Quit | At of int * int | Button of int * bool | Key of int * bool | Wheel of int

(* [present w h rgb]: a frame of w by h pixels, three bytes each (red,
 * green, blue). [poll ()]: the events since the last poll. [cursor n]:
 * the mouse's look, 0 the arrow, 1 a hand (over a link). *)
type t = { present : int -> int -> string -> unit; poll : unit -> event list; cursor : int -> unit }

val create : title:string -> t

(* a key's byte, by its USB usage (a US keyboard's, SDL's scancode),
 * with shift and control; the arrows 128 to 131 (up, down, left,
 * right), tiny-machine's choice; None for a key that is no byte *)
val key_byte : int -> shift:bool -> ctrl:bool -> int option
