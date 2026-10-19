(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's mini-chrome's languages/javascript/values/Js_string.ml (its 8af888e) (docs/plans/plan_browser.md) *)

(* See Js_string.mli *)

(*****************************************************************************)
(* A character's bytes *)
(*****************************************************************************)

(* the character at byte [i]: how many bytes, and its code point. A
 * byte that starts none is one of its own *)
let decode (s : string) (i : int) : int * int =
  let n = String.length s and b = Char.code (String.unsafe_get s i) in
  let cont k = i + k < n && Char.code (String.unsafe_get s (i + k)) land 0xC0 = 0x80 in
  let bits k = Char.code (String.unsafe_get s (i + k)) land 0x3F in
  if b < 0x80 then (1, b)
  else if b >= 0xC2 && b <= 0xDF && cont 1 then (2, ((b land 0x1F) lsl 6) lor bits 1)
  else if b >= 0xE0 && b <= 0xEF && cont 1 && cont 2 then (3, ((b land 0x0F) lsl 12) lor (bits 1 lsl 6) lor bits 2)
  else if b >= 0xF0 && b <= 0xF4 && cont 1 && cont 2 && cont 3 then (4, ((b land 0x07) lsl 18) lor (bits 1 lsl 12) lor (bits 2 lsl 6) lor bits 3)
  else (1, b)

let of_code_point (cp : int) : string =
  let b = Buffer.create 4 in
  let add n = Buffer.add_char b (Char.chr n) in
  if cp < 0x80 then add cp
  else if cp < 0x800 then (add (0xC0 lor (cp lsr 6)); add (0x80 lor (cp land 0x3F)))
  else if cp < 0x10000 then (add (0xE0 lor (cp lsr 12)); add (0x80 lor ((cp lsr 6) land 0x3F)); add (0x80 lor (cp land 0x3F)))
  else (add (0xF0 lor ((cp lsr 18) land 7)); add (0x80 lor ((cp lsr 12) land 0x3F)); add (0x80 lor ((cp lsr 6) land 0x3F)); add (0x80 lor (cp land 0x3F)));
  Buffer.contents b

(*****************************************************************************)
(* A string is its bytes *)
(*****************************************************************************)

(* plan_browser.md, C: a string's length and its indexes are its UTF-8
 * bytes, not UTF-16's units ("é".length is 2): what a page shows is
 * the same, a script cutting an accented word in two may cut a letter *)
let ascii (_ : string) : bool = true
let length (s : string) : int = String.length s
let unit (s : string) (i : int) : int = if i < 0 || i >= String.length s then -1 else Char.code s.[i]
let byte_of (s : string) (i : int) : int = max 0 (min i (String.length s))
let unit_of (_ : string) (byte : int) : int = byte
let sub (s : string) (a : int) (b : int) : string =
  let n = String.length s in
  let a = max 0 (min a n) and b = max 0 (min b n) in
  if b <= a then "" else String.sub s a (b - a)

(* String.fromCharCode's: a unit a character, as its UTF-8 bytes *)
let of_units (units : int list) : string = String.concat "" (List.map of_code_point units)
let seam (a : string) (b : string) : string = a ^ b
let joined (s : string) : string = s

let code_points (s : string) : int list =
  let n = String.length s in
  let rec go i acc = if i >= n then List.rev acc else let bytes, cp = decode s i in go (i + bytes) (cp :: acc) in
  go 0 []

let recased ~(upper : bool) (s : string) : string = if upper then String.uppercase_ascii s else String.lowercase_ascii s
