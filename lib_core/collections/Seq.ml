(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*                 Simon Cruanes                                          *)
(*                                                                        *)
(*   Copyright 2017 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

(* Module [Seq]: functional iterators *)

(* ix: OCaml 4.14's seq.ml, the part ix's programs use (its 77
 * functions are 11 here); the definitions as they are there *)

type 'a node =
  | Nil
  | Cons of 'a * 'a t

and 'a t = unit -> 'a node

let empty () = Nil

let rec append seq1 seq2 () =
  match seq1() with
  | Nil -> seq2()
  | Cons (x, next) -> Cons (x, append next seq2)

let rec map f seq () = match seq() with
  | Nil -> Nil
  | Cons (x, next) -> Cons (f x, map f next)

let rec filter_map f seq () = match seq() with
  | Nil -> Nil
  | Cons (x, next) ->
      match f x with
        | None -> filter_map f next ()
        | Some y -> Cons (y, filter_map f next)

let rec filter f seq () = match seq() with
  | Nil -> Nil
  | Cons (x, next) ->
      if f x
      then Cons (x, filter f next)
      else filter f next ()

let rec flat_map f seq () = match seq () with
  | Nil -> Nil
  | Cons (x, next) ->
    append (f x) (flat_map f next) ()

let concat_map = flat_map

let rec fold_left f acc seq =
  match seq () with
    | Nil -> acc
    | Cons (x, next) ->
        let acc = f acc x in
        fold_left f acc next

let rec iter f seq =
  match seq () with
    | Nil -> ()
    | Cons (x, next) ->
        f x;
        iter f next

let rec init_aux f i j () =
  if i < j then begin
    Cons (f i, init_aux f (i + 1) j)
  end
  else
    Nil

let init n f =
  if n < 0 then
    invalid_arg "Seq.init"
  else
    init_aux f 0 n

let rec take_aux n xs =
  if n = 0 then
    empty
  else
    fun () ->
      match xs() with
      | Nil ->
          Nil
      | Cons (x, xs) ->
          Cons (x, take_aux (n-1) xs)

let take n xs =
  if n < 0 then invalid_arg "Seq.take";
  take_aux n xs

let rec take_while p xs () =
  match xs() with
  | Nil ->
      Nil
  | Cons (x, xs) ->
      if p x then Cons (x, take_while p xs) else Nil

let rec drop_while p xs () =
  match xs() with
  | Nil ->
      Nil
  | Cons (x, xs) as node ->
      if p x then drop_while p xs () else node

let return x () = Cons (x, empty)
