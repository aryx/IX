(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's mini-chrome's languages/javascript/values/Js_utf16.ml (its 8af888e) (docs/plans/plan_browser.md) *)

(* See Js_utf16.mli *)

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

let high u = u >= 0xD800 && u <= 0xDBFF
let low u = u >= 0xDC00 && u <= 0xDFFF
let paired (h : int) (l : int) : int = 0x10000 + ((h - 0xD800) lsl 10) + (l - 0xDC00)

(*****************************************************************************)
(* The table *)
(*****************************************************************************)

let ascii_simple (s : string) : bool =
  let n = String.length s in
  let rec go i = i >= n || (String.unsafe_get s i < '\128' && go (i + 1)) in
  go 0

(* [starts.(u)]: the byte where the character of unit u starts (the
 * two units of a pair: the same byte); [starts.(length)]: the end *)
let table (s : string) : int array =
  let n = String.length s in
  let starts = Array.make (n + 1) n and units = ref 0 and i = ref 0 in
  while !i < n do
    let bytes, cp = decode s !i in
    starts.(!units) <- !i;
    incr units;
    if cp >= 0x10000 then (starts.(!units) <- !i; incr units);
    i := !i + bytes
  done;
  Array.sub starts 0 (!units + 1)

(* opti: the last strings asked about, by identity: whether ASCII
 * (None), else their table. Two of them: a loop often goes through
 * one string while it reads another. Without it, "for (i < s.length)
 * s.charCodeAt(i)" on a page's 1 MB of text is a scan a step *)
(* (a domain its own: two tabs' scripts run side by side) *)
let cache = Per_domain.make (fun () -> (Array.make 2 ("", None), ref 0))

let known (s : string) : int array option =
  let (kept : (string * int array option) array), turn = cache () in
  let a, ta = kept.(0) and b, tb = kept.(1) in
  if a == s then ta
  else if b == s then tb
  else
    let t = if ascii_simple s then None else Some (table s) in
    (* a short string is not worth a place: it is scanned again sooner than found *)
    if String.length s > 64 then (
      kept.(!turn) <- (s, t);
      turn := 1 - !turn);
    t

let ascii (s : string) : bool = known s = None
let length (s : string) : int = match known s with None -> String.length s | Some starts -> Array.length starts - 1

let unit (s : string) (i : int) : int =
  match known s with
  | None -> if i >= 0 && i < String.length s then Char.code (String.unsafe_get s i) else -1
  | Some starts ->
      if i < 0 || i >= Array.length starts - 1 then -1
      else
        let _, cp = decode s starts.(i) in
        if cp < 0x10000 then cp
        else if i > 0 && starts.(i - 1) = starts.(i) then 0xDC00 lor ((cp - 0x10000) land 0x3FF)
        else 0xD800 lor ((cp - 0x10000) lsr 10)

let byte_of (s : string) (i : int) : int =
  match known s with
  | None -> max 0 (min i (String.length s))
  | Some starts ->
      let n = Array.length starts - 1 in
      if i <= 0 then 0
      else if i >= n then String.length s
      (* the second half of a pair: after its character *)
      else if starts.(i - 1) = starts.(i) then starts.(i + 1)
      else starts.(i)

let unit_of (s : string) (byte : int) : int =
  match known s with
  | None -> max 0 (min byte (String.length s))
  | Some starts ->
      (* the first unit whose character starts at that byte or after *)
      let rec search lo hi = if lo >= hi then lo else let mid = (lo + hi) / 2 in if starts.(mid) < byte then search (mid + 1) hi else search lo mid in
      search 0 (Array.length starts - 1)

let sub (s : string) (a : int) (b : int) : string =
  match known s with
  | None -> String.sub s a (b - a)
  | Some starts ->
      if b <= a then ""
      else
        (* a is the second half of a pair: that half first, then from
         * the next character; b cuts a pair: up to its character, then
         * its first half *)
        let second u = u > 0 && u < Array.length starts - 1 && starts.(u - 1) = starts.(u) in
        let head = if second a then of_code_point (unit s a) else "" in
        let tail = if second b then of_code_point (unit s (b - 1)) else "" in
        let from = if second a then starts.(a + 1) else starts.(a) in
        let upto = if second b then starts.(b - 1) else starts.(b) in
        head ^ (if upto > from then String.sub s from (upto - from) else "") ^ tail

(*****************************************************************************)
(* Halves *)
(*****************************************************************************)

let of_units (units : int list) : string =
  let b = Buffer.create 16 in
  let rec go = function
    | h :: l :: rest when high h && low l -> Buffer.add_string b (of_code_point (paired h l)); go rest
    | u :: rest -> Buffer.add_string b (of_code_point (u land 0xFFFF)); go rest
    | [] -> ()
  in
  go units;
  Buffer.contents b

(* the half a text ends with, or starts with: its three bytes are ED,
 * A0..AF (high) or B0..BF (low), and one more *)
let half_at (s : string) (i : int) : int option =
  if i >= 0 && i + 2 < String.length s && s.[i] = '\xED' && Char.code s.[i + 1] >= 0xA0 then Some (snd (decode s i)) else None

let seam (a : string) (b : string) : string =
  match (half_at a (String.length a - 3), half_at b 0) with
  | Some h, Some l when high h && low l && String.length a >= 3 ->
      String.sub a 0 (String.length a - 3) ^ of_code_point (paired h l) ^ String.sub b 3 (String.length b - 3)
  | _ -> a ^ b

let joined (s : string) : string =
  if not (String.contains s '\xED') then s
  else
    let n = String.length s and b = Buffer.create (String.length s) in
    let rec go i =
      if i < n then
        match (half_at s i, half_at s (i + 3)) with
        | Some h, Some l when high h && low l -> Buffer.add_string b (of_code_point (paired h l)); go (i + 6)
        | _ -> Buffer.add_char b s.[i]; go (i + 1)
    in
    go 0;
    Buffer.contents b

let code_points (s : string) : int list =
  let n = String.length s in
  let rec go i acc = if i >= n then List.rev acc else let bytes, cp = decode s i in go (i + bytes) (cp :: acc) in
  go 0 []

(*****************************************************************************)
(* Case *)
(*****************************************************************************)

(* a letter's other case, for the alphabets whose two cases are a
 * fixed step apart: Latin-1's accented letters, Latin Extended-A's
 * pairs, Greek, Cyrillic. The rest (and the letters whose other case
 * is two letters) are left as they are *)
let cased ~(upper : bool) (cp : int) : int =
  let step lo hi by = if upper then (if cp >= lo + by && cp <= hi + by then cp - by else cp) else if cp >= lo && cp <= hi then cp + by else cp in
  if cp < 0x80 then Char.code ((if upper then Char.uppercase_ascii else Char.lowercase_ascii) (Char.chr cp))
  else if cp < 0x100 then if cp = 0xD7 || cp = 0xF7 || cp = 0xDF then cp else if cp = 0xFF then (if upper then 0x178 else cp) else step 0xC0 0xDE 0x20
  else if cp = 0x178 then if upper then cp else 0xFF
  else if cp < 0x180 then
    (* pairs, the capital first: even then odd -- but from U+0139 to U+0148 and U+0179 to U+017E, odd then even *)
    let odd_first = (cp >= 0x139 && cp <= 0x148) || (cp >= 0x179 && cp <= 0x17E) in
    let capital = if odd_first then cp land 1 = 1 else cp land 1 = 0 in
    if cp = 0x130 || cp = 0x131 || cp = 0x138 || cp = 0x149 || cp = 0x17F then cp else if upper then (if capital then cp else cp - 1) else if capital then cp + 1 else cp
  (* Greek: the letters, the final sigma (a capital sigma's too), and the vowels with a tonos *)
  else if cp >= 0x386 && cp <= 0x3CE then (
    match List.find_opt (fun (big, small) -> if upper then small = cp else big = cp) [ (0x386, 0x3AC); (0x388, 0x3AD); (0x389, 0x3AE); (0x38A, 0x3AF); (0x38C, 0x3CC); (0x38E, 0x3CD); (0x38F, 0x3CE) ] with
    | Some (big, small) -> if upper then big else small
    | None -> if cp = 0x3C2 then (if upper then 0x3A3 else cp) else if cp = 0x3A2 || cp < 0x391 || (cp > 0x3AB && cp < 0x3B1) || cp > 0x3CB then cp else step 0x391 0x3AB 0x20)
  else if cp >= 0x400 && cp <= 0x45F then if cp <= 0x40F || cp >= 0x450 then step 0x400 0x40F 0x50 else step 0x410 0x42F 0x20
  else cp

let recased ~(upper : bool) (s : string) : string =
  if ascii_simple s then (if upper then String.uppercase_ascii s else String.lowercase_ascii s)
  else String.concat "" (List.map (fun cp -> of_code_point (cased ~upper cp)) (code_points s))
