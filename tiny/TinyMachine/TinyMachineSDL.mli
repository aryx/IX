(* The SDL window of tiny-machine-window (tsdl): the one module of t-ix
 * that links a C library. It shows frames of RGB bytes, gives what is
 * done in the window as events, and sets the mouse's look.
 *
 * The window opens at the first frame, at the largest whole number of
 * times the frame that three quarters of the screen's height hold (the
 * machine's 1024 by 768 is small on a large screen). It can be resized:
 * the frame is drawn as large as fits, its proportions kept, and the
 * mouse's place is still given in the frame's pixels.
 *
 * The sound is SDL's queue, filled as the samples come (about thirty
 * times a second): when it ran empty, a tenth of a second of silence
 * goes first, the margin a late frame of the host's eats before it is
 * heard as a gap (notes_audio.md's A); past half a second queued, what
 * comes is dropped, so that a sound stays near what it goes with.
 *
 * mini-qemu has its own (raspberry/video/Sdl_display.ml), which does
 * more: 44,100 samples a second in two channels, a meter under the
 * screen, a mouse grabbed and relative as a USB mouse is. This one is
 * what tiny-machine needs, so that t-ix depends on nothing of
 * mini-qemu's. *)

(* What is done in the window: closed; the mouse's place (in the frame's
 * pixels); a mouse button (1 left, 2 middle, 4 right, as Plan 9's),
 * down or up; a key (its USB HID usage, which is SDL's scancode), down
 * or up; a step of the wheel or of two fingers on a trackpad (negative
 * up). *)
type event =
  | Quit
  | At of int * int
  | Button of int * bool
  | Key of int * bool
  | Wheel of int

(* [present w h rgb]: a frame of w by h pixels, three bytes each (red,
 * green, blue). [poll ()]: the events since the last poll. [cursor n]:
 * the mouse's look, 0 the arrow, 1 a hand (over a link). [play
 * samples]: the machine's speaker's, a byte each (signed), 8,000 a
 * second, played after those before; the sound opened at the first.
 * [queued ()]: the samples waiting to be played. *)
type t = {
  present : int -> int -> string -> unit; poll : unit -> event list;
  cursor : int -> unit; play : string -> unit; queued : unit -> int;
}

val create : title:string -> t

(* The keyboard, what tiny-machine-window and tiny/sdl/ type from the
 * window's events. A key's byte is by its USB usage (a US keyboard's,
 * SDL's scancode), with shift and control; the arrows 128 to 131 (up,
 * down, left, right), tiny-machine's choice; a key that is no byte
 * types nothing. Alt with a key is Escape then the key: Emacs's Meta,
 * M-x. A step of the wheel (or of two fingers on a trackpad) is an
 * arrow key, up or down, a step each: a key is queued, where a button
 * pressed and let go between two reads of the mouse could be missed. A
 * program scrolls by its arrows (www, emacs).
 *
 * The key held is typed again, a keyboard's repeat, done here (the
 * display says a key's press once, what a kernel's USB driver wants; a
 * game wants its arrows held): after 0.3 s, then every 0.05 s.
 *
 * [typed k now e]: the bytes the event e types (none for a modifier, the
 * mouse, Quit), now the time in seconds. [repeated k now]: the key held,
 * when it is typed again. *)
type keyboard
val keyboard : unit -> keyboard
val typed : keyboard -> float -> event -> int list
val repeated : keyboard -> float -> int option
