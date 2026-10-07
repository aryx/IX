(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Cformat.mli *)

type spec = { minus : bool; plus : bool; space : bool; zero : bool; sharp : bool; width : int; precision : int option; verb : char }

let parse text =
  let n = String.length text in
  let digit k = k < n && text.[k] >= '0' && text.[k] <= '9' in
  let rec number k acc = if digit k then number (k + 1) ((acc * 10) + Char.code text.[k] - 48) else (k, acc) in
  let rec flags k (s : spec) =
    if k >= n then (k, s)
    else match text.[k] with
      | '-' -> flags (k + 1) { s with minus = true }
      | '+' -> flags (k + 1) { s with plus = true }
      | ' ' -> flags (k + 1) { s with space = true }
      | '#' -> flags (k + 1) { s with sharp = true }
      | '0' -> flags (k + 1) { s with zero = true }
      | _ -> (k, s) in
  let k, s = flags 1 { minus = false; plus = false; space = false; zero = false; sharp = false; width = 0; precision = None; verb = text.[n - 1] } in
  let k, width = number k 0 in
  let precision = if k < n && text.[k] = '.' then Some (snd (number (k + 1) 0)) else None in
  { s with width; precision }

(* the sign, the digits and the padding put together *)
let pad (s : spec) sign body =
  let len = String.length sign + Utf8.length body in
  if len >= s.width then sign ^ body
  else if s.minus then sign ^ body ^ String.make (s.width - len) ' '
  else if s.zero then sign ^ String.make (s.width - len) '0' ^ body
  else String.make (s.width - len) ' ' ^ sign ^ body

let sign (s : spec) negative = if negative then "-" else if s.plus then "+" else if s.space then " " else ""

(* A float's digits, as Plan 9's print finds them: the fewest that say
 * the number (0.1 is 1, not 1000000000000000055...), then rounded to
 * what is asked, a half upward (so %.1f of 2.55 is 2.6 and %.0f of 2.5
 * is 3, where C's are 2.5 and 2: C rounds the number's exact binary
 * value). The digits and the exponent of the first: d.ddd * 10^e *)
let decimal a =
  if a = 0. then ("0", 0)
  else begin
    let text d = Printf.sprintf "%.*e" d a in
    (* (if d digits say it, more do: by halves) *)
    let rec search low high = if low >= high then low else let mid = (low + high) / 2 in if float_of_string (text mid) = a then search low mid else search (mid + 1) high in
    let m = text (search 0 16) in
    let e = String.index m 'e' in
    let exp = int_of_string (String.sub m (e + 1) (String.length m - e - 1)) in
    (String.make 1 m.[0] ^ (if e > 2 then String.sub m 2 (e - 2) else ""), exp)
  end

(* the digits cut to n of them (n >= 0), the last one up when what is
 * cut starts with 5 or more; a carry out of the first makes one more
 * digit: the exponent is one more *)
let round (digits, exp) n =
  let len = String.length digits in
  if n >= len then (digits ^ String.make (n - len) '0', exp)
  else begin
    let kept = Bytes.of_string (String.sub digits 0 n) in
    let rec carry k =
      if k < 0 then true
      else if Bytes.get kept k = '9' then (Bytes.set kept k '0'; carry (k - 1))
      else (Bytes.set kept k (Char.chr (Char.code (Bytes.get kept k) + 1)); false) in
    if digits.[n] >= '5' && carry (n - 1) then ("1" ^ Bytes.to_string kept, exp + 1) else (Bytes.to_string kept, exp)
  end

let strip s = let rec last k = if k > 0 && s.[k - 1] = '0' then last (k - 1) else k in String.sub s 0 (last (String.length s))
let point whole frac = if frac = "" then whole else whole ^ "." ^ frac

(* d.ddde+xx, p digits after the point *)
let exponential a p upper zeros =
  let digits, exp = round (decimal a) (p + 1) in
  let digits = String.sub digits 0 (p + 1) in
  let frac = String.sub digits 1 p in
  point (String.make 1 digits.[0]) (if zeros then frac else strip frac)
  ^ Printf.sprintf "%c%c%02d" (if upper then 'E' else 'e') (if exp < 0 then '-' else '+') (abs exp)

