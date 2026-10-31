(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Runtime.mli *)

(*****************************************************************************)
(* .NET's members *)
(*****************************************************************************)

external m_sqrt : float -> float = "dotnet:static System.Math::Sqrt"
external m_exp : float -> float = "dotnet:static System.Math::Exp"
external m_log : float -> float = "dotnet:static System.Math::Log"
external m_log10 : float -> float = "dotnet:static System.Math::Log10"
external m_sin : float -> float = "dotnet:static System.Math::Sin"
external m_cos : float -> float = "dotnet:static System.Math::Cos"
external m_tan : float -> float = "dotnet:static System.Math::Tan"
external m_asin : float -> float = "dotnet:static System.Math::Asin"
external m_acos : float -> float = "dotnet:static System.Math::Acos"
external m_atan : float -> float = "dotnet:static System.Math::Atan"
external m_atan2 : float -> float -> float = "dotnet:static System.Math::Atan2"
external m_sinh : float -> float = "dotnet:static System.Math::Sinh"
external m_cosh : float -> float = "dotnet:static System.Math::Cosh"
external m_tanh : float -> float = "dotnet:static System.Math::Tanh"
external m_floor : float -> float = "dotnet:static System.Math::Floor"
external m_ceiling : float -> float = "dotnet:static System.Math::Ceiling"
external m_truncate : float -> float = "dotnet:static System.Math::Truncate"
external m_pow : float -> float -> float = "dotnet:static System.Math::Pow"
external m_remainder : float -> float -> float
  = "dotnet:static System.Math::IEEERemainder"
external m_scaleb : float -> int -> float
  = "dotnet:static System.Math::ScaleB(float64,int32)"
external m_ilogb : float -> int = "dotnet:static System.Math::ILogB -> int32"
external parse : string -> float = "dotnet:static System.Double::Parse"
external to_string : float -> string -> string
  = "dotnet:instance System.Double::ToString(string)"
external sub : string -> int -> int -> string
  = "dotnet:instance System.String::Substring(int32,int32)"
external lower : string -> string = "dotnet:instance System.String::ToLower"
external code : char -> int = "%identity"

(*****************************************************************************)
(* Floats *)
(*****************************************************************************)

let power_float (x : float) (y : float) : float = m_pow x y
let exp_float (x : float) : float = m_exp x
let acos_float (x : float) : float = m_acos x
let asin_float (x : float) : float = m_asin x
let atan_float (x : float) : float = m_atan x
let atan2_float (y : float) (x : float) : float = m_atan2 y x
let cos_float (x : float) : float = m_cos x
let cosh_float (x : float) : float = m_cosh x
let log_float (x : float) : float = m_log x
let log10_float (x : float) : float = m_log10 x
let sin_float (x : float) : float = m_sin x
let sinh_float (x : float) : float = m_sinh x
let sqrt_float (x : float) : float = m_sqrt x
let tan_float (x : float) : float = m_tan x
let tanh_float (x : float) : float = m_tanh x
let ceil_float (x : float) : float = m_ceiling x
let floor_float (x : float) : float = m_floor x
(* C's fmod from IEEE's remainder (the quotient rounded to the nearest,
 * not truncated): |y| back where its sign is not x's; exact, as both *)
let fmod_float (x : float) (y : float) : float =
  let r = m_remainder x y in
  let a = if y < 0.0 then -. y else y in
  if x > 0.0 && r < 0.0 then r +. a else if x < 0.0 && r > 0.0 then r -. a else r

let finite (x : float) : bool = x = x && x <> infinity && x <> neg_infinity

(* (C's: 0, NaN and the infinities as they are, an exponent 0) *)
let frexp_float (x : float) : float * int =
  if x = 0.0 || not (finite x) then (x, 0)
  else
    let e = m_ilogb x + 1 in
    (m_scaleb x (- e), e)

(* (an exponent beyond any double's: ScaleB's int32 not wrapped) *)
let ldexp_float (x : float) (n : int) : float =
  m_scaleb x (if n > 100000 then 100000 else if n < -100000 then -100000 else n)

(* the fractional part, the integral part; their signs x's *)
let modf_float (x : float) : float * float =
  if x <> x then (x, x)
  else if not (finite x) then ((if x < 0.0 then (-. 0.0) else 0.0), x)
  else
    let i = m_truncate x in
    let f = x -. i in
    ((if f = 0.0 && x < 0.0 then (-. 0.0) else f), i)

(*****************************************************************************)
(* Numbers read *)
(*****************************************************************************)

(* -, then 0x 0o 0b or decimal, _ between digits; past 64 bits it
 * wraps, as the native runtime's *)
let int_of_string (s : string) : int =
  let n = String.length s in
  let i = ref 0 and neg = ref false and b = ref 10 and v = ref 0 in
  if !i < n && s.[!i] = '-' then begin neg := true; incr i end
  else if !i < n && s.[!i] = '+' then incr i;
  if !i + 1 < n && s.[!i] = '0' then begin
    let c = s.[!i + 1] in
    if c = 'x' || c = 'X' then begin b := 16; i := !i + 2 end
    else if c = 'o' || c = 'O' then begin b := 8; i := !i + 2 end
    else if c = 'b' || c = 'B' then begin b := 2; i := !i + 2 end
  end;
  if !i = n then failwith "int_of_string";
  while !i < n do
    let c = s.[!i] in
    if c <> '_' then begin
      let d =
        if c >= '0' && c <= '9' then code c - 48
        else if c >= 'a' && c <= 'f' then code c - 87
        else if c >= 'A' && c <= 'F' then code c - 55
        else 99 in
      if d >= !b then failwith "int_of_string";
      v := !v * !b + d
    end;
    incr i
  done;
  if !neg then - !v else !v

let is_digit (c : char) : bool = c >= '0' && c <= '9'

let is_hex (c : char) : bool =
  is_digit c || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')

let hex_value (c : char) : int =
  if is_digit c then code c - 48 else if c >= 'a' && c <= 'f' then code c - 87 else code c - 55

(* the digits from i that pass ok: where they stop *)
let rec skip (s : string) (i : int) (ok : char -> bool) : int =
  if i < String.length s && ok s.[i] then skip s (i + 1) ok else i

(* strtod's, as the native runtime's: blanks first, then a sign, then
 * digits with a point and an exponent, 0x's digits and a p exponent,
 * inf, infinity or nan; the underscores dropped; nothing after *)
let float_of_string (s : string) : float =
  let t = ref "" in
  for i = 0 to String.length s - 1 do
    if s.[i] <> '_' then t := !t ^ sub s i 1
  done;
  let s = !t in
  let n = String.length s in
  let i = skip s 0 (fun (c : char) -> c = ' ' || c = '\t' || c = '\n' || c = '\r') in
  let neg = i < n && s.[i] = '-' in
  let j = if i < n && (s.[i] = '-' || s.[i] = '+') then i + 1 else i in
  let rest = lower (sub s j (n - j)) in
  let sign (x : float) : float = if neg then -. x else x in
  if rest = "inf" || rest = "infinity" then sign infinity
  else if rest = "nan" then nan
  else if n - j > 2 && s.[j] = '0' && (s.[j + 1] = 'x' || s.[j + 1] = 'X') then begin
    (* (the digits a float, exact to 53 bits, scaled by 2's exponent) *)
    let m = ref 0.0 and k = ref (j + 2) and e = ref 0 and digits = ref 0 in
    while !k < n && is_hex s.[!k] do m := !m *. 16.0 +. float (hex_value s.[!k]); incr k; incr digits done;
    if !k < n && s.[!k] = '.' then begin
      incr k;
      while !k < n && is_hex s.[!k] do
        m := !m *. 16.0 +. float (hex_value s.[!k]); e := !e - 4; incr k; incr digits
      done
    end;
    if !digits = 0 then failwith "float_of_string";
    if !k < n && (s.[!k] = 'p' || s.[!k] = 'P') then begin
      let start = !k + 1 in
      let d = if start < n && (s.[start] = '-' || s.[start] = '+') then start + 1 else start in
      let stop = skip s d is_digit in
      if stop = d || stop <> n then failwith "float_of_string";
      e := !e + int_of_string (sub s start (stop - start));
      k := stop
    end;
    if !k <> n then failwith "float_of_string";
    sign (ldexp_float !m !e)
  end
  else begin
    let a = skip s j is_digit in
    let b = if a < n && s.[a] = '.' then skip s (a + 1) is_digit else a in
    if b - j - (if b > a then 1 else 0) = 0 then failwith "float_of_string";
    let c =
      if b < n && (s.[b] = 'e' || s.[b] = 'E') then begin
        let d = if b + 1 < n && (s.[b + 1] = '-' || s.[b + 1] = '+') then b + 2 else b + 1 in
        let stop = skip s d is_digit in
        if stop = d then failwith "float_of_string";
        stop
      end
      else b in
    if c <> n then failwith "float_of_string";
    (* (.NET's reading of the number C's syntax checked: correctly
     * rounded, which digits by hand would not be) *)
    parse (sub s i (n - i))
  end

(*****************************************************************************)
(* Numbers written *)
(*****************************************************************************)

(* a format's %[-0+ #]width[.precision]: its flags, width, precision
 * (-1 none), and where its conversion is *)
type spec = {
  left : bool; zero : bool; plus : bool; space : bool; alt : bool;
  width : int; precision : int; conv : char;
}

let spec (f : string) : spec =
  let n = String.length f in
  let left = ref false and zero = ref false and plus = ref false
  and space = ref false and alt = ref false in
  let i = ref 1 in
  while !i < n && (f.[!i] = '-' || f.[!i] = '0' || f.[!i] = '+' || f.[!i] = ' ' || f.[!i] = '#') do
    let c = f.[!i] in
    if c = '-' then left := true
    else if c = '0' then zero := true
    else if c = '+' then plus := true
    else if c = ' ' then space := true
    else alt := true;
    incr i
  done;
  let width = ref 0 in
  while !i < n && is_digit f.[!i] do width := !width * 10 + code f.[!i] - 48; incr i done;
  let precision = ref (-1) in
  if !i < n && f.[!i] = '.' then begin
    incr i;
    precision := 0;
    while !i < n && is_digit f.[!i] do precision := !precision * 10 + code f.[!i] - 48; incr i done
  end;
  while !i < n && (f.[!i] = 'l' || f.[!i] = 'n' || f.[!i] = 'L') do incr i done;
  { left = !left; zero = !zero; plus = !plus; space = !space; alt = !alt;
    width = !width; precision = !precision; conv = (if !i < n then f.[!i] else 'd') }

let rec spaces (n : int) (c : string) : string = if n <= 0 then "" else c ^ spaces (n - 1) c

(* the sign and the digits padded to the width: spaces before, zeros
 * between (when the digits are a number's), or spaces after *)
let pad (sp : spec) (sign : string) (digits : string) (numeric : bool) : string =
  let len = String.length sign + String.length digits in
  let k = sp.width - len in
  if k <= 0 then sign ^ digits
  else if sp.left then sign ^ digits ^ spaces k " "
  else if sp.zero && numeric then sign ^ spaces k "0" ^ digits
  else spaces k " " ^ sign ^ digits

let sign_of (sp : spec) (neg : bool) : string =
  if neg then "-" else if sp.plus then "+" else if sp.space then " " else ""

let digit_chars = "0123456789abcdef0123456789ABCDEF"

(* n's digits in base b, n unsigned: 64 bits (an int is an int64 on
 * .NET, where the native runtime's is 63) *)
let unsigned_digits (n : int) (b : int) (upper : bool) : string =
  let off = if upper then 16 else 0 in
  let digit (d : int) : string = sub digit_chars (off + d) 1 in
  (* (the first step unsigned: n's halves by lsr, then signed) *)
  let first, last =
    if n >= 0 then (n / b, n mod b)
    else
      let q = (n lsr 1) / b * 2 in
      let r = n - q * b in
      if r >= b then (q + 1, r - b) else (q, r) in
  let s = ref (digit last) and m = ref first in
  while !m <> 0 do s := digit (!m mod b) ^ !s; m := !m / b done;
  !s

let format_int (f : string) (n : int) : string =
  let sp = spec f in
  match sp.conv with
  | 'd' | 'i' ->
      let neg = n < 0 in
      (* (min_int's digits as unsigned's: its negation is itself) *)
      let digits = if neg then unsigned_digits (- n) 10 false else unsigned_digits n 10 false in
      pad sp (sign_of sp neg) digits true
  | 'u' -> pad sp "" (unsigned_digits n 10 false) true
  | 'x' -> pad sp (if sp.alt && n <> 0 then "0x" else "") (unsigned_digits n 16 false) true
  | 'X' -> pad sp (if sp.alt && n <> 0 then "0X" else "") (unsigned_digits n 16 true) true
  | 'o' -> pad sp (if sp.alt && n <> 0 then "0" else "") (unsigned_digits n 8 false) true
  | _ -> failwith "format_int: bad format"

(* .NET's E format, 1.500000E+003, as C's %e: 1.500000e+03 *)
let exponent (x : float) (p : int) (upper : bool) : string =
  let s = to_string x ("E" ^ format_int "%d" p) in
  let n = String.length s in
  let e = ref 0 in
  for i = 0 to n - 1 do if s.[i] = 'E' then e := i done;
  let mant = sub s 0 !e in
  let x = int_of_string (sub s (!e + 2) (n - !e - 2)) in
  let x = if s.[!e + 1] = '-' then - x else x in
  mant ^ (if upper then "E" else "e") ^ (if x < 0 then "-" else "+") ^ format_int "%02d" (if x < 0 then - x else x)

let fixed (x : float) (p : int) : string = to_string x ("F" ^ format_int "%d" p)

(* %g's trailing zeros dropped, and its point if none is left *)
let trim (s : string) : string =
  let has_point = ref false in
  for i = 0 to String.length s - 1 do if s.[i] = '.' then has_point := true done;
  if not !has_point then s
  else begin
    let e = ref (String.length s) in
    for i = String.length s - 1 downto 0 do if s.[i] = 'e' || s.[i] = 'E' then e := i done;
    let k = ref (!e - 1) in
    while s.[!k] = '0' do decr k done;
    if s.[!k] = '.' then decr k;
    sub s 0 (!k + 1) ^ sub s !e (String.length s - !e)
  end

(* C's %e %f %g (and E F G) of a precision, 6 when it has none; inf
 * and nan as OCaml prints them *)
let format_float (f : string) (x : float) : string =
  let sp = spec f in
  let p = if sp.precision < 0 then 6 else sp.precision in
  let upper = sp.conv = 'E' || sp.conv = 'G' || sp.conv = 'F' in
  let neg = x < 0.0 || (x = 0.0 && 1.0 /. x < 0.0) in
  let a = if neg then -. x else x in
  if x <> x then pad sp "" (if upper then "NAN" else "nan") false
  else if a = infinity then pad sp (sign_of sp neg) (if upper then "INF" else "inf") false
  else
    let digits =
      match sp.conv with
      | 'e' | 'E' -> exponent a p upper
      | 'f' | 'F' -> fixed a p
      | 'g' | 'G' ->
          let p = if p = 0 then 1 else p in
          (* (the exponent the number has once rounded to p digits) *)
          let e = exponent a (p - 1) upper in
          let k = ref 0 in
          for i = 0 to String.length e - 1 do if e.[i] = 'e' || e.[i] = 'E' then k := i done;
          let x = int_of_string (sub e (!k + 1) (String.length e - !k - 1)) in
          let s = if x < p && x >= -4 then fixed a (p - 1 - x) else e in
          if sp.alt then s else trim s
      | _ -> failwith "format_float: bad format" in
    pad sp (sign_of sp neg) digits true
