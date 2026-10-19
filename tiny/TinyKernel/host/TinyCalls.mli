(* TinyKernel.ml's calls, for a program built by OCaml, so that it runs
 * on the host: what TinyLibDraw.ml, TinyLibPlayground.ml, TinyLibGUI.ml
 * and the few lines of a program on them (TinyKernel/user/office.ml...)
 * ask of tiny-kernel. On tiny-machine these names are externals
 * (TinyKernel/libml/TinyCalls.ml, which names mlsys.c's functions); tiny-ml
 * reads `open TinyCalls` and leaves it.
 *
 * A virtual library of dune's: this interface, and two
 * implementations, a program choosing one when it is linked:
 *
 *     stub/TinyCalls.ml     the tests': no kernel; what is drawn kept in
 *                           [drawn], for TinyKernelGraphics.ml; no key,
 *                           no clock, no network (the default)
 *     ../../sdl/TinyCalls.ml  a window of SDL's: what is drawn drawn by
 *                           TinyKernelGraphics.ml and shown, the mouse
 *                           and the keys the window's, the host's files
 *                           and clock (tiny-office, tiny-emacs... on the
 *                           host)
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

(* a file opened (flags as user.h's: 0 to read, 0x601 to write it anew),
 * its descriptor, or -1; closed *)
val u_open : string -> int -> int
val u_close : int -> int

(* the console raw (1) or not (0): its ^C a key *)
val u_rawcons : int -> int

(* a connection to a machine's port: -1, none on the host *)
val u_dial : string -> int -> int

(* the program's arguments: how many, the i-th (0 its name) *)
val u_argc : unit -> int
val u_arg : int -> string

(* what was written where a program draws, kept for a test (the stub's;
 * the window's draws it at once and keeps nothing) *)
val drawn : Buffer.t
