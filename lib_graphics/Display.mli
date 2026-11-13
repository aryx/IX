(* A program's connection to the screen (Plan 9's libdraw, with its
 * Display and Image; xix's lib_graphics/draw is the author's version in
 * OCaml). The connection is the draw device's files (/dev/draw), which
 * take messages. Each message is a letter and its arguments as bytes:
 * it makes an image, combines a rectangle of one image into another,
 * draws a line, and so on. The kernel has the images (the screen is one
 * of them) and does the drawing; a program only says what to draw.
 *
 * The messages are kept and sent together, so nothing shows before
 * [flush].
 *
 * The files are all text, except for the messages:
 *
 *     /dev/draw/new      read once: twelve numbers of 12 characters.
 *                        First the connection's number n, then the
 *                        screen's image: its number (0), its format,
 *                        whether it repeats, its rectangle, and its
 *                        clipping rectangle
 *     /dev/draw/n/data   written with the messages; read for the
 *                        pixels that a message asked for
 *     /dev/winname       read for the name of the window's image, when
 *                        a window system runs the program ([screen])
 *
 * A message is a letter followed by its arguments, with no padding. A
 * number is four bytes, the low one first; a point is two numbers, and
 * a rectangle is two points. A red square on the screen takes two
 * messages, one that makes a colour and one that draws it (and a third
 * one like the first, which makes the white mask that hides nothing):
 *
 *     b  id=1 screen=0 refresh  chan  repl=1  r 0 0 1 1  clip  a b g r
 *     1   4      4        1      4      1        16       16      4
 *                                                         = 51 bytes
 *     d  dst=0  src=1  mask=2  r 10 10 110 110  src's point  mask's
 *     1    4      4       4          16              8          8
 *                                                         = 45 bytes
 *
 * These are the letters written here and by Draw:
 *
 *     b    makes an image (on a screen, a window)
 *     f    frees an image
 *     d    draws src through mask into dst (Draw.draw)
 *     L    draws a line
 *     p P  draws a polygon's lines, or fills its inside
 *     e E  does the same for an ellipse
 *     y    gives pixels to an image
 *     r    asks for an image's pixels
 *     A    makes an image a screen of windows
 *     t    brings windows to the front, or sends them to the back
 *     o    moves a window
 *     N    gives an image a name
 *     n    asks for the image of a name
 *     v    shows what was drawn
 *     c    sets an image's clipping rectangle
 *
 * The program chooses an image's number ([alloc] counts up from 1); the
 * kernel does not give it back. So no message needs an answer, and the
 * hundreds of drawings of a frame are one write. Only [named] and
 * [file] read from the device, and they first send what is kept.
 *
 * A pixel's format (chan) is a word of 32 bits, with a byte for each
 * channel. The channel's kind is in the high four bits (r 0, g 1, b 2,
 * k 3, a 4, m 5, x 6), and how many bits it has is in the low four. The
 * first channel written is the highest in the pixel. So "x8r8g8b8" is
 * 0x68081828, and a pixel of it in memory, the low byte first, is blue,
 * green, red, and a byte that is not used: the same bytes as a
 * Framebuffer's.
 *
 * Here is where this module stands. The modules beside it are the
 * library:
 *
 *     Point, Rectangle     the plane
 *     Display              the connection, the images, a message's bytes
 *     Draw                 a function for each drawing message
 *     Font                 a string drawn as a 'd' for each character
 *     Mouse, Keyboard      /dev/mouse and /dev/cons, read as events
 *     Cursor, Menu         the mouse's picture, and a menu under it
 *
 * The other end is mini-9pi's kernel: Devdraw reads the messages and
 * keeps the numbers and the names, Memdraw composes the pixels, and
 * Memlayer has the windows. Between the two, mini-rio (Rio, Wm) makes
 * the screen's image a screen of windows ('A'), and makes a window for
 * each program ('b', 'N'). It serves a /dev/winname, a /dev/mouse and a
 * /dev/cons to each program (Virtual_mouse, Virtual_cons). The drawing
 * messages of a program in a window still go to the kernel, which keeps
 * them inside the window. The programs that use this library are
 * mini-rio itself, a game (lib_playground's draw platform, which draws
 * in a Framebuffer of its own and gives it whole with [load_sub]), a
 * terminal's window (lib_terminal), mini-emacs and mini-page.
 *
 * plan9-is-cleaner:
 * The screen is files. In the X Window System, the screen belongs to a
 * server, a user's program that the others reach through a socket. It
 * has a protocol of its own, a library to speak it (Xlib), a variable
 * to say where it is (DISPLAY), and a scheme of its own to say who may
 * connect. Here a program opens /dev/draw/new as it would open any
 * file. The permissions are a file's, and a program on another machine
 * draws on this screen when this machine's /dev is mounted there,
 * without any line of the graphics library knowing about a network. A
 * window system is then a file server that gives each of its programs
 * a /dev of the same shape as the one it has itself, and so it can run
 * in one of its own windows.
 *
 * cs-history:
 * The Blit (Rob Pike and Bart Locanthi, Bell Labs, 1982) was a terminal
 * with a bitmap screen and a processor of its own; the windows were
 * drawn in the terminal, by programs sent down the line to it. Plan 9's
 * first window system, 8 1/2 (Pike, 1991), kept the terminal's side as
 * a kernel device, /dev/bitblt. It was written with messages as here,
 * on bitmaps of a few bits per pixel that were combined by boolean
 * operations. The draw device replaced it in the third edition (2000),
 * when rio replaced 8 1/2. It has pixels of red, green and blue with an
 * alpha, and one compositing operation in place of the boolean ones
 * (Draw.mli).
 *
 * design:
 * The messages are kept and sent together. A write is a system call,
 * thousands of instructions to say that 45 bytes are a rectangle, and a
 * frame of a game has hundreds of them. So the library writes when
 * 8,000 bytes are kept or when it is asked to, as a C program's standard
 * output does, and for the same reason; Xlib does the same with its
 * requests (XFlush). The cost is the surprise of a program that draws
 * and sees nothing: the flush is part of the protocol ('v', which also
 * tells the screen to show what was drawn).
 *
 * References: draw(3) of Plan 9's manual, for the messages; draw(2) and
 * graphics(2), for the C library followed here (principia's
 * lib_graphics/libdraw, and its Graphics book for the kernel's side);
 * Rob Pike, "8 1/2, the Plan 9 Window System" (USENIX, 1991), on a
 * window system as a file server, and "Rio: Design of a Concurrent
 * Window System" (a talk's slides, 2000); Rob Pike,
 * "The Blit: A Multiplexed Graphics Terminal" (AT&T Bell
 * Laboratories Technical Journal, 1984). *)

