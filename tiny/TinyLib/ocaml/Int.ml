(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*                         The OCaml programmers                          *)
(*                                                                        *)
(*   Copyright 2018 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

type t = int

external div : int -> int -> int = "%divint"
external rem : int -> int -> int = "%modint"



external int_of_string : string -> int = "int_of_string"

external format_int : string -> int -> string = "format_int"

(* ix: OCaml's later functions, those ix's programs use *)

let max (a : int) (b : int) = if a >= b then a else b
