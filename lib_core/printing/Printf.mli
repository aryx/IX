(***********************************************************************)
(*                                                                     *)
(*                           Objective Caml                            *)
(*                                                                     *)
(*            Xavier Leroy, projet Cristal, INRIA Rocquencourt         *)
(*                                                                     *)
(*  Copyright 1996 Institut National de Recherche en Informatique et   *)
(*  en Automatique.  All rights reserved.  This file is distributed    *)
(*  under the terms of the GNU Library General Public License, with    *)
(*  the special exception on linking described in the file LICENSE.    *)
(*                                                                     *)
(***********************************************************************)

(** Formatted output functions. *)

val fprintf : out_channel -> ('a, out_channel, unit) format -> 'a
(** [fprintf outchan format arg1 ... argN] formats the arguments [arg1] to
    [argN] according to the format string [format], and outputs the
    resulting string on the channel [outchan].

    The conversions, after [%], optional flags ([-], [+], space, [#], [0])
    and an optional width and [.] precision (each may be [*], an argument):
    - [d], [i], [u], [x], [X], [o]: an integer, signed or unsigned decimal,
      hexadecimal, octal; after [l] an [int32], after [L] an [int64]
    - [s], [c], [b]: a string, a character, a boolean; [S], [C]: as OCaml
      writes them
    - [f], [e], [E], [g], [G]: a float; [h]: in hexadecimal
    - [a]: a printer and its argument; [t]: a printer alone
    - [!]: no argument, the output flushed; [%]: one [%] character *)

val printf : ('a, out_channel, unit) format -> 'a
(** Same as {!Printf.fprintf}, but output on [stdout]. *)

val eprintf : ('a, out_channel, unit) format -> 'a
(** Same as {!Printf.fprintf}, but output on [stderr]. *)

val sprintf : ('a, unit, string) format -> 'a
(** Same as {!Printf.fprintf}, but instead of printing on an output channel,
    return a string containing the result of formatting the arguments. *)

val bprintf : Buffer.t -> ('a, Buffer.t, unit) format -> 'a
(** Same as {!Printf.fprintf}, but instead of printing on an output channel,
    append the formatted arguments to the given extensible buffer (see
    module {!Buffer}). *)

val ksprintf : (string -> 'd) -> ('a, unit, string, 'd) format4 -> 'a
(** Same as {!Print.sprintf}, but instead of returning the string as result,
    after doing the formatting, [ksprintf] will pass the result string as
    argument to its first argument ("k" stands for "continuation"). *)

(** /* *)

(* For system use only.  Don't call directly. *)

val scan_format :
  string -> int -> (string -> int -> 'a) -> ('b -> 'c -> int -> 'a) ->
    ('e -> int -> 'a) -> (int -> 'a) -> 'a
