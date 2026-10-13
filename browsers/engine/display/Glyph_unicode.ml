(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's mini-chrome's src/display/Glyph_unicode.ml; ~closer and ~r said (no optional argument), a character's number by Utf8 (docs/plans/plan_browser.md) *)

(* See Glyph_unicode.mli *)

type glyph = Hershey.glyph

(* Hershey's units: y down, a capital's top at -12, a small letter's
 * at -5, the baseline at 9; a glyph's x around 0 *)

(*****************************************************************************)
(* Glyphs put together *)
(*****************************************************************************)

let ascii (c : char) : glyph = Hershey.glyph c
let width (g : glyph) : int = g.right - g.left
let shifted (dx : int) (strokes : (int * int) list list) = List.map (List.map (fun (x, y) -> (x + dx, y))) strokes

(* strokes drawn over a glyph, its width kept *)
let over (g : glyph) (strokes : (int * int) list list) : glyph = { g with strokes = g.strokes @ strokes }

(* two glyphs side by side, the second [closer] to the first *)
let beside ~(closer : int) (a : glyph) (b : glyph) : glyph =
  { left = a.left; right = a.right + width b - closer; strokes = a.strokes @ shifted (a.right - b.left - closer) b.strokes }

let of_text ~(closer : int) (s : string) : glyph =
  match List.init (String.length s) (fun i -> ascii s.[i]) with
  | first :: rest -> List.fold_left (fun a b -> beside ~closer a b) first rest
  | [] -> { left = 0; right = 0; strokes = [] }

(* upside down, as Spanish opens a question *)
let flipped (g : glyph) : glyph = { g with strokes = List.map (List.map (fun (x, y) -> (-x, 2 - y))) g.strokes }
let nothing : glyph = { left = 0; right = 0; strokes = [] }
let drawn ~(half : int) (strokes : (int * int) list list) : glyph = { left = -half; right = half; strokes }

(*****************************************************************************)
(* The marks *)
(*****************************************************************************)

(* a mark's strokes over a letter whose top is at [top] (-12 a capital's
 * or a tall small letter's, -5 a small one's): between top - 5 and
 * top - 2 *)
let above (mark : char) (top : int) : (int * int) list list =
  let hi = top - 5 and lo = top - 2 and mid = top - 3 in
  match mark with
  | '\'' -> [ [ (-1, lo); (3, hi) ] ]
  | '`' -> [ [ (-3, hi); (1, lo) ] ]
  | '^' -> [ [ (-3, lo); (0, hi); (3, lo) ] ]
  | 'v' -> [ [ (-3, hi); (0, lo); (3, hi) ] ]
  | '~' -> [ [ (-4, lo); (-2, hi); (2, lo); (4, hi) ] ]
  | ':' -> [ [ (-3, mid); (-3, mid - 1) ]; [ (3, mid); (3, mid - 1) ] ]
  | '.' -> [ [ (0, mid); (0, mid - 1) ] ]
  | 'o' -> [ [ (0, hi); (2, mid); (0, lo); (-2, mid); (0, hi) ] ]
  | '-' -> [ [ (-4, mid); (4, mid) ] ]
  | 'u' -> [ [ (-3, hi); (-1, lo); (1, lo); (3, hi) ] ]
  | '"' -> [ [ (-3, lo); (0, hi) ]; [ (1, lo); (4, hi) ] ]
  | _ -> []

(* a letter and its mark: the mark above (over a small letter's
 * x-height or over a capital), below, or across *)
let marked (base : char) (mark : char) : glyph =
  let g = ascii base in
  let tall = (base >= 'A' && base <= 'Z') || String.contains "bdfhklt" base in
  match mark with
  | ' ' | '?' -> g
  (* a cedilla, an ogonek: under the baseline *)
  | ',' -> over g [ [ (0, 9); (1, 11); (-1, 13) ] ]
  | ';' -> over g [ [ (3, 9); (2, 11); (3, 13); (5, 13) ] ]
  (* a stroke across: through an o, short on an l, a bar on the others *)
  | '/' ->
      over g
        (match base with
        | 'o' -> [ [ (-6, 10); (7, -6) ] ]
        | 'O' -> [ [ (-8, 10); (8, -13) ] ]
        | 'l' | 'L' -> [ [ (-4, 1); (4, -4) ] ]
        | 'd' -> [ [ (2, -9); (9, -9) ] ]
        | 'h' -> [ [ (-8, -9); (-1, -9) ] ]
        | 't' -> [ [ (-4, 2); (4, 2) ] ]
        | 'D' -> [ [ (-9, -2); (-1, -2) ] ]
        | 'H' -> [ [ (-9, -7); (9, -7) ] ]
        | _ -> [ [ (-5, -2); (5, -2) ] ])
  | mark ->
      (* an i's or a j's own dot gives its place to the mark *)
      let g = if base = 'i' || base = 'j' then { g with strokes = List.filter (List.exists (fun (_, y) -> y > -9)) g.strokes } else g in
      over g (above mark (if tall then -12 else -5))

(* Latin-1's letters, U+00C0 to U+00DF, and their small ones 32 after:
 * the letter and its mark (a space: none here, said below) *)
let latin_1 = "A`A'A^A~A:Ao  C,E`E'E^E:I`I'I^I:  N~O`O'O^O~O:  O/U`U'U^U:Y'    "

(* Latin Extended-A, U+0100 to U+017F: a capital and its small letter
 * mostly, a pair each *)
let latin_a =
  "A-a-AuauA;a;C'c'C^c^C.c.CvcvDvdvD/d/E-e-EueuE.e.E;e;EvevG^g^GuguG.g.G,g,H^h^H/h/I~i~I-i-IuiuI;i;I.i?I?i?J^j^K,k,k?L'l'L,l,LvlvL?l?L/l/N'n'N,n,Nvnvn?N?n?O-o-OuouO\"o\"O?o?R'r'R,r,RvrvS's'S^s^S,s,SvsvT,t,TvtvT/t/U~u~U-u-UuuuUouoU\"u\"U;u;W^w^Y^y^Y:Z'z'Z.z.Zvzvs?"

(*****************************************************************************)
(* A character *)
(*****************************************************************************)

let dash = ascii '-'

(* a small diamond round (0, y): a dot the pen can draw *)
let dot ~(r : int) (y : int) = [ (0, y - r); (r, y); (0, y + r); (-r, y); (0, y - r) ]

(* an arrow from (x1, y1) to (x2, y2), its two barbs *)
let arrow (x1, y1) (x2, y2) : glyph =
  let dx = compare x2 x1 and dy = compare y2 y1 in
  drawn ~half:11 [ [ (x1, y1); (x2, y2) ]; [ (x2 - (4 * dx) - (3 * dy), y2 - (4 * dy) - (3 * dx)); (x2, y2); (x2 - (4 * dx) + (3 * dy), y2 - (4 * dy) + (3 * dx)) ] ]

let of_code (cp : int) : glyph option =
  let some g = Some g in
  let pair (table : string) (i : int) = if (2 * i) + 1 < String.length table then Some (table.[2 * i], table.[(2 * i) + 1]) else None in
  match cp with
  | _ when cp < 0x80 -> some (ascii (Char.chr cp))
  (* what is not a letter and its mark, in Latin-1 *)
  | 0xC6 -> some (beside ~closer:7 (ascii 'A') (ascii 'E'))
  | 0xE6 -> some (beside ~closer:6 (ascii 'a') (ascii 'e'))
  | 0x152 -> some (beside ~closer:8 (ascii 'O') (ascii 'E'))
  | 0x153 -> some (beside ~closer:6 (ascii 'o') (ascii 'e'))
  | 0xDF -> some (of_text ~closer:3 "ss")
  | 0xD0 -> some (marked 'D' '/')
  | 0xF0 -> some (marked 'd' '/')
  | 0xDE -> some (ascii 'P')
  | 0xFE -> some (ascii 'p')
  | 0xD7 -> some (ascii 'x')
  | 0xF7 -> some (over dash [ dot ~r:1 (-5); dot ~r:1 5 ])
  | 0xFF -> some (marked 'y' ':')
  (* Turkish's i with no dot *)
  | 0x131 -> let g = ascii 'i' in some { g with strokes = List.filter (List.exists (fun (_, y) -> y > -9)) g.strokes }
  | _ when cp >= 0xC0 && cp <= 0xFE -> (
      (* a small letter is its capital's entry, in small *)
      let small = cp >= 0xE0 in
      match pair latin_1 (if small then cp - 0xE0 else cp - 0xC0) with
      | Some (base, mark) when base <> ' ' -> some (marked (if small then Char.lowercase_ascii base else base) mark)
      | _ -> None)
  | _ when cp >= 0x100 && cp <= 0x17F -> ( match pair latin_a (cp - 0x100) with Some (base, mark) -> some (marked base mark) | None -> None)
  (* spaces, and what takes no room *)
  | 0xA0 | 0x2002 | 0x2003 | 0x2004 | 0x2005 | 0x2006 | 0x2007 | 0x2008 | 0x2009 | 0x200A | 0x202F | 0x205F | 0x3000 -> some (ascii ' ')
  | 0xAD | 0x200B | 0x200C | 0x200D | 0x200E | 0x200F | 0x2060 | 0xFEFF -> some nothing
  (* what a word processor writes for the quotes, the dash, three dots *)
  | 0x2018 | 0x2019 | 0x201A | 0x201B | 0x2032 | 0xB4 | 0x2BC -> some (ascii '\'')
  | 0x201C | 0x201D | 0x201E | 0x201F | 0x2033 | 0xA8 -> some (ascii '"')
  | 0x2010 | 0x2011 | 0x2012 | 0x2013 | 0x2212 | 0xAC | 0xAF -> some dash
  | 0x2014 | 0x2015 -> some (drawn ~half:(width dash) [ [ (5 - width dash, 0); (width dash - 5, 0) ] ])
  | 0x2026 -> some (of_text ~closer:0 "...")
  | 0xAB -> some (of_text ~closer:14 "<<")
  | 0xBB -> some (of_text ~closer:14 ">>")
  | 0x2039 -> some (ascii '<')
  | 0x203A -> some (ascii '>')
  (* signs: drawn, or the ASCII they are read as *)
  | 0xB7 | 0x2219 | 0x22C5 -> some (drawn ~half:5 [ dot ~r:1 1 ])
  | 0x2022 | 0x25CF | 0x25AA -> some (drawn ~half:7 [ dot ~r:3 1; dot ~r:1 1 ])
  | 0xB0 -> some (drawn ~half:5 [ dot ~r:2 (-10) ])
  | 0xA1 -> some (flipped (ascii '!'))
  | 0xBF -> some (flipped (ascii '?'))
  | 0x20AC -> some (over (ascii 'C') [ [ (-10, -3); (3, -3) ]; [ (-10, 1); (3, 1) ] ])
  | 0xA3 -> some (over (ascii 'L') [ [ (-8, -1); (2, -1) ] ])
  | 0xA5 -> some (over (ascii 'Y') [ [ (-5, 1); (5, 1) ]; [ (-5, 4); (5, 4) ] ])
  | 0xA2 -> some (over (ascii 'c') [ [ (0, -8); (0, 12) ] ])
  | 0xB1 -> some (over (ascii '+') [ [ (-8, 9); (8, 9) ] ])
  | 0xA9 -> some (of_text ~closer:3 "(c)")
  | 0xAE -> some (of_text ~closer:3 "(R)")
  | 0x2122 -> some (of_text ~closer:2 "TM")
  | 0xBC -> some (of_text ~closer:3 "1/4")
  | 0xBD -> some (of_text ~closer:3 "1/2")
  | 0xBE -> some (of_text ~closer:3 "3/4")
  | 0x2116 -> some (of_text ~closer:0 "No")
  | 0x2030 -> some (ascii '%')
  | 0xA7 -> some (ascii 'S')
  | 0xB6 -> some (ascii 'P')
  | 0xB5 -> some (ascii 'u')
  | 0xB9 -> some (ascii '1')
  | 0xB2 -> some (ascii '2')
  | 0xB3 -> some (ascii '3')
  | 0xAA -> some (ascii 'a')
  | 0xBA -> some (ascii 'o')
  | 0xA6 -> some (ascii '|')
  | 0xB8 -> some (ascii ',')
  | 0x2020 | 0x2021 -> some (ascii '+')
  | 0x2605 | 0x2606 | 0x2217 -> some (ascii '*')
  | 0x2715 | 0x2717 | 0x2716 | 0x2A2F -> some (ascii 'x')
  | 0x2713 | 0x2714 -> some (drawn ~half:9 [ [ (-6, 0); (-2, 6); (7, -9) ] ])
  | 0x2190 -> some (arrow (8, 0) (-8, 0))
  | 0x2192 -> some (arrow (-8, 0) (8, 0))
  | 0x2191 -> some (arrow (0, 8) (0, -10))
  | 0x2193 -> some (arrow (0, -10) (0, 8))
  | _ -> None

let code_of (s : string) : int =
  if String.length s = 1 then Char.code s.[0]
  else
    (* bytes that are no character (Utf8's 0xFFFD for them): none we know *)
    match Utf8.decode s 0 with 0xFFFD, _ -> -1 | cp, _ -> cp

let known (s : string) : bool = s <> "" && (match code_of s with -1 -> false | cp -> of_code cp <> None)

(* measured (2 million calls): 0.013 microseconds for an ASCII
 * character, where Hershey.glyph alone is 0.010; 0.12 for a letter
 * with a mark, put together each time it is asked. A table keeping
 * those made 0.04 of it: not worth a table -- a page of fifty thousand
 * accented letters is 6 ms of this a layout (mini-chrome's numbers) *)
let glyph (s : string) : glyph =
  if s = "" then ascii '?'
  else if String.length s = 1 then ascii s.[0]
  else match code_of s with -1 -> ascii '?' | cp -> ( match of_code cp with Some g -> g | None -> ascii '?')
