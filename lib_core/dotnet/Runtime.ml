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

(* a string, a char, a boolean in a width (%-10s, %5c, %b): Printf's,
 * as the compiler makes its calls *)
let format_string (f : string) (x : string) : string =
  let sp = spec f in
  let x = if sp.precision >= 0 && sp.precision < String.length x then sub x 0 sp.precision else x in
  pad sp "" x false

external char_string : char -> string = "dotnet:static System.Char::ToString(char) -> string"

(* a char as OCaml's String.escaped writes it (String is a unit after
 * this one): a backslash before a quote and a backslash, newline, tab,
 * return and backspace by their letters, the printable as they are,
 * the others by three digits *)
let escaped_char (c : char) : string =
  match c with
  | '"' -> "\\\"" | '\\' -> "\\\\" | '\n' -> "\\n" | '\t' -> "\\t" | '\r' -> "\\r" | '\b' -> "\\b"
  | c when c >= ' ' && c < '\127' -> char_string c
  | c -> let n = code c in "\\" ^ format_int "%03d" n

let escaped (s : string) : string =
  let r = ref "" in
  for i = 0 to String.length s - 1 do r := !r ^ escaped_char s.[i] done;
  !r

(* %S and %C: OCaml's quoted, escaped *)
let format_quoted (f : string) (x : string) : string = format_string f ("\"" ^ escaped x ^ "\"")
let format_quoted_char (f : string) (c : char) : string =
  format_string f ("'" ^ (if c = '\'' then "\\'" else if c = '"' then "\"" else escaped_char c) ^ "'")

let format_char (f : string) (c : char) : string = pad (spec f) "" (char_string c) false
let format_bool (f : string) (b : bool) : string = pad (spec f) "" (if b then "true" else "false") false

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

(* OCaml's %h: 0x1.8p+1, the mantissa's hexadecimal digits, its
 * trailing zeros dropped; 0x0p+0; infinity, nan *)
let hex_float (x : float) : string =
  if x = 0.0 then "0x0p+0"
  else begin
    let m, e = frexp_float x in
    (* (1.xxx: twice the mantissa, the exponent one less) *)
    let bits = truncate ((m *. 2.0 -. 1.0) *. 4503599627370496.0) in
    let s = ref "" and b = ref bits in
    for _i = 1 to 13 do s := sub digit_chars (!b land 15) 1 ^ !s; b := !b lsr 4 done;
    let n = ref 13 in
    while !n > 0 && (!s).[!n - 1] = '0' do decr n done;
    let e = e - 1 in
    "0x1" ^ (if !n > 0 then "." ^ sub !s 0 !n else "") ^ "p" ^ (if e < 0 then "-" else "+") ^ format_int "%d" (if e < 0 then - e else e)
  end

(* C's %e %f %g (and E F G) of a precision, 6 when it has none; inf
 * and nan as OCaml prints them; OCaml's %h *)
let format_float (f : string) (x : float) : string =
  let sp = spec f in
  let p = if sp.precision < 0 then 6 else sp.precision in
  let upper = sp.conv = 'E' || sp.conv = 'G' || sp.conv = 'F' in
  let neg = x < 0.0 || (x = 0.0 && 1.0 /. x < 0.0) in
  let a = if neg then -. x else x in
  if sp.conv = 'h' || sp.conv = 'H' then
    pad sp (sign_of sp neg) (if x <> x then "nan" else if a = infinity then "infinity" else hex_float a) false
  else if x <> x then pad sp "" (if upper then "NAN" else "nan") false
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

(*****************************************************************************)
(* Bytes *)
(*****************************************************************************)

(* bytes are .NET's byte[], a string a System.String of a byte a char:
 * between them by Latin-1, a copy each way *)
type encoding

external alloc : int -> bytes = "%bytes_create"
external bget : bytes -> int -> char = "%string_unsafe_get"
external bset : bytes -> int -> char -> unit = "%string_unsafe_set"
external blength : bytes -> int = "%string_length"
external latin1 : unit -> encoding
  = "dotnet:static System.Text.Encoding::get_Latin1() -> System.Text.Encoding"
external get_string : encoding -> bytes -> string
  = "dotnet:instance System.Text.Encoding::GetString(uint8[])"
external get_bytes : encoding -> string -> bytes
  = "dotnet:instance System.Text.Encoding::GetBytes(string)"

let create_string (n : int) : bytes =
  if n < 0 then invalid_arg "Bytes.create" else alloc n

external get_bytes_into : encoding -> string -> int -> int -> bytes -> int -> int
  = "dotnet:instance System.Text.Encoding::GetBytes(string,int32,int32,uint8[],int32) -> int32"

(* (one call of .NET's, not a loop: mini-dotnet's interpreter spent a
 * fifth of the reading of a Datalog file in the loop)
 * old: for i = 0 to n - 1 do bset b (o2 + i) s.[o1 + i] done *)
let blit_string (s : string) (o1 : int) (b : bytes) (o2 : int) (n : int) : unit =
  if n > 0 then ignore (get_bytes_into (latin1 ()) s o1 n b o2)

let fill_string (b : bytes) (o : int) (n : int) (c : char) : unit =
  for i = o to o + n - 1 do bset b i c done

(* (C's isprint of ASCII, as the native's: Latin-1's upper half not) *)
let is_printable (c : char) : bool = c >= ' ' && c < '\127'

(* an array of n x: .NET's T[] (newarr), generic in its element *)
external alloc_array : int -> 'a array = "%array_create"

(* Float.Array.create's: a float64[] of zeros *)
external alloc_floats : int -> Float.Array.t = "%array_create"
let caml_floatarray_create (n : int) : Float.Array.t =
  if n < 0 then invalid_arg "Float.Array.create" else alloc_floats n

let make_vect (n : int) (x : 'a) : 'a array =
  if n < 0 then invalid_arg "Array.make";
  let a = alloc_array n in
  for i = 0 to n - 1 do a.(i) <- x done;
  a

let string_of_bytes (b : bytes) : string = get_string (latin1 ()) b
let bytes_of_string (s : string) : bytes = get_bytes (latin1 ()) s

(*****************************************************************************)
(* Channels *)
(*****************************************************************************)

(* the native runtime's (languages/ml/runtime/io.c): a buffer of 4096
 * bytes over a file's, here a .NET Stream (the console's: its bytes as
 * they are, whatever its encoding). A descriptor a number in a table
 * of the streams: 0, 1 and 2 the console's, then the files opened *)
type stream

external stdin_stream : unit -> stream
  = "dotnet:static System.Console::OpenStandardInput() -> System.IO.Stream"
external stdout_stream : unit -> stream
  = "dotnet:static System.Console::OpenStandardOutput() -> System.IO.Stream"
external stderr_stream : unit -> stream
  = "dotnet:static System.Console::OpenStandardError() -> System.IO.Stream"
external s_read : stream -> bytes -> int -> int -> int
  = "dotnet:instance System.IO.Stream::Read(uint8[],int32,int32) -> int32"
external s_write : stream -> bytes -> int -> int -> unit
  = "dotnet:instance System.IO.Stream::Write(uint8[],int32,int32)"
external s_flush : stream -> unit = "dotnet:instance System.IO.Stream::Flush"
external s_dispose : stream -> unit = "dotnet:instance System.IO.Stream::Dispose"
external s_length : stream -> int = "dotnet:instance System.IO.Stream::get_Length"
external s_seek : stream -> int -> unit = "dotnet:instance System.IO.Stream::set_Position"
external open_read : string -> stream
  = "dotnet:static System.IO.File::OpenRead -> System.IO.FileStream"
external open_write : string -> stream
  = "dotnet:static System.IO.File::OpenWrite -> System.IO.FileStream"
external create : string -> stream
  = "dotnet:static System.IO.File::Create -> System.IO.FileStream"
external exists : string -> bool = "dotnet:static System.IO.File::Exists"

type channel = {
  stream : stream;
  buf : bytes;
  mutable len : int;            (* output: the bytes buffered; input: those left, *)
  mutable pos : int;            (* from pos *)
  mutable offset : int;         (* the stream's position *)
  mutable written : bool;       (* an output channel's (flush writes) *)
}

(* (Pervasives' in_channel and out_channel are abstract: objects, each
 * a channel; out_channel says both here) *)
external chan : out_channel -> channel = "%identity"
external of_chan : channel -> out_channel = "%identity"
external chr : int -> char = "%identity"

let streams : (int * stream) list ref = ref []
let next_fd = ref 3

let stream_of (fd : int) : stream =
  let rec find (l : (int * stream) list) : stream option =
    match l with [] -> None | (n, s) :: r -> if n = fd then Some s else find r in
  match find !streams with
  | Some s -> s
  | None ->
      let s =
        if fd = 0 then stdin_stream () else if fd = 1 then stdout_stream ()
        else if fd = 2 then stderr_stream () else raise (Sys_error "bad file descriptor") in
      streams := (fd, s) :: !streams;
      s

let caml_open_descriptor (fd : int) : out_channel =
  of_chan { stream = stream_of fd; buf = create_string 4096; len = 0; pos = 0; offset = 0; written = false }

(* (an input channel's len is what is left to read: not written, the
 * native's write of it fails on a file opened to read, .NET's throws) *)
let flush_chan (c : channel) : unit =
  if c.written then begin
    if c.len > 0 then s_write c.stream c.buf 0 c.len;
    s_flush c.stream;
    c.offset <- c.offset + c.len;
    c.len <- 0
  end

let caml_flush (ch : out_channel) : unit = flush_chan (chan ch)

let putc (c : channel) (b : char) : unit =
  c.written <- true;
  if c.len = 4096 then flush_chan c;
  bset c.buf c.len b;
  c.len <- c.len + 1

let caml_output_char (ch : out_channel) (b : char) : unit = putc (chan ch) b

let caml_output (ch : out_channel) (s : string) (ofs : int) (len : int) : unit =
  let c = chan ch in
  for i = 0 to len - 1 do putc c s.[ofs + i] done

let caml_output_int (ch : out_channel) (n : int) : unit =
  let c = chan ch in
  putc c (chr ((n asr 24) land 255));
  putc c (chr ((n asr 16) land 255));
  putc c (chr ((n asr 8) land 255));
  putc c (chr (n land 255))

let fill (c : channel) : int =
  let n = s_read c.stream c.buf 0 4096 in
  if n > 0 then begin
    c.offset <- c.offset + n;
    c.len <- n;
    c.pos <- 0
  end;
  n

(* the next byte, or -1 at the end (no signals here: -2 never) *)
let ml_input_char (ch : out_channel) : int =
  let c = chan ch in
  if c.len = 0 && fill c <= 0 then -1
  else begin
    c.len <- c.len - 1;
    c.pos <- c.pos + 1;
    code (bget c.buf (c.pos - 1))
  end

(* what the buffer has, at once (filled first when it is empty) *)
let caml_input (ch : out_channel) (s : bytes) (ofs : int) (len : int) : int =
  let c = chan ch in
  if c.len = 0 && len > 0 then ignore (fill c);
  let n = if len < c.len then len else c.len in
  let n = if n < 0 then 0 else n in
  for i = 0 to n - 1 do bset s (ofs + i) (bget c.buf (c.pos + i)) done;
  c.pos <- c.pos + n;
  c.len <- c.len - n;
  n

(* how far to the next newline (included), negated if the buffer ends
 * first, 0 at the end: input_line loops on it *)
let caml_input_scan_line (ch : out_channel) : int =
  let c = chan ch in
  if c.len = 0 && fill c <= 0 then 0
  else begin
    let i = ref 0 and found = ref (-1) in
    while !found < 0 && !i < c.len do
      if bget c.buf (c.pos + !i) = '\n' then found := !i + 1;
      incr i
    done;
    if !found > 0 then !found else - c.len
  end

let caml_close_channel (ch : out_channel) : unit =
  let c = chan ch in
  flush_chan c;
  s_dispose c.stream

let caml_pos_out (ch : out_channel) : int = (chan ch).offset + (chan ch).len
let caml_pos_in (ch : out_channel) : int = (chan ch).offset - (chan ch).len
let caml_channel_size (ch : out_channel) : int = s_length (chan ch).stream

let caml_seek_in (ch : out_channel) (n : int) : unit =
  let c = chan ch in
  s_seek c.stream n;
  c.offset <- n;
  c.len <- 0;
  c.pos <- 0

let caml_seek_out (ch : out_channel) (n : int) : unit =
  let c = chan ch in
  flush_chan c;
  s_seek c.stream n;
  c.offset <- n

(* output_binary_int's 4 bytes, the high one first, with its sign *)
let caml_input_int (ch : out_channel) : int =
  let n = ref 0 in
  for _i = 1 to 4 do
    let b = ml_input_char ch in
    if b < 0 then raise End_of_file;
    n := (!n lsl 8) lor b
  done;
  if !n land 0x80000000 <> 0 then !n - 0x100000000 else !n

let ml_signal_pending () : int = 0

(*****************************************************************************)
(* The system *)
(*****************************************************************************)

let rec has (f : open_flag) (l : open_flag list) : bool =
  match l with [] -> false | x :: r -> x = f || has f r

(* the native's open: written with Open_wronly or Open_append; made with
 * Open_creat when it is not there (or only made, Open_excl); emptied
 * with Open_trunc; at its end with Open_append. A name that cannot be:
 * Sys_error, the name its message, as the native's *)
let sys_open (name : string) (flags : open_flag list) (_perm : int) : int =
  let write = has Open_wronly flags || has Open_append flags in
  let there = exists name in
  if (not there && not (has Open_creat flags)) || (there && has Open_creat flags && has Open_excl flags) then
    raise (Sys_error name);
  let s =
    if not there || has Open_trunc flags then create name
    else if write then open_write name
    else open_read name in
  if has Open_append flags then s_seek s (s_length s);
  let fd = !next_fd in
  incr next_fd;
  streams := (fd, s) :: !streams;
  fd

external bits_to_double : int64 -> float
  = "dotnet:static System.BitConverter::Int64BitsToDouble"
external double_to_bits : float -> int64
  = "dotnet:static System.BitConverter::DoubleToInt64Bits"

let int64_float_of_bits (b : int64) : float = bits_to_double b
let int64_bits_of_float (x : float) : int64 = double_to_bits x

(*****************************************************************************)
(* Int32, Int64 *)
(*****************************************************************************)

(* an int64 is .NET's int64, an int; an int32 its int32, which a call
 * of these converts to an int and back (conv.i4: the 32 bits kept, as
 * the int32's own arithmetic would) *)
let int64_neg (a : int) : int = - a
let int64_add (a : int) (b : int) : int = a + b
let int64_sub (a : int) (b : int) : int = a - b
let int64_mul (a : int) (b : int) : int = a * b
let int64_div (a : int) (b : int) : int = a / b
let int64_mod (a : int) (b : int) : int = a mod b
let int64_and (a : int) (b : int) : int = a land b
let int64_or (a : int) (b : int) : int = a lor b
let int64_xor (a : int) (b : int) : int = a lxor b
let int64_shift_left (a : int) (n : int) : int = a lsl n
let int64_shift_right (a : int) (n : int) : int = a asr n
let int64_shift_right_unsigned (a : int) (n : int) : int = a lsr n
let int64_of_int (a : int) : int = a
let int64_to_int (a : int) : int = a
let int64_of_int32 (a : int) : int = a
let int64_to_int32 (a : int) : int = a
let int64_format (f : string) (a : int) : string = format_int f a
let int64_of_string (s : string) : int = int_of_string s
let int64_of_float (x : float) : int = truncate x
let int64_to_float (a : int) : float = float a

let int32_neg (a : int) : int = - a
let int32_add (a : int) (b : int) : int = a + b
let int32_sub (a : int) (b : int) : int = a - b
let int32_mul (a : int) (b : int) : int = a * b
let int32_div (a : int) (b : int) : int = a / b
let int32_mod (a : int) (b : int) : int = a mod b
let int32_and (a : int) (b : int) : int = a land b
let int32_or (a : int) (b : int) : int = a lor b
let int32_xor (a : int) (b : int) : int = a lxor b
let int32_shift_left (a : int) (n : int) : int = a lsl n
let int32_shift_right (a : int) (n : int) : int = a asr n
let int32_shift_right_unsigned (a : int) (n : int) : int = (a land 0xFFFFFFFF) lsr n
let int32_of_int (a : int) : int = a
let int32_to_int (a : int) : int = a
(* (%x, %o, %u of a negative one: its 32 bits) *)
let int32_format (f : string) (a : int) : string =
  let c = f.[String.length f - 1] in
  format_int f (if a < 0 && (c = 'x' || c = 'X' || c = 'o' || c = 'u') then a land 0xFFFFFFFF else a)
let int32_of_string (s : string) : int =
  let n = int_of_string s in
  if n < -0x80000000 || n > 0xFFFFFFFF then failwith "Int32.of_string" else n
let int32_of_float (x : float) : int = truncate x
let int32_to_float (a : int) : float = float a

external single_bits : float -> int
  = "dotnet:static System.BitConverter::SingleToInt32Bits(float32) -> int32"
external bits_single : int -> float
  = "dotnet:static System.BitConverter::Int32BitsToSingle(int32) -> float32"

let int32_bits_of_float (x : float) : int = single_bits x
let int32_float_of_bits (b : int) : float = bits_single b

(*****************************************************************************)
(* Hashtbl *)
(*****************************************************************************)

(* Hashtbl.hash: the compiler's Ml::hash, the same on both runtimes
 * (not OCaml's numbers: a table's order is not its); positive *)
external ml_hash : 'a -> int = "%hash"

let hash_univ_param (_count : int) (_limit : int) (x : 'a) : int = ml_hash x land 0x3FFFFFFF

(*****************************************************************************)
(* Sys *)
(*****************************************************************************)

type directory_info

external command_line : unit -> string array
  = "dotnet:static System.Environment::GetCommandLineArgs() -> string[]"
external get_variable : string -> string
  = "dotnet:static System.Environment::GetEnvironmentVariable"
external null_or_empty : string -> bool = "dotnet:static System.String::IsNullOrEmpty"
external tick_count : unit -> int = "dotnet:static System.Environment::get_TickCount64"
external dir_exists : string -> bool = "dotnet:static System.IO.Directory::Exists"
external create_directory : string -> directory_info
  = "dotnet:static System.IO.Directory::CreateDirectory -> System.IO.DirectoryInfo"
external current_directory : unit -> string
  = "dotnet:static System.IO.Directory::GetCurrentDirectory"
external set_current_directory : string -> unit
  = "dotnet:static System.IO.Directory::SetCurrentDirectory"
external entries : string -> string array
  = "dotnet:static System.IO.Directory::GetFileSystemEntries"
external file_delete : string -> unit = "dotnet:static System.IO.File::Delete"
external file_move : string -> string -> bool -> unit = "dotnet:static System.IO.File::Move"

(* (the assembly's path first: the program's name, as argv.(0)) *)
let sys_get_argv () : string array = command_line ()

(* (an int of 64 bits: .NET's) *)
let sys_get_config () : string * int = ("Unix", 64)

(* (a variable set to "": not set, as .NET says null and "" alike here) *)
let sys_getenv (v : string) : string =
  let s = get_variable v in
  if null_or_empty s then raise Not_found else s

let sys_file_exists (f : string) : bool = exists f || dir_exists f

let no_such (f : string) : 'a = raise (Sys_error (f ^ ": No such file or directory"))

let sys_is_directory (f : string) : bool =
  if dir_exists f then true else if exists f then false else no_such f

let sys_remove (f : string) : unit = if exists f then file_delete f else no_such f

let sys_rename (a : string) (b : string) : unit =
  if exists a then file_move a b true else no_such a

let sys_mkdir (f : string) (_perm : int) : unit =
  if sys_file_exists f then raise (Sys_error (f ^ ": File exists")) else ignore (create_directory f)

(* the names of a directory's entries (.NET's are paths) *)
let sys_read_directory (d : string) : string array =
  if not (dir_exists d) then no_such d;
  let a = entries d in
  for i = 0 to Array.length a - 1 do
    let p = a.(i) in
    let j = ref (String.length p - 1) in
    while !j >= 0 && p.[!j] <> '/' do decr j done;
    a.(i) <- sub p (!j + 1) (String.length p - !j - 1)
  done;
  a

let sys_getcwd () : string = current_directory ()
let sys_chdir (d : string) : unit = if dir_exists d then set_current_directory d else no_such d

(* (the time since the program started, by the clock: not the
 * processor's, which .NET gives only through a Process) *)
let start_ticks = tick_count ()
let sys_time () : float = float (tick_count () - start_ticks) /. 1000.0

let sys_system_command (_ : string) : int = raise (Sys_error "Sys.command: no process here (.NET)")

(* (no signals: a handler installed is never run) *)
let ml_signal (_ : int) (_ : int) : unit = ()

let sys_close (fd : int) : unit =
  let rec remove (l : (int * stream) list) : (int * stream) list =
    match l with
    | [] -> []
    | (n, s) :: r -> if n = fd then (s_dispose s; r) else (n, s) :: remove r in
  streams := remove !streams

(*****************************************************************************)
(* Callback, Gc, Digest *)
(*****************************************************************************)

(* (a value named for the C runtime's own calls: none here) *)
let register_named_value (_ : string) (_ : Obj.t) : unit = ()

(* (.NET's collector: no counters of OCaml's heap, nothing to ask) *)
let gc_counters () : int * int * int * int = (0, 0, 0, 0)
let gc_minor () : unit = ()
let gc_major () : unit = ()
let gc_full_major () : unit = ()
let gc_compaction () : unit = ()

external md5 : bytes -> bytes
  = "dotnet:static System.Security.Cryptography.MD5::HashData(uint8[]) -> uint8[]"

let md5_string (s : string) (ofs : int) (len : int) : string =
  string_of_bytes (md5 (bytes_of_string (sub s ofs len)))

(* a channel's len bytes, or all that is left (len < 0) *)
let md5_chan (ch : out_channel) (len : int) : string =
  let b = create_string 4096 and acc = ref "" and left = ref len and over = ref false in
  while not !over do
    let want = if !left < 0 || !left > 4096 then 4096 else !left in
    let n = if want = 0 then 0 else caml_input ch b 0 want in
    if n = 0 then over := true
    else begin
      acc := !acc ^ sub (string_of_bytes b) 0 n;
      if !left > 0 then left := !left - n
    end
  done;
  if !left > 0 then raise End_of_file;
  md5_string !acc 0 (String.length !acc)

(*****************************************************************************)
(* Printexc *)
(*****************************************************************************)

type dotnet_type

external get_type : exn -> dotnet_type = "dotnet:instance System.Object::GetType() -> System.Type"
external type_name : dotnet_type -> string = "dotnet:instance System.Type::get_Name"

(* an exception as OCaml prints it: the predefined ones with their
 * arguments (Failure("..."), Sys_error, Invalid_argument); another,
 * Pervasives' too (Exit, Assert_failure: a unit after this one), its
 * class's name, its arguments not (no reflection of them here) *)
let ml_exn_string (e : exn) : string =
  (* (not escaped: String's escaped is a unit after this one) *)
  let quoted (s : string) = "(\"" ^ s ^ "\")" in
  match e with
  | Failure s -> "Failure" ^ quoted s
  | Invalid_argument s -> "Invalid_argument" ^ quoted s
  | Sys_error s -> "Sys_error" ^ quoted s
  | Not_found -> "Not_found"
  | End_of_file -> "End_of_file"
  | Division_by_zero -> "Division_by_zero"
  | e -> type_name (get_type e)

(* (no backtrace kept: none, at Printexc's types, which come after) *)
let ml_raise_trace () : string = ""
let caml_get_exception_backtrace () : 'a option = None
let caml_get_exception_raw_backtrace () : string = ""

external environment_exit : int -> unit = "dotnet:static System.Environment::Exit(int32)"

(* (the external's 'a: a call of it gets a value of its type, which
 * Exit never lets it use) *)
let sys_exit (n : int) : unit = environment_exit n
