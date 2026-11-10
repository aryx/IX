(* TinyKernel.ml's calls: what TinyLibDraw.ml, TinyLibPlayground.ml,
 * TinyLibGUI.ml and the few lines of a program on them
 * (user/office.ml...) ask of tiny-kernel. One interface, and
 * three implementations, a program choosing one when it is linked:
 *
 *     tinykernel/TinyCalls.ml  on tiny-machine, by tiny-ml: externals,
 *                           mlsys.c's functions, the kernel's calls
 *     sdl/TinyCalls.ml      on the host, a window of SDL's: what is
 *                           drawn drawn by TinyKernelGraphics.ml and
 *                           shown, the mouse and the keys the window's,
 *                           the host's files and clock (tiny-office,
 *                           tiny-emacs... on the host: ../user/sdl/)
 *     stub/TinyCalls.ml     on the host, the tests': no kernel; what is
 *                           drawn kept in [drawn], for
 *                           TinyKernelGraphics.ml; no key, no clock, no
 *                           network (dune's default)
 *
 * On the host, a virtual library of dune's (dune, beside this file).
 *
 * The descriptors are tiny-kernel's: 0 the keys, 1 the console, 3 where
 * a program draws, 4 its mouse (a box: x, y, the buttons, a word each). *)

(* [u_write fd s]: 0 when all of s was written (where a program draws:
 * the drawing messages, TinyKernelGraphics.mli's) *)
val u_write : int -> string -> int

(* [u_read fd n]: up to n bytes, "" at the end *)
val u_read : int -> int -> string

(* [u_ready fds n until]: the first of fds' n descriptors that can be
 * read, waiting until the clock is until (0: no end), -1 then *)
val u_ready : int array -> int -> int -> int

(* the clock, 400 ticks a second *)
val u_ticks : unit -> int

(* the date, seconds since 2000-01-01 *)
val u_time : unit -> int

(* a seed for a program's first random number: the machine's, or the
 * clock when it has none *)
val u_seed : unit -> int

(* a path's entry (user.h's dirent: a name of 64 bytes, its type, links,
 * size and date, a word each), or "" when it is not there *)
val u_stat : string -> string

(* a file opened, flags as user.h's (below), its descriptor, or -1;
 * closed *)
val u_open : string -> int -> int

(* u_open's flags: to read (O_RDONLY, 0); to write it anew (O_WRONLY |
 * O_CREATE | O_TRUNC, 0x601); to write, made when it is not there
 * (O_WRONLY | O_CREATE, 0x201: an append seeks its end); to read and
 * write, made when it is not there (O_RDWR | O_CREATE, 0x202). (old:
 * the numbers where a file was opened) *)
val o_read : int
val o_anew : int
val o_write : int
val o_read_write : int
val u_close : int -> int

(* the console raw (1) or not (0): its ^C a key *)
val u_rawcons : int -> int

(* a connection to a machine's port: -1, none on the host *)
val u_dial : string -> int -> int

(* [u_spawn path args]: a child running the program at path (args: its
 * name first), not waited for; its pid, or -1. The window's: a program
 * of tiny-kernel's /bin is its host twin (/bin/play: tiny-play, else
 * mini-play; /bin/page: mini-page), found where this one is or on the
 * PATH; the stub's: -1 *)
val u_spawn : string -> string list -> int

(* the program's arguments: how many, the i-th (0 its name) *)
val u_argc : unit -> int
val u_arg : int -> string

(* what was written where a program draws, kept for a test (the stub's;
 * the window's draws it at once and keeps nothing) *)
val drawn : Buffer.t
