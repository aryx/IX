(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*                           Daniel C. Buenzli                            *)
(*                                                                        *)
(*   Copyright 2014 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

external format_int : string -> int -> string = "format_int"

let err_no_pred = "U+0000 has no predecessor"
let err_no_succ = "U+10FFFF has no successor"
let err_not_sv i = format_int "%X" i ^ " is not an Unicode scalar value"
let err_not_latin1 u = "U+" ^ format_int "%04X" u ^ " is not a latin1 character"

type t = int

let lo_bound = 0xD7FF
let hi_bound = 0xE000









(* ix: OCaml's later functions, those ix's programs use *)

(* a decoded character: 0xDUUUUUU, D's high bit set when valid, its
 * three low bits the bytes read, UUUUUU the character (U+FFFD when
 * not valid); OCaml's *)
type utf_decode = int
let utf_decode n u = ((8 lor n) lsl 24) lor u
