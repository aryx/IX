(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's mini-chrome's languages/javascript/values/Js_operators.ml (its 8af888e) (docs/plans/plan_browser.md) *)

(* See Js_operators.mli *)
open Js_value

(* ==: the same as === for the same kinds; null and undefined equal
 * each other only; else numbers compared, a string or a boolean made
 * one, an object its primitive (ECMA-262 5.1, 11.9.3) *)
let rec loose_equal (a : value) (b : value) : bool =
  match (a, b) with
  | Rope _, _ | _, Rope _ -> loose_equal (flat a) (flat b)
  | (Undefined | Null), (Undefined | Null) -> true
  | (Undefined | Null), _ | _, (Undefined | Null) -> false
  | Number _, Number _ | String _, String _ | Bool _, Bool _ | Object _, Object _ | Symbol _, _ | _, Symbol _ -> strict_equal a b
  | Number x, String _ -> x = to_number b
  | String _, Number y -> to_number a = y
  | Bool _, _ -> loose_equal (Number (to_number a)) b
  | _, Bool _ -> loose_equal a (Number (to_number b))
  | Object _, _ -> loose_equal (to_primitive a) b
  | _, Object _ -> loose_equal a (to_primitive b)

(* a number as the 32 bits the bitwise operators work on: its integer
 * part, modulo 2^32 (NaN and the infinities: 0) *)
let to_int32 (v : value) : int32 =
  let f = to_number v in
  if Float.is_nan f || Float.abs f = infinity then 0l
  else Int64.to_int32 (Int64.of_float (Float.rem (Float.trunc f) 4294967296.))

let of_int32 (i : int32) : value = Number (Int32.to_float i)

let arithmetic_simple (op : string) (a : value) (b : value) : value =
  match op with
  | "+" -> (
      match (to_primitive a, to_primitive b) with
      (* a long text is a rope, not a copy of the two (Js_value.join) *)
      | ((String _ | Rope _) as x), ((String _ | Rope _) as y) -> join x y
      | ((String _ | Rope _) as x), y -> join x (String (to_string y))
      | x, ((String _ | Rope _) as y) -> join (String (to_string x)) y
      | x, y -> Number (to_number x +. to_number y))
  | "-" -> Number (to_number a -. to_number b)
  | "*" -> Number (to_number a *. to_number b)
  | "/" -> Number (to_number a /. to_number b)
  | "%" -> Number (Float.rem (to_number a) (to_number b))
  | "**" -> Number (Float.pow (to_number a) (to_number b))
  (* the bits: both sides made 32-bit integers, the answer one too; a
   * shift's count is its low five bits; >>> fills with zeros, so its
   * answer is not negative *)
  | "&" -> of_int32 (Int32.logand (to_int32 a) (to_int32 b))
  | "|" -> of_int32 (Int32.logor (to_int32 a) (to_int32 b))
  | "^" -> of_int32 (Int32.logxor (to_int32 a) (to_int32 b))
  | "<<" -> of_int32 (Int32.shift_left (to_int32 a) (Int32.to_int (to_int32 b) land 31))
  | ">>" -> of_int32 (Int32.shift_right (to_int32 a) (Int32.to_int (to_int32 b) land 31))
  | ">>>" ->
      Number (Int64.to_float (Int64.logand (Int64.of_int32 (Int32.shift_right_logical (to_int32 a) (Int32.to_int (to_int32 b) land 31))) 0xFFFFFFFFL))
  | "<" | ">" | "<=" | ">=" -> (
      let cmp =
        match (flat (to_primitive a), flat (to_primitive b)) with
        | String x, String y -> Some (compare x y)
        | x, y ->
            let x = to_number x and y = to_number y in
            if Float.is_nan x || Float.is_nan y then None else Some (compare x y)
      in
      match cmp with
      | None -> Bool false
      | Some c -> Bool (match op with "<" -> c < 0 | ">" -> c > 0 | "<=" -> c <= 0 | _ -> c >= 0))
  | "===" -> Bool (strict_equal a b)
  | "!==" -> Bool (not (strict_equal a b))
  | "==" -> Bool (loose_equal a b)
  | "!=" -> Bool (not (loose_equal a b))
  | _ -> throw "SyntaxError" ("unknown operator " ^ op)

(* opti: two numbers, what most operators are given: the answer at
 * once, with no conversion to a primitive, then to a number, then (the
 * bits) to 32 bits by a remainder; anything else is arithmetic_simple's.
 * 3M turns of s = (s + i) | 0: 1,900 ms to 1,200 *)
let arithmetic_opti (op : string) (a : value) (b : value) : value =
  (* a 32-bit integer already (NaN is not) *)
  let small (x : float) : bool = x >= -2147483648. && x <= 2147483647. && Float.of_int (Float.to_int x) = x in
  match (a, b) with
  | Number x, Number y -> (
      match op with
      | "+" -> Number (x +. y)
      | "-" -> Number (x -. y)
      | "*" -> Number (x *. y)
      | "<" -> Bool (x < y)
      | ">" -> Bool (x > y)
      | "<=" -> Bool (x <= y)
      | ">=" -> Bool (x >= y)
      | "===" | "==" -> Bool (x = y)
      | "!==" | "!=" -> Bool (x <> y)
      | "|" when small x && small y -> Number (Float.of_int (Float.to_int x lor Float.to_int y))
      | "&" when small x && small y -> Number (Float.of_int (Float.to_int x land Float.to_int y))
      | "^" when small x && small y -> Number (Float.of_int (Float.to_int x lxor Float.to_int y))
      | ">>" when small x && small y -> Number (Float.of_int (Float.to_int x asr (Float.to_int y land 31)))
      | _ -> arithmetic_simple op a b)
  | _ -> arithmetic_simple op a b

let arithmetic (op : string) (a : value) (b : value) : value = if !Mini_opti.enabled then arithmetic_opti op a b else arithmetic_simple op a b
