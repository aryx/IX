(* A program's connection to the screen (Plan 9's libdraw, its Display
 * and Image; xix's lib_graphics/draw is the author's in OCaml): the
 * draw device's files (/dev/draw), which take messages, each a letter
 * and its arguments as bytes: an image made, a rectangle of one
 * combined into another, a line. The kernel has the images (the
 * screen is one) and does the drawing: a program only says what.
 *
 * The messages are kept and sent together: nothing shows before
 * [flush].
 *
 * The files, all text but the messages:
 *
 *     /dev/draw/new      read once: twelve numbers of 12 characters.
 *                        The connection's number n, then the screen:
 *                        its image's number (0), its format, whether
 *                        it repeats, its rectangle, its clipping one
 *     /dev/draw/n/data   written: the messages; read: pixels asked for
 *     /dev/winname       read: the name of the window's image, when a
 *                        window system runs the program ([screen])
 *
 * A message is a letter, then its arguments with no padding: a number
 * is four bytes, the low one first, a point two numbers, a rectangle
 * two points. A red square on the screen is two of them, a colour
 * made and a drawing (and a third like the first, the white mask
 * that hides nothing):
 *
 *     b  id=1 screen=0 refresh  chan  repl=1  r 0 0 1 1  clip  a b g r
 *     1   4      4        1      4      1        16       16      4
 *                                                         = 51 bytes
 *     d  dst=0  src=1  mask=2  r 10 10 110 110  src's point  mask's
 *     1    4      4       4          16              8          8
 *                                                         = 45 bytes
 *
 * The letters written here and by Draw:
 *
 *     b  an image made (on a screen: a window)    f  an image freed
 *     d  src through mask into dst (Draw.draw)    L  a line
 *     p P  a polygon's lines, its inside          e E  an ellipse's
 *     y  pixels given to an image                 r  pixels asked for
 *     A  an image made a screen of windows        t  windows to the
 *     o  a window moved                              front or the back
 *     N  an image given a name                    n  the image of a name
 *     v  what was drawn, shown
 *
 * An image's number is chosen by the program ([alloc] counts up from
 * 1), not given back by the kernel: so no message needs an answer,
 * and a frame's hundreds of drawings are one write. Only [named] and
 * [file] read, and they send what is kept first.
 *
 * A pixel's format (chan) is a word of 32 bits, a byte a channel: the
 * channel's kind in the high four bits (r 0, g 1, b 2, k 3, a 4, m 5,
 * x 6), how many bits it has in the low four; the first channel
 * written is the highest in the pixel. So "x8r8g8b8" is 0x68081828,
 * and a pixel of it in memory, the low byte first, is blue, green,
 * red, and a byte that is not used: Framebuffer's bytes.
 *
 * Where it stands: the modules beside this one are the library,
 *
 *     Point, Rectangle     the plane
 *     Display              the connection, the images, a message's bytes
 *     Draw                 each drawing message a function
 *     Font                 a string: a 'd' a character
 *     Mouse, Keyboard      /dev/mouse and /dev/cons, as events
 *     Cursor, Menu         the mouse's picture; a menu under it
 *
 * and the other end is mini-9pi's kernel: Devdraw reads the messages
 * and has the numbers and the names, Memdraw composes the pixels,
 * Memlayer has the windows. Between the two, mini-rio (Rio, Wm)
 * makes a screen of the screen's image ('A') and a window for each
 * program ('b', 'N'), and serves a /dev/winname, a /dev/mouse and a
 * /dev/cons to each (Virtual_mouse, Virtual_cons); the drawing
 * messages of a program in a window still go to the kernel, which
 * keeps them inside the window. The programs: mini-rio itself, a
 * game (lib_playground's draw platform, which draws in a Framebuffer
 * of its own and gives it whole by [load_sub]), a terminal's window
 * (lib_terminal), mini-emacs, mini-page.
 *
 * plan9-is-cleaner:
 * The screen is files. In the X Window System the screen belongs to
 * a server, a user's program that others reach through a socket with
 * a protocol of its own, a library to speak it (Xlib), a variable to
 * say where it is (DISPLAY) and a scheme of its own to say who may
 * connect. Here a program opens /dev/draw/new as it would any file:
 * the permissions are a file's, and a program on another machine
 * draws on this screen when this machine's /dev is mounted there,
 * with no line of the graphics library knowing of a network. A
 * window system is then a file server that gives each of its
 * programs a /dev of the same shape as the one it has itself, and so
 * runs in one of its own windows.
 *
 * cs-history:
 * The Blit (Rob Pike and Bart Locanthi, Bell Labs, 1982) was a
 * terminal with a bitmap screen and a processor of its own; the
 * windows were drawn in the terminal, by programs sent down the line
 * to it. Plan 9's first window system, 8 1/2 (Pike, 1991), kept the
 * terminal's side as a kernel device, /dev/bitblt, written with
 * messages as here, on bitmaps of a few bits a pixel combined by
 * boolean operations. The draw device replaced it in the third
 * edition (2000), with rio in the place of 8 1/2: pixels of red,
 * green and blue with an alpha, and one operation of compositing
 * where there were the boolean ones (Draw.mli).
 *
 * design:
 * Kept and sent together. A write is a system call, thousands of
 * instructions to say that 45 bytes are a rectangle; a frame of a
 * game has hundreds. So the library writes when 8,000 bytes are kept
 * or when asked, as a C program's standard output does, and for the
 * same reason; Xlib does the same with its requests (XFlush). What
 * it costs is the surprise of a program that draws and sees nothing:
 * the flush is part of the protocol ('v', which also says that the
 * screen is to show it).
 *
 * References: draw(3) of Plan 9's manual, the messages; draw(2) and
 * graphics(2), the C library followed here (principia's
 * lib_graphics/libdraw, and its Graphics book for the kernel's side);
 * Rob Pike, "8 1/2, the Plan 9 Window System" (USENIX, 1991), a
 * window system as a file server, and "Rio: Design of a Concurrent
 * Window System" (a talk's slides, 2000; from memory); Rob Pike,
 * "The Blit: A Multiplexed Graphics Terminal" (AT&T Bell
 * Laboratories Technical Journal, 1984; from memory). *)

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
