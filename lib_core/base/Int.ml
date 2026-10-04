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

let zero = 0
let one = 1
let minus_one = -1
external div : int -> int -> int = "%divint"
external rem : int -> int -> int = "%modint"
let abs x = if x >= 0 then x else -x
let max_int = (-1) lsr 1
let min_int = max_int + 1

let equal : t -> t -> bool = ( = )
let compare : t -> t -> int = compare

external to_float : int -> float = "%floatofint"
external of_float : float -> int = "%intoffloat"

external int_of_string : string -> int = "int_of_string"
let of_string s = try Some (int_of_string s) with Failure _ -> None

external format_int : string -> int -> string = "format_int"
let to_string x = format_int "%d" x

(* ix: OCaml's later functions, those ix's programs use *)

let min (a : int) (b : int) = if a <= b then a else b
let max (a : int) (b : int) = if a >= b then a else b
