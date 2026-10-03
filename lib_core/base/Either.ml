(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*         Gabriel Scherer, projet Parsifal, INRIA Saclay                 *)
(*                                                                        *)
(*   Copyright 2019 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

type ('a, 'b) t = Left of 'a | Right of 'b

let is_left = function Left _ -> true | Right _ -> false
let is_right = function Left _ -> false | Right _ -> true
let find_left = function Left v -> Some v | Right _ -> None
let find_right = function Left _ -> None | Right v -> Some v
