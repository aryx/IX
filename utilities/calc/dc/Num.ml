(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Num.mli *)

(* the digits, the lowest first, none of them 0 at the top; 0 is no
 * digit and is not negative *)
type t = { negative : bool; mag : int array }

let zero = { negative = false; mag = [||] }

let norm negative (mag : int array) =
  let rec top k = if k > 0 && mag.(k - 1) = 0 then top (k - 1) else k in
  let n = top (Array.length mag) in
  if n = 0 then zero else { negative; mag = (if n = Array.length mag then mag else Array.sub mag 0 n) }

let of_int n =
  let rec go n acc = if n = 0 then List.rev acc else go (n / 100) ((n mod 100) :: acc) in
  norm (n < 0) (Array.of_list (go (abs n) []))

let is_zero x = Array.length x.mag = 0
let is_neg x = x.negative
let neg x = if is_zero x then x else { x with negative = not x.negative }
let digits x = x.mag

let cmp_mag (a : int array) (b : int array) =
  if Array.length a <> Array.length b then compare (Array.length a) (Array.length b)
  else begin
    let rec go k = if k < 0 then 0 else if a.(k) <> b.(k) then compare a.(k) b.(k) else go (k - 1) in
    go (Array.length a - 1)
  end

let compare x y =
  if x.negative <> y.negative then (if x.negative then -1 else 1)
  else if x.negative then cmp_mag y.mag x.mag else cmp_mag x.mag y.mag

let add_mag (a : int array) (b : int array) =
  let n = max (Array.length a) (Array.length b) in
  let r = Array.make (n + 1) 0 in
  let carry = ref 0 in
  for k = 0 to n - 1 do
    let s = (if k < Array.length a then a.(k) else 0) + (if k < Array.length b then b.(k) else 0) + !carry in
    r.(k) <- s mod 100;
    carry := s / 100
  done;
  r.(n) <- !carry;
  r

(* a - b, a >= b *)
let sub_mag (a : int array) (b : int array) =
  let r = Array.make (Array.length a) 0 in
  let borrow = ref 0 in
  for k = 0 to Array.length a - 1 do
    let s = a.(k) - (if k < Array.length b then b.(k) else 0) - !borrow in
    if s < 0 then (r.(k) <- s + 100; borrow := 1) else (r.(k) <- s; borrow := 0)
  done;
  r

let add x y =
  if x.negative = y.negative then norm x.negative (add_mag x.mag y.mag)
  else if cmp_mag x.mag y.mag >= 0 then norm x.negative (sub_mag x.mag y.mag)
  else norm y.negative (sub_mag y.mag x.mag)

let sub x y = add x (neg y)

let mul_mag (a : int array) (b : int array) =
  let r = Array.make (Array.length a + Array.length b + 1) 0 in
  Array.iteri (fun i ai ->
    let carry = ref 0 in
    Array.iteri (fun j bj ->
      let s = r.(i + j) + (ai * bj) + !carry in
      r.(i + j) <- s mod 100;
      carry := s / 100) b;
    r.(i + Array.length b) <- r.(i + Array.length b) + !carry) a;
  r

let mul x y = norm (x.negative <> y.negative) (mul_mag x.mag y.mag)

(* a digit at a time from the top: the remainder so far with the next
 * digit under it, and how many times the divisor goes in it, guessed
 * from their first digits then made right *)
let divmod_mag (a : int array) (b : int array) =
  let q = Array.make (Array.length a) 0 in
  let r = ref [||] in
  let nb = Array.length b in
  let top (m : int array) k = if k >= 0 && k < Array.length m then m.(k) else 0 in
  for k = Array.length a - 1 downto 0 do
    r := (norm false (Array.append [| a.(k) |] !r)).mag;
    if cmp_mag !r b >= 0 then begin
      let num = (top !r nb * 10000) + (top !r (nb - 1) * 100) + top !r (nb - 2) in
      let den = (top b (nb - 1) * 100) + top b (nb - 2) in
      let guess = ref (min 99 (num / den)) in
      let times d = (norm false (mul_mag b [| d |])).mag in
      while cmp_mag (times !guess) !r > 0 do decr guess done;
      q.(k) <- !guess;
      r := (norm false (sub_mag !r (times !guess))).mag
    end
  done;
  (q, !r)

let divmod x y =
  if is_zero y then raise Division_by_zero;
  let q, r = divmod_mag x.mag y.mag in
  (norm (x.negative <> y.negative) q, norm x.negative r)

let pow10 n =
  let mag = Array.make ((n / 2) + 1) 0 in
  mag.(n / 2) <- (if n mod 2 = 1 then 10 else 1);
  { negative = false; mag }

let rec pow x n = if n <= 0 then of_int 1 else let h = pow x (n / 2) in if n mod 2 = 0 then mul h h else mul x (mul h h)

(* Newton's steps from above, to the first that does not go down *)
let sqrt x =
  if is_zero x then x
  else begin
    let two = of_int 2 in
    let rec go r =
      let next = fst (divmod (add r (fst (divmod x r))) two) in
      if compare next r >= 0 then r else go next in
    go (pow10 (Array.length x.mag + 1))
  end

let to_int x =
  (* (an int of 31 bits: four digits and a half at most) *)
  let n = Array.length x.mag in
  if n > 4 then (if x.negative then min_int else max_int)
  else begin
    let v = ref 0 in
    for k = n - 1 downto 0 do v := (!v * 100) + x.mag.(k) done;
    if x.negative then - !v else !v
  end

let encode x =
  if not x.negative then String.init (Array.length x.mag) (fun k -> Char.chr x.mag.(k))
  else begin
    (* 100^n - |x|, its top digit left out when 99: the -1 after says it *)
    let n = Array.length x.mag in
    let c = Array.make n 0 in
    let carry = ref 0 in
    for k = 0 to n - 1 do
      let d = 100 - x.mag.(k) - !carry in
      if d >= 100 then (c.(k) <- d - 100; carry := 0) else (c.(k) <- d; carry := 1)
    done;
    let n = if n > 0 && c.(n - 1) = 99 then n - 1 else n in
    String.init (n + 1) (fun k -> if k < n then Char.chr c.(k) else '\255')
  end

let decode s =
  let acc = ref zero in
  let hundred = of_int 100 in
  for k = String.length s - 1 downto 0 do
    let b = Char.code s.[k] in
    acc := add (mul !acc hundred) (of_int (if b >= 128 then b - 256 else b))
  done;
  !acc
