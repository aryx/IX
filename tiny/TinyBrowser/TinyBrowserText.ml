(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyBrowserText.mli *)

(*****************************************************************************)
(* Strings *)
(*****************************************************************************)

(* Returns the position of pat in s, searching from i, or -1. *)
let find s pat i =
  let n = String.length s and m = String.length pat in
  let rec at j k = k >= m || (s.[j + k] = pat.[k] && at j (k + 1)) in
  let rec go j = if j + m > n then -1 else if at j 0 then j else go (j + 1) in
  go i

let is_space c = c = ' ' || c = '\n' || c = '\t' || c = '\r'

(* Is w one of the space-separated words of a class attribute? *)
let has_class classes w =
  w <> "" && List.mem w (String.split_on_char ' ' classes)

(* an attribute's number, 0 when it is not one *)
let number s = match int_of_string_opt s with Some n -> n | None -> 0

(*****************************************************************************)
(* Characters *)
(*****************************************************************************)

(* The Latin-1 letters from 0xc0 on, each without its accent; and
 * Latin Extended-A's, from 0x100 to 0x17f (the names of Central Europe:
 * c with a caron, l with a stroke, o with a double acute), the same way
 * (made from Unicode's decompositions). *)
let latin1 = "AAAAAAACEEEEIIIIDNOOOOOxOUUUUYPsaaaaaaaceeeeiiiidnooooo/ouuuuypy"
let latin_a =
  "AaAaAaCcCcCcCcDdDdEeEeEeEeEeGgGgGgGgHhHhIiIiIiIiIiIiJjKkkLlLlLlLlLlNnNnNnnNnOoOoOoOoRrRrRrSsSsSsSsTtTtTtUuUuUuUuUuUuWwYyYZzZzZzs"

(* Converts a Unicode code point to what the 128-character font can show. *)
let of_code u =
  if u < 128 then
    (if u = 9 || u = 10 then " " else if u < 32 then ""
     else String.make 1 (Char.chr u))
  else if u >= 0xc0 && u <= 0xff then String.make 1 latin1.[u - 0xc0]
  else if u = 0x152 then "OE" else if u = 0x153 then "oe"
  else if u >= 0x100 && u < 0x180 then String.make 1 latin_a.[u - 0x100]
  else match u with
  | 0x20ac -> "EUR" | 0xa3 -> "GBP" | 0xa5 -> "JPY" | 0xa7 -> "S."
  | 0xb2 -> "2" | 0xb3 -> "3" | 0xb9 -> "1" | 0xbc -> "1/4" | 0xbe -> "3/4"
  | 0xa0 | 0x2002 | 0x2003 | 0x2009 | 0x202f -> " "
  | 0xad | 0x200b | 0x200c | 0x200d | 0x200e | 0x200f | 0x2060 | 0xfeff -> ""
  | 0xa9 -> "(c)" | 0xae -> "(R)" | 0xb0 -> "o" | 0xb1 -> "+-"
  | 0xb7 | 0x2219 | 0x22c5 -> "."
  | 0xab -> "<<" | 0xbb -> ">>" | 0xbd -> "1/2" | 0xd7 -> "x" | 0xf7 -> "/"
  | 0x2010 | 0x2011 | 0x2012 | 0x2013 | 0x2014 | 0x2015 | 0x2212 -> "-"
  | 0x2018 | 0x2019 | 0x201a | 0x2032 | 0x2bc -> "'"
  | 0x201c | 0x201d | 0x201e | 0x2033 -> "\""
  | 0x2022 | 0x25cf -> "*" | 0x2026 -> "..." | 0x2192 -> "->"
  | 0x2190 -> "<-" | 0x2191 -> "^" | 0x21d2 -> "=>"
  | 0x2264 -> "<=" | 0x2265 -> ">=" | 0x2260 -> "/=" | 0x2248 -> "~"
  | 0x221e -> "inf"
  | 0x3bb -> "lambda" | 0x3b1 -> "alpha" | 0x3b2 -> "beta" | 0x3b3 -> "gamma"
  | 0x3b4 -> "delta" | 0x3b5 -> "epsilon"
  | 0x3b8 -> "theta" | 0x3bc -> "mu" | 0x3c0 -> "pi" | 0x3c3 -> "sigma"
  | 0x3c6 | 0x3d5 -> "phi" | 0x3c9 -> "omega"
  | 0x394 -> "Delta" | 0x3a3 -> "Sigma" | 0x3a9 -> "Omega"
  | 0x21a6 -> "|->" | 0x2208 -> "in" | 0x2295 -> "(+)" | 0x2021 -> "++"
  | 0x200a | 0x2061 -> "" 
  | _ -> "?"

let entity name =
  match name with
  | "amp" -> 38 | "lt" -> 60 | "gt" -> 62 | "quot" -> 34 | "apos" -> 39
  | "nbsp" -> 0xa0
  | "ndash" -> 0x2013 | "mdash" -> 0x2014 | "minus" -> 0x2212
  | "hellip" -> 0x2026
  | "lsquo" -> 0x2018 | "rsquo" -> 0x2019 | "ldquo" -> 0x201c
  | "rdquo" -> 0x201d
  | "middot" -> 0xb7 | "bull" -> 0x2022 | "times" -> 0xd7 | "copy" -> 0xa9
  | "reg" -> 0xae
  | "shy" -> 0xad
  | "rarr" -> 0x2192 | "larr" -> 0x2190 | "laquo" -> 0xab | "raquo" -> 0xbb
  | "deg" -> 0xb0
  | "eacute" -> 0xe9 | "egrave" -> 0xe8 | "aacute" -> 0xe1 | "ouml" -> 0xf6
  | "uuml" -> 0xfc
  | _ -> -1

(* Returns the code point of an entity, given the text between its &
 * and its ; (like "amp", "#8211" or "#x2013"), or -1 if it is unknown:
 * a number's, as int_of_string reads 08211 and 0x2013 *)
let entity_code s =
  let n = String.length s in
  if n > 1 && s.[0] = '#' then
    (match
       int_of_string_opt
         ("0" ^ String.lowercase_ascii (String.sub s 1 (n - 1)))
     with
     | Some u -> u
     | None -> -1)
  else entity s

(* How many bytes a UTF-8 character has, given its first byte. *)
let utf8_length b =
  if b < 0x80 then 1 else if b < 0xc0 then 1 else if b < 0xe0 then 2
  else if b < 0xf0 then 3 else 4

let ascii s =
  let n = String.length s in
  if not (String.exists (fun c -> c = '&' || Char.code c >= 128) s) then s
  else begin
    (* The result is built as a list of pieces: stretches of plain
     * ASCII copied as they are, and a replacement for each entity or
     * non-ASCII character. *)
    let pieces = ref [] and plain = ref 0 in
    let cut i =
      if i > !plain then pieces := String.sub s !plain (i - !plain) :: !pieces
    in
    let i = ref 0 in
    while !i < n do
      let c = s.[!i] in
      if c = '&' then begin
        let j = ref (!i + 1) in
        while !j < n && !j - !i < 12 && s.[!j] <> ';' && not (is_space s.[!j])
              && s.[!j] <> '&' do
          incr j
        done;
        let u =
          if !j < n && s.[!j] = ';' then
            entity_code (String.sub s (!i + 1) (!j - !i - 1))
          else -1 in
        if u >= 0 then begin
          cut !i; pieces := of_code u :: !pieces; i := !j + 1; plain := !i
        end
        else incr i
      end
      else if Char.code c >= 128 then begin
        let b = Char.code c in
        let len = utf8_length b in
        let rec follows k =
          k >= len
          || (Char.code s.[!i + k] land 0xc0 = 0x80 && follows (k + 1)) in
        let u =
          if len = 1 || !i + len > n || not (follows 1) then -1
          else if len = 2 then
            ((b land 0x1f) lsl 6) lor (Char.code s.[!i + 1] land 0x3f)
          else if len = 3 then
            ((b land 0x0f) lsl 12)
            lor ((Char.code s.[!i + 1] land 0x3f) lsl 6)
            lor (Char.code s.[!i + 2] land 0x3f)
          else 0x10000 in
        cut !i;
        pieces := (if u < 0 then "?" else of_code u) :: !pieces;
        i := !i + (if u < 0 then 1 else len);
        plain := !i
      end
      else incr i
    done;
    cut n;
    String.concat "" (List.rev !pieces)
  end

(* When a text runs to the end of a message, the next message may
 * continue it. This returns where it is safe to cut it: never in the
 * middle of an entity or of a UTF-8 character, and only after a space,
 * so that a word is never split in two. *)
let safe_end s i n =
  let rec amp j =
    if j < i || j < n - 12 then n else if s.[j] = '&' then j
    else if s.[j] = ';' || is_space s.[j] then n else amp (j - 1) in
  let a = amp (n - 1) in
  let rec lead j =
    if j > i && j > n - 4 && Char.code s.[j] land 0xc0 = 0x80 then lead (j - 1)
    else j in
  let l = if n > i && Char.code s.[n - 1] >= 0x80 then lead (n - 1) else n in
  let l = if l < n && l + utf8_length (Char.code s.[l]) > n then l else n in
  (* Back up to just after the last space. *)
  let rec space j =
    if j <= i then i else if is_space s.[j - 1] then j else space (j - 1) in
  space (min a l)
