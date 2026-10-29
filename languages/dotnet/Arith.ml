(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Arith.mli *)

open Value

let i4 (n : int) : value = I4 (Int32.of_int n)
let bool_v (b : bool) : value = if b then I4 Int32.one else I4 Int32.zero

let truthy (v : value) : bool =
  match v with
  | I4 n -> Int32.compare n Int32.zero <> 0
  | I8 n -> Int64.compare n Int64.zero <> 0
  | R8 f -> f <> 0.0
  | Null -> false
  | _ -> true

let int_of (v : value) : int =
  match v with
  | I4 n -> Int32.to_int n
  | I8 n -> Int64.to_int n
  | _ -> Frame.error "an integer expected"

(* unsigned, as an int64 *)
let u32 (n : int32) : int64 = Int64.logand (Int64.of_int32 n) 0xFFFFFFFFL

let ucompare64 (a : int64) (b : int64) : int =
  Int64.compare (Int64.add a Int64.min_int) (Int64.add b Int64.min_int)

(* a comparison of two values; None when unordered (a NaN) *)
let compare_values (un : bool) (a : value) (b : value) : int option =
  match a, b with
  | I4 x, I4 y -> Some (if un then Int64.compare (u32 x) (u32 y) else Int32.compare x y)
  | I8 x, I8 y -> Some (if un then ucompare64 x y else Int64.compare x y)
  | I4 x, I8 y -> Some (Int64.compare (Int64.of_int32 x) y)
  | I8 x, I4 y -> Some (Int64.compare x (Int64.of_int32 y))
  | R8 x, R8 y -> if Float.is_nan x || Float.is_nan y then None else Some (compare x y)
  | Null, Null -> Some 0
  | Null, _ -> Some (-1)
  | _, Null -> Some 1
  | Obj x, Obj y -> Some (if x == y then 0 else 1)
  | Str x, Str y -> Some (if x == y then 0 else 1)
  | Fn x, Fn y -> Some (if x == y then 0 else 1)
  | _ -> Some 1

let test (c : Il.cmp) (un : bool) (a : value) (b : value) : bool =
  match compare_values un a b with
  | None -> un && c <> Il.Eq || c = Il.Ne
  | Some k ->
      match c with
      | Il.Eq -> k = 0 | Il.Ne -> k <> 0 | Il.Ge -> k >= 0
      | Il.Gt -> k > 0 | Il.Le -> k <= 0 | Il.Lt -> k < 0

let divide_by_zero () = Frame.throw_new "System.DivideByZeroException" "Attempted to divide by zero."

