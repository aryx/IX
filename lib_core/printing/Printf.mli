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

    A conversion comes after [%], optional flags ([-], [+], space, [#],
    [0]), and an optional width and [.] precision (each may be [*], which
    takes it from an argument). The conversions are:
    - [d], [i], [u], [x], [X], [o] print an integer, as a signed or
      unsigned decimal, in hexadecimal, or in octal; after [l] the
      integer is an [int32], and after [L] an [int64].
    - [s], [c], [b] print a string, a character, a boolean; [S] and [C]
      print a string and a character as OCaml writes them.
    - [f], [e], [E], [g], [G] print a float; [h] prints it in
      hexadecimal.
    - [a] takes a printer and its argument; [t] takes a printer alone.
    - [!] takes no argument and flushes the output; [%] prints one [%]
      character. *)

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
(** Same as {!Printf.sprintf}, but instead of returning the string as result,
    after doing the formatting, [ksprintf] will pass the result string as
    argument to its first argument ("k" stands for "continuation"). *)

(** /* *)

(* For system use only.  Don't call directly. *)

val scan_format :
  string -> int -> (string -> int -> 'a) -> ('b -> 'c -> int -> 'a) ->
    ('e -> int -> 'a) -> (int -> 'a) -> 'a
