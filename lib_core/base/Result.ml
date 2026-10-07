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

type ('a, 'e) t = ('a, 'e) result = Ok of 'a | Error of 'e

let is_ok = function Ok _ -> true | Error _ -> false
let is_error = function Error _ -> true | Ok _ -> false
let get_ok = function Ok v -> v | Error _ -> invalid_arg "result is Error _"
let get_error = function Error e -> e | Ok _ -> invalid_arg "result is Ok _"
(* ("Error e -> Error e", not "Error _ as e -> e": the alias would keep
   the success type the same on both sides) *)
let bind r f = match r with Ok v -> f v | Error e -> Error e
let map f r = match r with Ok v -> Ok (f v) | Error e -> Error e
let to_option = function Ok v -> Some v | Error _ -> None
