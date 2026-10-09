(* A program's connection to the screen (Plan 9's libdraw, its Display
 * and Image; xix's lib_graphics/draw is the author's in OCaml): the
 * draw device's files (/dev/draw), which take messages, each a letter
 * and its arguments as bytes: an image made, a rectangle of one
 * combined into another, a line. The kernel has the images (the
 * screen is one) and does the drawing: a program only says what.
 *
 * The messages are kept and sent together: nothing shows before
 * [flush]. *)

type t

(* an image of the kernel's, by its number there: where it is in the
 * plane (the screen's coordinates), and whether it repeats over all of
 * it (a colour is an image of one pixel that does) *)
type image = { display : t; id : int; r : Rectangle.t; repl : bool }

(* a colour: red, green, blue, and how opaque, each 0 to 255 *)
type color = { red : int; green : int; blue : int; alpha : int }
val rgb : int -> int -> int -> color
val black : color
val white : color

(* a pixel's format, as Plan 9 writes it: "k1" a bit of grey, "k8" a
 * byte, "r8g8b8", "x8r8g8b8" (the screen's, here)... *)
type chan = string

(* the connection opened: /dev/draw/new, then its data file *)
val init : < Cap.draw; .. > -> t
(* the screen's format *)
val format : t -> chan
(* [hold d true]: the messages are kept until [flush], however many (they
 * are sent as they pile up otherwise): for a meter, the device's time is
 * then the flush's alone *)
val hold : t -> bool -> unit
(* where the program draws: its window, when it runs in one of a window
 * system's (inside the border); else all the screen. Asked again when
 * the window changed (Mouse's resized): the image is then another. *)
val screen : t -> image
(* all the screen: image 0 of a connection (a window system's) *)
val whole : t -> image

(* a new image, filled with a colour *)
val alloc : t -> Rectangle.t -> chan -> repl:bool -> color -> image
(* a colour to draw with: one pixel, repeated *)
val color : t -> color -> image
(* the mask that hides nothing *)
val opaque : t -> image
val free : image -> unit
(* an image's pixels given: rows of bytes, as its format packs them *)
val load : image -> Rectangle.t -> string -> unit
(* [load_sub img r pixels off n]: the same, the pixels n bytes of a
 * larger array from off (a program's own picture: no copy of them made
 * to be given) *)
val load_sub : image -> Rectangle.t -> bytes -> int -> int -> unit
(* an image of the screen's format (the screen, a window) as Plan 9
 * writes one in a file (image(6), not compressed): its format and its
 * rectangle's four numbers, each 11 characters and a space, then its
 * pixels, rows of bytes *)
val file : image -> string

(* Windows: a screen's image made a desktop, filled with an image
 * where no window is; then windows on it, images that may cover one
 * another (the kernel draws what shows of each and keeps the rest:
 * Plan 9's layers); one brought to the front *)
type desktop
val desktop : image -> image -> desktop
val window : desktop -> Rectangle.t -> color -> image
val top : image -> unit
(* (and behind the others) *)
val bottom : image -> unit
(* a window moved: its corner in its own coordinates, and where that is
 * on the screen (elsewhere than the first: off the screen, hidden) *)
val origin : image -> Point.t -> Point.t -> image
(* an image given a name, which another program draws in by ([named]) *)
val name : image -> string -> unit
val named : t -> string -> image

(* a message, for Draw: a letter and its bytes, built with these, in
 * the bytes kept until they are sent ([out]) *)
type out
val message : t -> (out -> unit) -> unit
val char : out -> char -> unit
val byte : out -> int -> unit
val long : out -> int -> unit
val point : out -> Point.t -> unit
val rect : out -> Rectangle.t -> unit

(* what was said so far sent, and shown *)
val flush : t -> unit
(* the connection ended: its images are freed by the kernel *)
val close : t -> unit
