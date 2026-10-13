(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* A picture as it is written, in pic's language: what Pic_parser makes
 * and Pic draws (see Pic.mli). *)

(* n, s, e, w, ne, nw, se, sw, c, start, end *)
type corner = string

type expr =
  | Num of float
  | Var of string
  | Bin of char * expr * expr
  | Neg of expr
  (* A.e.x: how far right a place is, or up (y) *)
  | Coord of place * string

and place =
  (* A, A.ne, Block.Inner.s *)
  | Named of string list * corner option
  (* last box (-1), 2nd circle *)
  | Nth of int * string * corner option
  | Here

type position =
  | Xy of expr * expr
  | Place of place
  (* a place and how far from it *)
  | Shift of position * expr * expr
  (* 0.3 <A, B>: that part of the way from A to B *)
  | Between of expr * position * position

type kind = Box | Circle | Ellipse | Line | Arrow | Arc | Spline | Move | Text | Block of statement list

and attr =
  | Wid of expr
  | Ht of expr
  | Rad of expr
  | From of position
  | To of position
  | At of position
  (* which of its corners is at the place said by At *)
  | With of corner
  | Then
  (* up, down, left, right, and how far *)
  | Go of string * expr option
  (* a number alone: that far, the way it was going *)
  | Dist of expr
  | Dashed
  | Dotted
  | Invis
  | Fill
  | Same
  | Chop
  (* an arrow's head at its start, at its end *)
  | Head of bool * bool
  | Cw
  | Ccw
  | Str of string
  (* ljust, rjust, above, below: of the string before *)
  | Just of string

and statement =
  | Object of string option * kind * attr list
  | Direction of string
  | Assign of string * expr
