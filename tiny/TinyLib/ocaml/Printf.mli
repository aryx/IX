(* TinyLib: lib_core/printing/Printf, the part the tiny programs call (tiny/TinyLib/README.md) *)
(* Xavier Leroy, projet Cristal, INRIA Rocquencourt
 * Objective Caml. Copyright 1996 INRIA. GNU Library General Public License, with the linking exception of OCaml's LICENSE. *)

(** Formatted output functions. *)

val fprintf : out_channel -> ('a, out_channel, unit) format -> 'a
(** [fprintf outchan format arg1 ... argN]

    The conversions, after [%], optional flags ([-], [+], space, [#], [0])
    and an optional width and [.] precision (each may be [*], an argument):
    - [d], [i], [u], [x], [X], [o]: an integer, signed or unsigned decimal,
      hexadecimal, octal; after [l] an [int32], after [L] an [int64]
    - [s], [c], [b]: a string, a character, a boolean; [S], [C]: as OCaml
      writes them
    - no float (TinyLib/c/ has no formatter for one)
    - [a]: a printer and its argument; [t]: a printer alone
    - [!]: no argument, the output flushed; [%]: one [%] character *)

val printf : ('a, out_channel, unit) format -> 'a
(** On [stdout]. *)

val eprintf : ('a, out_channel, unit) format -> 'a
(** On [stderr]. *)

val sprintf : ('a, unit, string) format -> 'a

val bprintf : Buffer.t -> ('a, Buffer.t, unit) format -> 'a
(** Appended to the buffer. *)

val ksprintf : (string -> 'd) -> ('a, unit, string, 'd) format4 -> 'a
(** As {!Printf.sprintf}, the string given to the first argument (a
    continuation). *)

(** /* *)

(* For system use only.  Don't call directly. *)

val scan_format :
  string -> int -> (string -> int -> 'a) -> ('b -> 'c -> int -> 'a) ->
    ('e -> int -> 'a) -> (int -> 'a) -> 'a
