(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Roff.mli *)

type device = Terminal | Typesetter
type line = Request of string * string list | Text of string

type t = {
  device : device;
  (* the lines not read yet, each with its number: a macro's lines are
   * put before the others *)
  mutable input : (int * string) list;
  mutable at : int;
  strings : (string, string) Hashtbl.t;
  registers : (string, float) Hashtbl.t;
  macros : (string, string list) Hashtbl.t;
  mutable font : Doc.font;
  mutable before : Doc.font;
  mutable size : int;
  mutable shift : int;
  (* what the last .ie found, for its .el *)
  mutable taken : bool;
  (* .ec: the character that starts an escape; none after .eo *)
  mutable escape : char option;
  (* .tr: a character written as another *)
  mutable translate : (string * string) list;
  (* .hc: a character that says where a word may be cut *)
  mutable hyphen : char option;
  (* \% was before the word being read: its hyphens are not places to
   * cut it *)
  mutable whole : bool;
  (* a text's width, in ens: \w's *)
  mutable measure : Doc.inline list -> float;
  (* a file's text, by its name: .so's, a picture's *)
  mutable loader : string -> string option;
  mutable complaints : (int * string) list;
}

(* a terminal's: every character one wide *)
let letters_width (text : Doc.inline list) : float =
  List.fold_left (fun w (i : Doc.inline) -> match i with Doc.Text (_, s) -> w +. float_of_int (Utf8.length (Doc.letters s)) | Doc.Break -> w) 0. text

let create (device : device) (source : string) : t =
  let lines = String.split_on_char '\n' (String.concat "" (String.split_on_char '\r' source)) in
  (* (a file ends with a newline: no line after it) *)
  let lines = match List.rev lines with "" :: rest -> List.rev rest | _ -> lines in
  { device; input = List.mapi (fun i l -> (i + 1, l)) lines; at = 0; strings = Hashtbl.create 16; registers = Hashtbl.create 16;
    macros = Hashtbl.create 16; font = Doc.Roman; before = Doc.Roman; size = 0; shift = 0; taken = false; escape = Some '\\'; translate = []; hyphen = None; whole = false; measure = letters_width; loader = (fun _ -> None); complaints = [] }

let device (t : t) = t.device
let set_loader (t : t) (f : string -> string option) = t.loader <- f
let load (t : t) (name : string) : string option = t.loader name
let set_measure (t : t) (f : Doc.inline list -> float) = t.measure <- f
let line_number (t : t) = t.at
let unknown (t : t) (what : string) = t.complaints <- (t.at, what) :: t.complaints
let complaints (t : t) = List.rev t.complaints
let register (t : t) (name : string) : float option = Hashtbl.find_opt t.registers name
let set_register (t : t) (name : string) (v : float) = Hashtbl.replace t.registers name v
let set_string (t : t) (name : string) (v : string) = Hashtbl.replace t.strings name v
let font (t : t) = t.font
let set_font (t : t) (f : Doc.font) = t.before <- t.font; t.font <- f
(* .ps: +2, -2, 10 (the text's own being 10), or nothing: as it was *)
let resize (t : t) (s : string) =
  if s = "" then t.size <- 0
  else
    match int_of_string_opt (if s.[0] = '+' then String.sub s 1 (String.length s - 1) else s) with
    | None -> ()
    | Some v -> if s.[0] = '+' || s.[0] = '-' then t.size <- t.size + v else t.size <- v - 10

let reset_style (t : t) = t.font <- Doc.Roman; t.before <- Doc.Roman; t.size <- 0; t.shift <- 0

let font_named (t : t) (name : string) : Doc.font =
  match name with
  | "R" | "1" -> Doc.Roman
  | "I" | "2" -> Doc.Italic
  | "B" | "3" -> Doc.Bold
  | "L" | "5" | "CW" | "4" -> Doc.Mono
  | "P" | "" -> t.before
  | _ -> unknown t ("font " ^ name); Doc.Roman

(*****************************************************************************)
(* A character by its name: \(em *)
(*****************************************************************************)

(* (troff's names, those the manual and the papers use and a few
 * around them; a terminal's page has the character itself) *)
let special (device : device) (name : string) : string option =
  match name with
  (* (a terminal has no dash longer than its hyphen: Plan 9's table for
   * one, tab.utf, says so) *)
  | "em" -> Some (if device = Terminal then "-" else "—") | "en" -> Some (if device = Terminal then "-" else "–")
  | "hy" -> Some "-" | "mi" -> Some "\xe2\x88\x92" | "pl" -> Some "+" | "eq" -> Some "="
  | "bu" -> Some "•" | "sq" -> Some "□" | "dg" -> Some "†" | "dd" -> Some "‡" | "ct" -> Some "¢" | "sc" -> Some "§"
  | "->" -> Some "→" | "<-" -> Some "←" | "ua" -> Some "↑" | "da" -> Some "↓"
  | "mu" -> Some "×" | "di" -> Some "÷" | "+-" -> Some "±" | "de" -> Some "°" | "sr" -> Some "√" | "rn" -> Some "‾"
  | "<=" -> Some "≤" | ">=" -> Some "≥" | "!=" -> Some "≠" | "==" -> Some "≡" | "~=" -> Some "≅" | "ap" -> Some "∼"
  | "if" -> Some "∞" | "pd" -> Some "∂" | "gr" -> Some "∇" | "no" -> Some "¬" | "is" -> Some "∫" | "pt" -> Some "∝"
  | "es" -> Some "∅" | "mo" -> Some "∈" | "ca" -> Some "∩" | "cu" -> Some "∪" | "sb" -> Some "⊂" | "sp" -> Some "⊃"
  | "**" -> Some "*" | "or" -> Some "|" | "br" -> Some "│" | "ul" -> Some "_" | "ru" -> Some "_" | "sl" -> Some "/"
  | "aa" -> Some (if device = Terminal then "'" else "´") | "ga" -> Some "`" | "fm" -> Some (if device = Terminal then "'" else "′")
  | "co" -> Some "©" | "rg" -> Some "®" | "tm" -> Some "™"
  | "14" -> Some "¼" | "12" -> Some "½" | "34" -> Some "¾" | "lh" -> Some "☜" | "rh" -> Some "☞" | "bs" -> Some "☎"
  | "ci" -> Some "○" | "bx" -> Some "■" | "fi" -> Some "fi" | "fl" -> Some "fl" | "ff" -> Some "ff"
  | "*a" -> Some "α" | "*b" -> Some "β" | "*g" -> Some "γ" | "*d" -> Some "δ" | "*e" -> Some "ε" | "*l" -> Some "λ"
  | "*m" -> Some "µ" | "*p" -> Some "π" | "*s" -> Some "σ" | "*t" -> Some "τ" | "*f" -> Some "φ" | "*w" -> Some "ω"
  | "*D" -> Some "Δ" | "*S" -> Some "Σ" | "*W" -> Some "Ω" | "*P" -> Some "Π"
  | _ -> None

(*****************************************************************************)
(* Numbers *)
(*****************************************************************************)

(* troff counts in a unit as small as its device needs. A terminal's,
 * as nroff's: 240 to the inch, a letter 24 wide (ten to the inch), a
 * line 40 high (six to the inch). A typesetter's here: a tenth of a
 * point, the text 10 points on 12, so an en is 50 and a line 120. *)
let ens (t : t) (u : float) : float = u /. (if t.device = Terminal then 24. else 50.)
let lines (t : t) (u : float) : float = u /. (if t.device = Terminal then 40. else 120.)

let scale (t : t) (unit : char) : float =
  if t.device = Terminal then
    match unit with
    | 'i' -> 240. | 'n' | 'm' -> 24. | 'v' | 'P' -> 40. | 'p' -> 240. /. 72. | 'c' -> 240. /. 2.54 | _ -> 1.
  else
    match unit with
    | 'i' -> 720. | 'n' -> 50. | 'm' -> 100. | 'v' | 'P' -> 120. | 'p' -> 10. | 'c' -> 720. /. 2.54 | _ -> 1.

(*****************************************************************************)
(* What is in a line: words in fonts *)
(*****************************************************************************)

let is_digit (c : char) = c >= '0' && c <= '9'

(* [quoted s i]: what is between the character at i and the next one
 * like it ('...'), and where the text goes on *)
let quoted (s : string) (i : int) : string * int =
  if i >= String.length s then ("", i)
  else
    match String.index_from_opt s (i + 1) s.[i] with
    | Some j -> (String.sub s (i + 1) (j - i - 1), j + 1)
    | None -> (String.sub s (i + 1) (String.length s - i - 1), String.length s)

(* a name after an escape: one letter, or ( and two *)
let name_at (s : string) (i : int) : string * int =
  let n = String.length s in
  if i >= n then ("", i)
  else if s.[i] = '(' then (String.sub s (i + 1) (min 2 (n - i - 1)), min n (i + 3))
  else (String.sub s i 1, i + 1)

let continues (s : string) : bool = String.ends_with ~suffix:"\\c" s && not (String.ends_with ~suffix:"\\\\c" s)

let rec inlines (t : t) (s : string) : Doc.inline list =
  let n = String.length s in
  let out = ref [] and run = Buffer.create 64 in
  let style () : Doc.style = { font = t.font; size = t.size; shift = t.shift } in
  (* the letters so far are in the style as it was: said before it changes *)
  let flush () =
    if Buffer.length run > 0 then begin
      let text = Buffer.contents run in
      let text = if t.translate = [] then text else String.concat "" (List.map (fun c -> match List.assoc_opt c t.translate with Some d -> d | None -> c) (fst (Utf8.chars text))) in
      out := Doc.Text (style (), text) :: !out; Buffer.clear run
    end in
  let is_letter (c : char) = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') in
  let rec go i =
    if i < n then
      if Some s.[i] = t.hyphen then begin
        if Buffer.length run > 0 && is_letter (Buffer.nth run (Buffer.length run - 1)) && i + 1 < n && is_letter s.[i + 1] then Buffer.add_string run "\xc2\xad";
        go (i + 1)
      end
      else if s.[i] = '-' && t.whole then begin Buffer.add_string run "\xe2\x80\x91"; go (i + 1) end
      else if s.[i] <> '\\' then begin if s.[i] = ' ' || s.[i] = '\t' then t.whole <- false; Buffer.add_char run s.[i]; go (i + 1) end
      else if i + 1 >= n then ()
      else
        let c = s.[i + 1] and j = i + 2 in
        match c with
        | '\\' | 'e' -> Buffer.add_char run '\\'; go j
        (* inside a word: where it may be cut, with a hyphen (U+00AD) *)
        | '%' when Buffer.length run > 0 && is_letter (Buffer.nth run (Buffer.length run - 1)) && j < n && is_letter s.[j] -> Buffer.add_string run "\xc2\xad"; go j
        (* before a word: it is not to be cut, and its hyphens are
         * written as the ones a line does not end after (U+2011) *)
        | '%' -> t.whole <- true; go j
        (* nothing, but something: after a dot, the sentence does not end
         * there (U+2060, the word joiner) *)
        | '&' -> Buffer.add_string run "\xe2\x81\xa0"; go j
        | '|' | '^' | '{' | '}' | 'z' | '!' -> go j
        | ' ' | '0' | '~' -> Buffer.add_string run "\xc2\xa0"; go j
        (* a minus (U+2212), not a hyphen: no line ends after it *)
        | '-' -> Buffer.add_string run "\xe2\x88\x92"; go j
        | 't' | 'a' -> Buffer.add_char run '\t'; go j
        | 'c' -> go j
        | '(' | 'C' ->
            let name, k = if c = '(' then name_at s (i + 1) else quoted s j in
            (match special t.device name with
             | Some ch -> Buffer.add_string run ch
             | None -> unknown t ("\\(" ^ name); Buffer.add_string run name);
            go k
        | 'f' ->
            let name, k = name_at s j in
            flush (); set_font t (font_named t name); go k
        | 's' ->
            (* \s8, \s-2, \s+2, \s0 (as it was), \s10: two digits when
             * the first is 1, 2 or 3 *)
            let sign, k = if j < n && (s.[j] = '-' || s.[j] = '+') then (Some s.[j], j + 1) else (None, j) in
            let digits = if k + 1 < n && is_digit s.[k] && is_digit s.[k + 1] && sign = None && s.[k] >= '1' && s.[k] <= '3' then 2 else if k < n && is_digit s.[k] then 1 else 0 in
            let v = if digits = 0 then 0 else int_of_string (String.sub s k digits) in
            flush ();
            (match sign with
             | Some '-' -> t.size <- t.size - v
             | Some _ -> t.size <- t.size + v
             | None -> t.size <- (if v = 0 then 0 else v - 10));
            go (k + digits)
        | 'u' -> flush (); t.shift <- t.shift + 1; go j
        | 'd' -> flush (); t.shift <- t.shift - 1; go j
        (* a motion, a line drawn, a width asked for nothing: passed over *)
        (* a move to the right: on a terminal, that many columns *)
        | 'h' ->
            let by, k = quoted s j in
            (* (on paper: as many spaces, each half an en in Times) *)
            let cols = if t.device = Terminal then int_of_float (ens t (number t 'm' by)) else int_of_float (Float.round (ens t (number t 'm' by) *. 2.)) in
            if cols > 0 then List.iter (fun _ -> Buffer.add_string run "\xc2\xa0") (List.init cols (fun x -> x));
            go k
        | 'v' | 'x' | 'l' | 'L' | 'w' | 'X' | 'b' | 'D' -> let _, k = quoted s j in go k
        | 'o' -> let both, k = quoted s j in List.iter (fun (x : Doc.inline) -> match x with Doc.Text (_, a) -> Buffer.add_string run a | Doc.Break -> ()) (inlines t both); go k
        | 'k' -> go (j + 1)
        | '*' | 'n' -> let _, k = name_at s j in go k
        | '"' -> ()
        | _ -> Buffer.add_char run c; go j in
  go 0; flush (); List.rev !out

(* troff's arithmetic: from left to right, no operator before another *)
and number (t : t) (unit : char) (s : string) : float =
  let n = String.length s in
  let rec term i : float * int =
    if i >= n then (0., i)
    else if s.[i] = '(' then
      let v, j = expr (i + 1) in
      (v, if j < n && s.[j] = ')' then j + 1 else j)
    else if s.[i] = '-' then let v, j = term (i + 1) in (-.v, j)
    else if s.[i] = '+' then term (i + 1)
    else if s.[i] = '\\' && i + 1 < n && s.[i + 1] = 'w' then
      let text, j = quoted s (i + 2) in
      let font = t.font and before = t.before and size = t.size in
      let w = t.measure (inlines t text) in
      t.font <- font; t.before <- before; t.size <- size;
      unit_at (w *. scale t 'n') j 'u'
    else
      let j = ref i in
      while !j < n && (is_digit s.[!j] || s.[!j] = '.') do incr j done;
      let v = match float_of_string_opt (String.sub s i (!j - i)) with Some v -> v | None -> 0. in
      unit_at v !j unit
  and unit_at (v : float) (j : int) (default : char) : float * int =
    if j < n && String.contains "inmvpcPu" s.[j] then (v *. scale t s.[j], j + 1) else (v *. scale t default, j)
  and expr i : float * int =
    let v, j = term i in
    more v j
  and more (v : float) (j : int) : float * int =
    if j >= n then (v, j)
    else
      match s.[j] with
      | '+' -> let w, k = term (j + 1) in more (v +. w) k
      | '-' -> let w, k = term (j + 1) in more (v -. w) k
      (* (a factor has no unit of its own: 2*3n is 6n) *)
      | '*' -> let w, k = term (j + 1) in more (v *. w /. scale t unit) k
      | '/' -> let w, k = term (j + 1) in more (if w = 0. then 0. else v /. (w /. scale t unit)) k
      | '>' -> let w, k = term (j + 1) in more (if v > w then 1. else 0.) k
      | '<' -> let w, k = term (j + 1) in more (if v < w then 1. else 0.) k
      | '=' -> let w, k = term (if j + 1 < n && s.[j + 1] = '=' then j + 2 else j + 1) in more (if v = w then 1. else 0.) k
      | _ -> (v, j) in
  fst (expr 0)

let inlines_in (t : t) (f : Doc.font) (s : string) : Doc.inline list =
  let font = t.font and before = t.before in
  t.font <- f;
  let r = inlines t s in
  t.font <- font; t.before <- before; r

(*****************************************************************************)
(* The lines *)
(*****************************************************************************)

(* \*x and \nx put in the line, and a comment (a backslash and a
 * double quote, to the line's end) taken off *)
let interpolate (t : t) (s : string) : string =
  if not (String.contains s '\\') then s
  else begin
    let n = String.length s and out = Buffer.create (String.length s) in
    let rec go i =
      if i < n then
        if s.[i] <> '\\' || i + 1 >= n then begin Buffer.add_char out s.[i]; go (i + 1) end
        else
          match s.[i + 1] with
          | '"' -> ()
          | '*' ->
              let name, j = name_at s (i + 2) in
              (match Hashtbl.find_opt t.strings name with Some v -> Buffer.add_string out v | None -> ());
              go j
          | 'n' ->
              let name, j = name_at s (i + 2) in
              let v = match Hashtbl.find_opt t.registers name with Some v -> v | None -> 0. in
              Buffer.add_string out (string_of_int (int_of_float v));
              go j
          | c -> Buffer.add_char out '\\'; Buffer.add_char out c; go (i + 2) in
    go 0; Buffer.contents out
  end

let is_blank (c : char) = c = ' ' || c = '\t'

let rec skip_blanks (s : string) (i : int) : int = if i < String.length s && is_blank s.[i] then skip_blanks s (i + 1) else i

(* a request's name and what is after it *)
let split_request (s : string) : string * string =
  let n = String.length s in
  let i = skip_blanks s 1 in
  let j = ref i in
  while !j < n && !j < i + 2 && not (is_blank s.[!j]) do incr j done;
  (* (one tab after the name is the name's end, not the first argument's start) *)
  let k = if !j < n && s.[!j] = '\t' then !j + 1 else !j in
  (String.sub s i (!j - i), String.sub s k (n - k))

(* the arguments: split at the spaces (a tab is a letter here), but
 * not at one after a backslash; an argument that starts with a double
 * quote goes to the next one, "" in it being a quote *)
let arguments (s : string) : string list =
  let n = String.length s in
  let rec spaces i = if i < n && s.[i] = ' ' then spaces (i + 1) else i in
  let rec go i (acc : string list) : string list =
    let i = spaces i in
    if i >= n then List.rev acc
    else if s.[i] = '"' then begin
      let b = Buffer.create 16 in
      let rec inside j =
        if j >= n then j
        else if s.[j] = '"' then if j + 1 < n && s.[j + 1] = '"' then begin Buffer.add_char b '"'; inside (j + 2) end else j + 1
        else begin Buffer.add_char b s.[j]; inside (j + 1) end in
      let j = inside (i + 1) in
      go j (Buffer.contents b :: acc)
    end
    else begin
      (* (a width asked, \w and its text between two quotes, is one
       * piece, spaces and all) *)
      let rec word j =
        if j >= n || s.[j] = ' ' then j
        else if s.[j] = '\\' && j + 2 < n && s.[j + 1] = 'w' then word (snd (quoted s (j + 2)))
        else if s.[j] = '\\' && j + 1 < n then word (j + 2)
        else word (j + 1) in
      let j = word i in
      go j (String.sub s i (j - i) :: acc)
    end in
  go 0 []

(* a macro's line with \$1 ... \$9 put in *)
let with_arguments (args : string list) (s : string) : string =
  let n = String.length s and out = Buffer.create (String.length s) in
  let rec go i =
    if i < n then
      if i + 2 < n && s.[i] = '\\' && s.[i + 1] = '$' && is_digit s.[i + 2] then begin
        (match List.nth_opt args (Char.code s.[i + 2] - Char.code '1') with Some a -> Buffer.add_string out a | None -> ());
        go (i + 3)
      end
      else begin Buffer.add_char out s.[i]; go (i + 1) end in
  go 0; Buffer.contents out

(* \\ is \ in a macro's lines: they are read twice *)
let once (s : string) : string =
  let n = String.length s and out = Buffer.create (String.length s) in
  let rec go i =
    if i < n then
      if i + 1 < n && s.[i] = '\\' && s.[i + 1] = '\\' then begin Buffer.add_char out '\\'; go (i + 2) end
      else begin Buffer.add_char out s.[i]; go (i + 1) end in
  go 0; Buffer.contents out

(* how many \{ a text opens, less the \} it has *)
let braces (s : string) : int =
  let n = String.length s in
  let rec go i (d : int) : int =
    if i + 1 >= n then d
    else if s.[i] = '\\' then go (i + 2) (if s.[i + 1] = '{' then d + 1 else if s.[i + 1] = '}' then d - 1 else d)
    else go (i + 1) d in
  go 0 0

let again (t : t) (s : string) : string = if String.contains s '\\' then interpolate t (once s) else s

let is_control (s : string) : bool = String.length s > 0 && (s.[0] = '.' || s.[0] = '\'')

(* the lines up to the one that is ".." (or .name), taken off the input *)
let until (t : t) (stop : string) : string list =
  let rec go (acc : string list) : string list =
    match t.input with
    | [] -> List.rev acc
    | (_, l) :: rest ->
        t.input <- rest;
        if is_control l && fst (split_request l) = stop then List.rev acc else go (l :: acc) in
  go []

(* a condition: what it says, and the rest of the line *)
let rec condition (t : t) (s : string) : bool * string =
  let n = String.length s in
  let i = skip_blanks s 0 in
  if i >= n then (false, "")
  else
    let rest j = String.sub s j (n - j) in
    match s.[i] with
    | '!' -> let c, r = condition t (rest (i + 1)) in (not c, r)
    | 't' -> (t.device = Typesetter, rest (i + 1))
    | 'n' -> (t.device = Terminal, rest (i + 1))
    | 'o' -> (true, rest (i + 1))
    | 'e' -> (false, rest (i + 1))
    | c when is_digit c || c = '(' || c = '-' || c = '\\' ->
        let j = ref i in
        while !j < n && not (is_blank s.[!j]) do incr j done;
        (number t 'u' (String.sub s i (!j - i)) > 0., rest !j)
    | c ->
        (* 'a'b': the two the same *)
        (match String.index_from_opt s (i + 1) c with
         | None -> (false, "")
         | Some j ->
             (match String.index_from_opt s (j + 1) c with
              | None -> (false, "")
              | Some k -> (String.sub s (i + 1) (j - i - 1) = String.sub s (j + 1) (k - j - 1), rest (k + 1))))

(* a line written with another escape character (.ec), or with none
 * (.eo), as it would be with the backslash *)
let canonical (t : t) (s : string) : string =
  match t.escape with
  | Some '\\' -> s
  | e ->
      let out = Buffer.create (String.length s) in
      String.iter (fun c -> if c = '\\' then Buffer.add_string out "\\\\" else if Some c = e then Buffer.add_char out '\\' else Buffer.add_char out c) s;
      Buffer.contents out

let rec next (t : t) : line option =
  match t.input with
  | [] -> None
  | (at, raw) :: rest ->
      t.input <- rest; t.at <- at; t.whole <- false;
      let raw = canonical t raw in
      if not (is_control raw) then
        (* (a line that only closes a conditional's lines is no text) *)
        if String.trim raw = "\\}" then next t else Some (Text (interpolate t raw))
      else
        let name, _ = split_request raw in
        (* (a macro's lines are kept as they are: read when it is called) *)
        if name = "de" || name = "am" || name = "ig" then begin
          let args = arguments (snd (split_request (interpolate t raw))) in
          let stop = match (name, args) with ("ig", s :: _) | (_, _ :: s :: _) -> s | _ -> "." in
          let body = until t stop in
          (match (name, args) with
           | "de", m :: _ -> Hashtbl.replace t.macros m (List.map once body)
           | "am", _ -> unknown t ".am"
           | _ -> ());
          next t
        end
        else
          let line = interpolate t raw in
          let name, after = split_request line in
          let args () = arguments after in
          match name with
          | "" | "''" | "\\}" -> next t
          | "ds" | "as" ->
              let i = skip_blanks after 0 in
              let j = ref i in
              while !j < String.length after && not (is_blank after.[!j]) do incr j done;
              let k = skip_blanks after !j in
              let k = if k < String.length after && after.[k] = '"' then k + 1 else k in
              let v = String.sub after k (String.length after - k) and x = String.sub after i (!j - i) in
              (* (a string is read as a macro's lines are: \\ is \) *)
              let v = once v in
              Hashtbl.replace t.strings x (if name = "as" then (match Hashtbl.find_opt t.strings x with Some old -> old ^ v | None -> v) else v);
              next t
          | "nr" ->
              (match args () with
               | x :: v :: _ ->
                   let old = match Hashtbl.find_opt t.registers x with Some o -> o | None -> 0. in
                   let relative = String.length v > 0 && (v.[0] = '+' || v.[0] = '-') in
                   let v = number t 'u' v in
                   Hashtbl.replace t.registers x (if relative then old +. v else v)
               | _ -> ());
              next t
          | "so" ->
              (* another file's lines, here *)
              (match (match args () with name :: _ -> t.loader name | [] -> None) with
               | Some text ->
                   let lines = String.split_on_char '\n' (String.concat "" (String.split_on_char '\r' text)) in
                   let lines = match List.rev lines with "" :: rest -> List.rev rest | _ -> lines in
                   t.input <- List.map (fun l -> (at, l)) lines @ t.input
               | None -> unknown t ".so");
              next t
          | "ec" -> t.escape <- Some (match args () with a :: _ when a <> "" -> a.[0] | _ -> '\\'); next t
          | "eo" -> t.escape <- None; next t
          | "hc" -> t.hyphen <- (match args () with a :: _ when a <> "" -> Some a.[0] | _ -> None); next t
          | "tr" ->
              let chars = fst (Utf8.chars (String.trim after)) in
              let rec pairs (l : string list) = match l with a :: b :: rest -> (a, b) :: pairs rest | [ a ] -> [ (a, " ") ] | [] -> [] in
              t.translate <- pairs chars @ t.translate; next t
          | "rm" -> List.iter (fun m -> Hashtbl.remove t.macros m; Hashtbl.remove t.strings m) (args ()); next t
          | "if" | "ie" | "el" ->
              let yes, body = if name = "el" then (not t.taken, after) else condition t after in
              if name = "ie" then t.taken <- yes;
              let body = let i = skip_blanks body 0 in String.sub body i (String.length body - i) in
              if yes then begin
                let body = if String.starts_with ~prefix:"\\{" body then String.sub body 2 (String.length body - 2) else body in
                if String.trim body <> "" then t.input <- (at, body) :: t.input
              end
              else begin
                (* the lines to the \} that closes this one's \{ *)
                let rec skip (d : int) = if d > 0 then match t.input with [] -> () | (_, l) :: rest -> t.input <- rest; skip (d + braces l) in
                skip (braces body)
              end;
              next t
          | _ ->
              (match Hashtbl.find_opt t.macros name with
               | Some body ->
                   let args = args () in
                   t.input <- List.map (fun l -> (at, with_arguments args l)) body @ t.input;
                   next t
               | None -> Some (Request (name, args ())))