(* ddd.ddd, p digits after the point *)
let fixed a p zeros =
  let digits, exp = decimal a in
  (* how many of the digits are wanted: those before the point and p after *)
  let wanted = exp + 1 + p in
  let digits, exp = if wanted < 0 then ("0", 0) else if wanted = 0 then (if digits.[0] >= '5' then ("1", exp + 1) else ("0", 0)) else round (digits, exp) wanted in
  let digits = if digits = "0" then "0" else digits in
  let whole, frac =
    if digits = "0" then ("0", String.make p '0')
    else if exp >= 0 then begin
      let all = digits ^ String.make (max 0 (exp + 1 + p - String.length digits)) '0' in
      (String.sub all 0 (exp + 1), String.sub all (exp + 1) p)
    end else begin
      let all = String.make (-exp - 1) '0' ^ digits in
      ("0", String.sub (all ^ String.make p '0') 0 p)
    end in
  point whole (if zeros then frac else strip frac)

(* %g: p digits in all, as %e if the exponent is less than -4 or not
 * less than p, without the zeros at the end *)
let general a p upper sharp =
  let p = max p 1 in
  let _, exp = round (decimal a) p in
  if exp < -4 || exp >= p then exponential a (p - 1) upper sharp else fixed a (p - 1 - exp) sharp

let float (s : spec) v =
  if v <> v then pad { s with zero = false } "" "nan"
  else if v = infinity || v = neg_infinity then pad { s with zero = false } (sign s (v < 0.)) "inf"
  else begin
    let p = match s.precision with Some p -> p | None -> 6 in
    let a = abs_float v in
    let body = match s.verb with
      | 'e' -> exponential a p false true
      | 'E' -> exponential a p true true
      | 'f' -> fixed a p true
      | 'G' -> general a p true s.sharp
      | _ -> general a p false s.sharp in
    (* (-0 has no sign, unlike C's) *)
    pad s (sign s (v < 0.)) body
  end

(* a double to a long of 32 bits, as the machine does it: the nearest
 * one when it does not fit *)
let to_int32 v =
  if v <> v then 0l
  else if v >= 2147483647. then Int32.max_int
  else if v <= -2147483648. then Int32.min_int
  else Int32.of_float v

let int (s : spec) v =
  let n = to_int32 v in
  let unsigned = Int64.logand (Int64.of_int32 n) 0xFFFFFFFFL in
  let negative, digits = match s.verb with
    | 'o' -> (false, Printf.sprintf "%Lo" unsigned)
    | 'x' -> (false, Printf.sprintf "%Lx" unsigned)
    | 'X' -> (false, Printf.sprintf "%LX" unsigned)
    | 'u' -> (false, Printf.sprintf "%Ld" unsigned)
    | _ -> (n < 0l, Printf.sprintf "%Ld" (Int64.abs (Int64.of_int32 n))) in
  let digits = match s.precision with
    | Some p when String.length digits < p -> String.make (p - String.length digits) '0' ^ digits
    | _ -> digits in
  let prefix = if not s.sharp then "" else match s.verb with 'x' -> "0x" | 'X' -> "0X" | 'o' -> "0" | _ -> "" in
  pad s (sign s negative ^ prefix) digits

let string (s : spec) text =
  (* (the precision is bytes, of whole characters; the width is characters) *)
  let text = match s.precision with
    | Some p when String.length text > p ->
        let chars, _ = Utf8.chars text in
        let rec take acc used = function c :: rest when used + String.length c <= p -> take (acc ^ c) (used + String.length c) rest | _ -> acc in
        take "" 0 chars
    | _ -> text in
  pad { s with zero = false } "" text

let number fmt v =
  let n = String.length fmt in
  let b = Buffer.create 32 in
  (* what is around the directive is kept, a %% is a % *)
  let rec go k used =
    if k < n then
      if fmt.[k] <> '%' then (Buffer.add_char b fmt.[k]; go (k + 1) used)
      else if k + 1 < n && fmt.[k + 1] = '%' then (Buffer.add_char b '%'; go (k + 2) used)
      else begin
        let rec last j = if j < n - 1 && not ((fmt.[j] >= 'a' && fmt.[j] <= 'z' && fmt.[j] <> 'l' && fmt.[j] <> 'h') || (fmt.[j] >= 'A' && fmt.[j] <= 'Z' && fmt.[j] <> 'L')) then last (j + 1) else j in
        let stop = last (k + 1) in
        let spec = parse (String.sub fmt k (stop - k + 1)) in
        if not used then Buffer.add_string b (if String.contains "dioxXu" spec.verb then int spec v else float spec v);
        go (stop + 1) true
      end in
  go 0 false;
  Buffer.contents b
