(* The SDL window of tiny-machine-window, through the tsdl binding.
 * This is the one module of t-ix that links a C library. It shows
 * frames of RGB bytes, reports what the user does in the window as
 * events, and sets the mouse cursor.
 *
 * The window opens at the first frame. Its size is the largest whole
 * multiple of the frame's size that fits in three quarters of the
 * screen's height, because the machine's 1024 by 768 is small on a
 * large screen. It can be resized: the frame is then drawn as large as
 * fits, keeping its proportions, and the mouse's position is still
 * given in the frame's pixels.
 *
 * The sound goes through SDL's queue, filled as the samples come
 * (about thirty times a second). Two rules keep it in step:
 * - when the queue has run empty, we first queue a tenth of a second
 *   of silence. This is the margin a late frame of the host can eat
 *   before it is heard as a gap (notes_audio.md, A);
 * - when more than half a second is queued, new samples are dropped,
 *   so that a sound stays close to what it goes with on the screen.
 *
 * mini-qemu has its own SDL display (raspberry/video/Sdl_display.ml),
 * which does more: 44,100 samples a second in two channels, a meter
 * under the screen, and a mouse that is grabbed and relative, as a USB
 * mouse is. This one does only what tiny-machine needs, so that t-ix
 * depends on nothing of mini-qemu's. *)

type event =
  | Quit
  | At of int * int (* in the frame's pixels *)
  | Button of int * bool (* 1 left, 2 middle, 4 right, as in Plan 9 *)
  | Key of int * bool (* the USB HID usage, also SDL's scancode *)
  | Wheel of int (* a step, negative going up *)

(* [present w h rgb] takes three bytes a pixel. [cursor] 0 is the arrow,
 * 1 a hand. [play] queues the speaker's signed bytes, 8,000 a second,
 * and opens the sound at the first call. *)
type t = {
  present : int -> int -> string -> unit; poll : unit -> event list;
  cursor : int -> unit; play : string -> unit; queued : unit -> int;
}

val create : title:string -> t

(* How tiny-machine-window and tiny/user/sdl/ turn events into bytes,
 * on a US keyboard with shift and control. The arrows are 128 to 131
 * (up, down, left, right); Alt types Escape then the key (Emacs's Meta).
 * A wheel step types an up or down arrow: a key is queued, where a
 * quick click between two reads of the mouse could be missed. A held
 * key repeats after 0.3 s, then every 0.05 s; it is done here because
 * the display reports a press once, as a USB driver wants, while a game
 * wants held arrows to keep coming. Times are in seconds. *)
type keyboard
val keyboard : unit -> keyboard
val typed : keyboard -> float -> event -> int list
val repeated : keyboard -> float -> int option