let binop (op : Il.binop) (a : value) (b : value) : value =
  match a, b with
  | I4 x, I4 y -> (
      match op with
      | Add -> I4 (Int32.add x y) | Sub -> I4 (Int32.sub x y) | Mul -> I4 (Int32.mul x y)
      | Div ->
          if Int32.compare y Int32.zero = 0 then divide_by_zero ()
          else if Int32.compare x Int32.min_int = 0 && Int32.compare y Int32.minus_one = 0 then Frame.overflow ()
          else I4 (Int32.div x y)
      | Rem ->
          if Int32.compare y Int32.zero = 0 then divide_by_zero ()
          else if Int32.compare y Int32.minus_one = 0 then I4 Int32.zero
          else I4 (Int32.rem x y)
      | Div_un ->
          if Int32.compare y Int32.zero = 0 then divide_by_zero ()
          else I4 (Int64.to_int32 (Int64.div (u32 x) (u32 y)))
      | Rem_un ->
          if Int32.compare y Int32.zero = 0 then divide_by_zero ()
          else I4 (Int64.to_int32 (Int64.rem (u32 x) (u32 y)))
      | And -> I4 (Int32.logand x y) | Or -> I4 (Int32.logor x y) | Xor -> I4 (Int32.logxor x y)
      | Shl -> I4 (Int32.shift_left x (Int32.to_int y land 31))
      | Shr -> I4 (Int32.shift_right x (Int32.to_int y land 31))
      | Shr_un -> I4 (Int32.shift_right_logical x (Int32.to_int y land 31))
      | Add_ovf | Sub_ovf | Mul_ovf ->
          let r = (match op with Add_ovf -> Int64.add | Sub_ovf -> Int64.sub | _ -> Int64.mul)
                    (Int64.of_int32 x) (Int64.of_int32 y) in
          if Int64.compare r (Int64.of_int32 Int32.max_int) > 0 || Int64.compare r (Int64.of_int32 Int32.min_int) < 0
          then Frame.overflow () else I4 (Int64.to_int32 r)
      | Add_ovf_un | Sub_ovf_un | Mul_ovf_un ->
          let r = (match op with Add_ovf_un -> Int64.add | Sub_ovf_un -> Int64.sub | _ -> Int64.mul)
                    (u32 x) (u32 y) in
          if Int64.compare r 0xFFFFFFFFL > 0 || Int64.compare r 0L < 0 then Frame.overflow ()
          else I4 (Int64.to_int32 r))
  | (I8 _ | I4 _), (I8 _ | I4 _) -> (
      let w v = match v with I8 n -> n | I4 n -> Int64.of_int32 n | _ -> assert false in
      let x = w a and y = w b in
      match op with
      | Shl -> I8 (Int64.shift_left x (int_of b land 63))
      | Shr -> I8 (Int64.shift_right x (int_of b land 63))
      | Shr_un -> I8 (Int64.shift_right_logical x (int_of b land 63))
      | Add | Add_ovf | Add_ovf_un -> I8 (Int64.add x y)
      | Sub | Sub_ovf | Sub_ovf_un -> I8 (Int64.sub x y)
      | Mul | Mul_ovf | Mul_ovf_un -> I8 (Int64.mul x y)
      | Div | Div_un -> if Int64.compare y 0L = 0 then divide_by_zero () else I8 (Int64.div x y)
      | Rem | Rem_un -> if Int64.compare y 0L = 0 then divide_by_zero () else I8 (Int64.rem x y)
      | And -> I8 (Int64.logand x y) | Or -> I8 (Int64.logor x y) | Xor -> I8 (Int64.logxor x y))
  | R8 x, R8 y -> (
      match op with
      | Add -> R8 (x +. y) | Sub -> R8 (x -. y) | Mul -> R8 (x *. y)
      | Div -> R8 (x /. y) | Rem -> R8 (Float.rem x y)
      | _ -> Frame.error "a float in an integer's operation")
  | _ -> Frame.error "an arithmetic on what is not a number"

let conv (k : Il.kind) (ovf : bool) (un : bool) (v : value) : value =
  (* the value as an int64, and a float if it is one *)
  let wide = match v with
    | I4 n -> if un then u32 n else Int64.of_int32 n
    | I8 n -> n
    | R8 f -> Int64.of_float f
    | Ptr _ | Obj _ | Str _ | Null | Fn _ -> 0L
    | _ -> Frame.error "a conversion of what is not a number" in
  let check lo hi =
    if ovf && (Int64.compare wide lo < 0 || Int64.compare wide hi > 0
               || (match v with R8 f -> Float.is_nan f | _ -> false)) then Frame.overflow () in
  let small bits signed =
    let m = Int64.of_int ((1 lsl bits) - 1) in
    let x = Int64.logand wide m in
    let x = if signed && Int64.compare x (Int64.of_int (1 lsl (bits - 1))) >= 0 then Int64.sub x (Int64.add m 1L) else x in
    I4 (Int64.to_int32 x) in
  match k with
  | K_i1 -> check (-128L) 127L; small 8 true
  | K_u1 -> check 0L 255L; small 8 false
  | K_i2 -> check (-32768L) 32767L; small 16 true
  | K_u2 -> check 0L 65535L; small 16 false
  | K_i4 | K_i -> check (-2147483648L) 2147483647L;
      (match v with Ptr _ | Obj _ | Str _ | Fn _ -> v | _ -> I4 (Int64.to_int32 wide))
  | K_u4 | K_u -> check 0L 4294967295L;
      (match v with Ptr _ | Obj _ | Str _ | Fn _ -> v | _ -> I4 (Int64.to_int32 wide))
  | K_i8 -> (match v with I4 n when not un -> I8 (Int64.of_int32 n) | _ -> I8 wide)
  | K_u8 -> (match v with I4 n -> I8 (u32 n) | _ -> I8 wide)
  | K_r4 -> let f = (match v with R8 f -> f | I4 n when un -> Int64.to_float (u32 n) | _ -> Int64.to_float wide) in
      R8 (Int32.float_of_bits (Int32.bits_of_float f))
  | K_r8 -> R8 (match v with R8 f -> f | _ -> Int64.to_float wide)
  | K_ref -> v