type t

(* an image in the kernel, known by its number there. [r] is where it is
 * in the plane (in the screen's coordinates), and [repl] says whether
 * it repeats over all the plane (a colour is an image of one pixel that
 * does) *)
type image = { display : t; id : int; r : Rectangle.t; repl : bool }

(* a colour: red, green, blue, and how opaque it is, each 0 to 255 *)
type color = { red : int; green : int; blue : int; alpha : int }
val rgb : int -> int -> int -> color
val black : color
val white : color

(* a pixel's format, as Plan 9 writes it: "k1" is a bit of grey, "k8" a
 * byte of grey, and there are "r8g8b8", "x8r8g8b8" (here, the screen's
 * format), and others *)
type chan = string

(* opens the connection: /dev/draw/new, then its data file *)
val init : < Cap.draw; .. > -> t
(* returns the screen's format *)
val format : t -> chan
(* [hold d true] keeps the messages until [flush], however many there
 * are (otherwise they are sent as they pile up). For a meter, all the
 * device's time is then spent in the flush. *)
val hold : t -> bool -> unit
(* returns where the program draws: its window (inside the border) when
 * it runs in a window of a window system, otherwise all the screen. Ask
 * again when the window changed (Mouse's resized), because the image is
 * then another one. *)
val screen : t -> image
(* returns all the screen, which is image 0 of a connection (the one a
 * window system draws on) *)
val whole : t -> image

(* makes a new image, filled with a colour *)
val alloc : t -> Rectangle.t -> chan -> repl:bool -> color -> image
(* returns a colour to draw with: an image of one pixel, repeated *)
val color : t -> color -> image
(* returns the mask that hides nothing *)
val opaque : t -> image
val free : image -> unit
(* keeps what is drawn in an image from now on inside a rectangle of it
 * (its clipping rectangle, which at first is all of the image) *)
val clip : image -> Rectangle.t -> unit
(* gives an image its pixels, as rows of bytes packed by its format *)
val load : image -> Rectangle.t -> string -> unit
(* [load_sub img r pixels off n] does the same with the n bytes of a
 * larger array that start at off (for a program's own picture, so that
 * no copy of it is made to give it) *)
val load_sub : image -> Rectangle.t -> bytes -> int -> int -> unit
(* returns an image of the screen's format (the screen, or a window) as
 * Plan 9 writes one in a file (image(6), not compressed): its format
 * and the four numbers of its rectangle, each in 11 characters and a
 * space, then its pixels, as rows of bytes *)
val file : image -> string

(* Windows. [desktop] makes a screen's image a desktop, filled with an
 * image where there is no window. Then [window] makes windows on it,
 * which are images that may cover one another (the kernel draws what
 * shows of each and keeps the rest: these are Plan 9's layers), and
 * [top] brings one to the front. The desktop's number must be one that
 * no other program uses, so it is the caller's pid. *)
type desktop
val desktop : image -> image -> int -> desktop
val window : desktop -> Rectangle.t -> color -> image
val top : image -> unit
(* (sends the window to the back, behind the others) *)
val bottom : image -> unit
(* moves a window: the arguments are its corner in its own coordinates,
 * and where that corner is on the screen (it may differ from the first;
 * when it is off the screen, the window is hidden) *)
val origin : image -> Point.t -> Point.t -> image
(* gives an image a name, by which another program draws in it
 * ([named]) *)
val name : image -> string -> unit
val named : t -> string -> image

(* a message, for Draw: [message] writes a letter and its bytes, built
 * with the functions below, in the bytes kept until they are sent
 * ([out]) *)
type out
val message : t -> (out -> unit) -> unit
val char : out -> char -> unit
val byte : out -> int -> unit
val long : out -> int -> unit
val point : out -> Point.t -> unit
val rect : out -> Rectangle.t -> unit
(* sends a message alone, after the ones before it, and says whether
 * the device took it (it may be an extension that a kernel does not
 * have) *)
val accepted : t -> (out -> unit) -> bool

(* sends what was said so far, and shows it *)
val flush : t -> unit
(* ends the connection; the kernel frees its images *)
val close : t -> unit
