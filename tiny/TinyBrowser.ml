(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyBrowser.mli *)
open TinyCalls
open TinyLibDraw

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
  let n = String.length classes and m = String.length w in
  let rec go i =
    let j = find classes w i in
    if j < 0 then false
    else if (j = 0 || classes.[j - 1] = ' ') && (j + m = n || classes.[j + m] = ' ') then true
    else go (j + 1) in
  m > 0 && go 0

let number s =
  let n = String.length s in
  let rec go i acc = if i < n && s.[i] >= '0' && s.[i] <= '9' then go (i + 1) (acc * 10 + Char.code s.[i] - 48) else acc in
  go 0 0

(*****************************************************************************)
(* Characters *)
(*****************************************************************************)

(* The Latin-1 letters from 0xc0 on, each without its accent; and
 * Latin Extended-A's, from 0x100 to 0x17f (the names of Central Europe:
 * c with a caron, l with a stroke, o with a double acute), the same way
 * (made from Unicode's decompositions). *)
let latin1 = "AAAAAAACEEEEIIIIDNOOOOOxOUUUUYPsaaaaaaaceeeeiiiidnooooo/ouuuuypy"
let latin_a = "AaAaAaCcCcCcCcDdDdEeEeEeEeEeGgGgGgGgHhHhIiIiIiIiIiIiJjKkkLlLlLlLlLlNnNnNnnNnOoOoOoOoRrRrRrSsSsSsSsTtTtTtUuUuUuUuUuUuWwYyYZzZzZzs"

(* Converts a Unicode code point to what the 128-character font can show. *)
let of_code u =
  if u < 128 then (if u = 9 || u = 10 then " " else if u < 32 then "" else String.make 1 (Char.chr u))
  else if u >= 0xc0 && u <= 0xff then String.make 1 latin1.[u - 0xc0]
  else if u = 0x152 then "OE" else if u = 0x153 then "oe"
  else if u >= 0x100 && u < 0x180 then String.make 1 latin_a.[u - 0x100]
  else match u with
  | 0x20ac -> "EUR" | 0xa3 -> "GBP" | 0xa5 -> "JPY" | 0xa7 -> "S." | 0xb2 -> "2" | 0xb3 -> "3" | 0xb9 -> "1" | 0xbc -> "1/4" | 0xbe -> "3/4"
  | 0xa0 | 0x2002 | 0x2003 | 0x2009 | 0x202f -> " "
  | 0xad | 0x200b | 0x200c | 0x200d | 0x200e | 0x200f | 0x2060 | 0xfeff -> ""
  | 0xa9 -> "(c)" | 0xae -> "(R)" | 0xb0 -> "o" | 0xb1 -> "+-" | 0xb7 | 0x2219 | 0x22c5 -> "."
  | 0xab -> "<<" | 0xbb -> ">>" | 0xbd -> "1/2" | 0xd7 -> "x" | 0xf7 -> "/"
  | 0x2010 | 0x2011 | 0x2012 | 0x2013 | 0x2014 | 0x2015 | 0x2212 -> "-"
  | 0x2018 | 0x2019 | 0x201a | 0x2032 | 0x2bc -> "'"
  | 0x201c | 0x201d | 0x201e | 0x2033 -> "\""
  | 0x2022 | 0x25cf -> "*" | 0x2026 -> "..." | 0x2192 -> "->" | 0x2190 -> "<-" | 0x2191 -> "^" | 0x21d2 -> "=>"
  | 0x2264 -> "<=" | 0x2265 -> ">=" | 0x2260 -> "/=" | 0x2248 -> "~" | 0x221e -> "inf"
  | 0x3bb -> "lambda" | 0x3b1 -> "alpha" | 0x3b2 -> "beta" | 0x3b3 -> "gamma" | 0x3b4 -> "delta" | 0x3b5 -> "epsilon"
  | 0x3b8 -> "theta" | 0x3bc -> "mu" | 0x3c0 -> "pi" | 0x3c3 -> "sigma" | 0x3c6 | 0x3d5 -> "phi" | 0x3c9 -> "omega"
  | 0x394 -> "Delta" | 0x3a3 -> "Sigma" | 0x3a9 -> "Omega"
  | 0x21a6 -> "|->" | 0x2208 -> "in" | 0x2295 -> "(+)" | 0x2021 -> "++" | 0x200a | 0x2061 -> "" 
  | _ -> "?"

let entity name =
  match name with
  | "amp" -> 38 | "lt" -> 60 | "gt" -> 62 | "quot" -> 34 | "apos" -> 39 | "nbsp" -> 0xa0
  | "ndash" -> 0x2013 | "mdash" -> 0x2014 | "minus" -> 0x2212 | "hellip" -> 0x2026
  | "lsquo" -> 0x2018 | "rsquo" -> 0x2019 | "ldquo" -> 0x201c | "rdquo" -> 0x201d
  | "middot" -> 0xb7 | "bull" -> 0x2022 | "times" -> 0xd7 | "copy" -> 0xa9 | "shy" -> 0xad
  | "rarr" -> 0x2192 | "larr" -> 0x2190 | "laquo" -> 0xab | "raquo" -> 0xbb | "deg" -> 0xb0
  | "eacute" -> 0xe9 | "egrave" -> 0xe8 | "aacute" -> 0xe1 | "ouml" -> 0xf6 | "uuml" -> 0xfc
  | _ -> -1

(* Returns the code point of an entity, given the text between its &
 * and its ; (like "amp" or "#8211"), or -1 if it is unknown. *)
let entity_code s =
  let n = String.length s in
  if n > 1 && s.[0] = '#' then begin
    if s.[1] = 'x' || s.[1] = 'X' then begin
      let rec hex i acc =
        if i >= n then acc
        else
          let c = s.[i] in
          let d = if c >= '0' && c <= '9' then Char.code c - 48 else if c >= 'a' && c <= 'f' then Char.code c - 87 else if c >= 'A' && c <= 'F' then Char.code c - 55 else -1 in
          if d < 0 then -1 else hex (i + 1) (acc * 16 + d) in
      hex 2 0
    end
    else number (String.sub s 1 (n - 1))
  end
  else entity s

(* How many bytes a UTF-8 character has, given its first byte. *)
let utf8_length b = if b < 0x80 then 1 else if b < 0xc0 then 1 else if b < 0xe0 then 2 else if b < 0xf0 then 3 else 4

let ascii s =
  let n = String.length s in
  if not (String.exists (fun c -> c = '&' || Char.code c >= 128) s) then s
  else begin
    (* The result is built as a list of pieces: stretches of plain
     * ASCII copied as they are, and a replacement for each entity or
     * non-ASCII character. *)
    let pieces = ref [] and plain = ref 0 in
    let cut i = if i > !plain then pieces := String.sub s !plain (i - !plain) :: !pieces in
    let i = ref 0 in
    while !i < n do
      let c = s.[!i] in
      if c = '&' then begin
        let j = ref (!i + 1) in
        while !j < n && !j - !i < 12 && s.[!j] <> ';' && not (is_space s.[!j]) && s.[!j] <> '&' do incr j done;
        let u = if !j < n && s.[!j] = ';' then entity_code (String.sub s (!i + 1) (!j - !i - 1)) else -1 in
        if u >= 0 then begin cut !i; pieces := of_code u :: !pieces; i := !j + 1; plain := !i end
        else incr i
      end
      else if Char.code c >= 128 then begin
        let b = Char.code c in
        let len = utf8_length b in
        let rec follows k = k >= len || (Char.code s.[!i + k] land 0xc0 = 0x80 && follows (k + 1)) in
        let u =
          if len = 1 || !i + len > n || not (follows 1) then -1
          else if len = 2 then ((b land 0x1f) lsl 6) lor (Char.code s.[!i + 1] land 0x3f)
          else if len = 3 then ((b land 0x0f) lsl 12) lor ((Char.code s.[!i + 1] land 0x3f) lsl 6) lor (Char.code s.[!i + 2] land 0x3f)
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
  let rec amp j = if j < i || j < n - 12 then n else if s.[j] = '&' then j else if s.[j] = ';' || is_space s.[j] then n else amp (j - 1) in
  let a = amp (n - 1) in
  let rec lead j = if j > i && j > n - 4 && Char.code s.[j] land 0xc0 = 0x80 then lead (j - 1) else j in
  let l = if n > i && Char.code s.[n - 1] >= 0x80 then lead (n - 1) else n in
  let l = if l < n && l + utf8_length (Char.code s.[l]) > n then l else n in
  (* Back up to just after the last space. *)
  let rec space j = if j <= i then i else if is_space s.[j - 1] then j else space (j - 1) in
  space (min a l)

(*****************************************************************************)
(* Tokens *)
(*****************************************************************************)

type token = Text of string | Open of string * (string * string) list | Close of string

(* The attributes the browser uses. The others (like Parsoid's large
 * data-mw, or ids) are skipped without being copied. *)
let wanted = [ "href"; "class"; "style"; "src"; "alt"; "width"; "height"; "colspan"; "start"; "id" ]

(* Parses the inside of a tag, the text between its < and its >. *)
let tag s =
  let n = String.length s in
  let rec word i = if i < n && not (is_space s.[i]) && s.[i] <> '/' && s.[i] <> '=' && s.[i] <> '>' then word (i + 1) else i in
  let rec skip i = if i < n && (is_space s.[i] || s.[i] = '/') then skip (i + 1) else i in
  if n > 0 && s.[0] = '/' then let e = word 1 in Close (String.lowercase_ascii (String.sub s 1 (e - 1)))
  else begin
    let e = word 0 in
    let name = String.lowercase_ascii (String.sub s 0 e) in
    let rec attrs i acc =
      let i = skip i in
      if i >= n then List.rev acc
      else begin
        let e = word i in
        let a = String.lowercase_ascii (String.sub s i (e - i)) in
        let rec sp j = if j < n && is_space s.[j] then sp (j + 1) else j in
        let j = sp e in
        if j < n && s.[j] = '=' then begin
          let j = sp (j + 1) in
          let q = if j < n then s.[j] else ' ' in
          let v0, v1, next =
            if q = '"' || q = '\'' then
              (match String.index_from_opt s (j + 1) q with Some k -> j + 1, k, k + 1 | None -> j + 1, n, n)
            else let rec un k = if k < n && not (is_space s.[k]) then un (k + 1) else k in let k = un j in j, k, k in
          if List.mem a wanted then attrs next ((a, ascii (String.sub s v0 (v1 - v0))) :: acc) else attrs next acc
        end
        else attrs (if e = i then i + 1 else e) (if List.mem a wanted then (a, "") :: acc else acc)
      end in
    Open (name, attrs e [])
  end

(* The reader keeps what the last message left unfinished (tail), and,
 * while we skip the content of a <style> or <script>, which is not
 * HTML, the name of that element (raw). *)
type reader = { mutable tail : string; mutable raw : string }

(* Finds the > that ends a tag, starting just after its <. A > inside
 * quotes does not count. Returns -1 if the tag is not complete yet. *)
let tag_end s i =
  let n = String.length s in
  let rec go j q =
    if j >= n then -1
    else
      let c = s.[j] in
      if q <> ' ' then go (j + 1) (if c = q then ' ' else q)
      else if c = '>' then j
      else if c = '"' || c = '\'' then go (j + 1) c
      else go (j + 1) ' ' in
  go i ' '

(* Returns the tokens of a message. [last] is true when no message
 * follows, so nothing is kept for later. *)
let tokens (r : reader) chunk last =
  let s = if r.tail = "" then chunk else r.tail ^ chunk in
  let n = String.length s in
  r.tail <- "";
  let keep i = if not last then r.tail <- String.sub s i (n - i) in
  let rec go i acc =
    if i >= n then acc
    else if r.raw <> "" then begin
      let j = find s ("</" ^ r.raw) i in
      if j < 0 then begin keep (max i (n - 10)); acc end
      else (match String.index_from_opt s j '>' with
        | Some k -> let name = r.raw in r.raw <- ""; go (k + 1) (Close name :: acc)
        | None -> keep j; acc)
    end
    else if s.[i] = '<' then begin
      if i + 3 < n && s.[i + 1] = '!' && s.[i + 2] = '-' && s.[i + 3] = '-' then begin
        let j = find s "-->" (i + 4) in
        if j < 0 then begin keep i; acc end else go (j + 3) acc
      end
      else begin
        let k = tag_end s (i + 1) in
        if k < 0 then begin keep i; acc end
        else if i + 1 < n && (s.[i + 1] = '!' || s.[i + 1] = '?') then go (k + 1) acc
        else begin
          let t = tag (String.sub s (i + 1) (k - i - 1)) in
          (match t with Open (name, _) when name = "style" || name = "script" -> r.raw <- name | _ -> ());
          go (k + 1) (t :: acc)
        end
      end
    end
    else begin
      let j = match String.index_from_opt s i '<' with Some j -> j | None -> n in
      let e = if j = n && not last then safe_end s i n else j in
      if e < j then keep e;
      let acc = if e > i then Text (ascii (String.sub s i (e - i))) :: acc else acc in
      if e < j then acc else go j acc
    end in
  List.rev (go 0 [])

(*****************************************************************************)
(* Lines *)
(*****************************************************************************)

let bold = 1
let emph = 2
let code = 4
let big = 8
let under = 16

type run = { col : int; text : string; look : int; link : string; pic : int }
type line = { runs : run list; rule : bool }

(* A flow wraps words into lines of a given width, starting at a left
 * margin. *)
type flow = {
  width : int;
  mutable left : int;
  mutable made : run list;  (* the line being built, last run first *)
  mutable at : int;         (* the column where the next word goes *)
  mutable out : line list;  (* the finished lines, last line first *)
  mutable nlines : int;     (* how many lines are in out *)
  mutable blank : bool;     (* whether the next line wants a blank line before it *)
  mutable glue : int;       (* the column where the word being made started *)
  mutable cache : line array;  (* the lines from the top, when there were [cached] *)
  mutable cached : int;
}

let flow width = { width = width; left = 0; made = []; at = 0; out = []; nlines = 0; blank = false; glue = 0; cache = Array.make 0 { runs = []; rule = false }; cached = 0 }

let push (f : flow) (l : line) =
  if f.blank then begin
    (match f.out with x :: _ when x.runs <> [] || x.rule -> f.out <- { runs = []; rule = false } :: f.out; f.nlines <- f.nlines + 1 | _ -> ());
    f.blank <- false
  end;
  f.out <- l :: f.out;
  f.nlines <- f.nlines + 1

let end_line (f : flow) = if f.made <> [] then begin push f { runs = List.rev f.made; rule = false }; f.made <- [] end

(* Adds a word to the flow, after a space if [space] is true. When the
 * word has the same look and link as the previous run, it extends that
 * run instead of starting a new one. *)
(* Moves the word being made, from the column where it started, to a
 * new line, and ends the line before it. A word can be made of several
 * pieces with no space between them (a full stop and a reference's
 * [15], a link and the comma after it), so it is only known to be too
 * long for its line when its last piece comes. *)
let carry (f : flow) =
  let g = f.glue in
  let keep = ref [] and move = ref [] in
  List.iter (fun (r : run) ->
    let n = String.length r.text in
    if r.col + n <= g then keep := r :: !keep
    else if r.col >= g then move := r :: !move
    else begin
      keep := { col = r.col; text = String.sub r.text 0 (g - r.col); look = r.look; link = r.link; pic = r.pic } :: !keep;
      move := { col = g; text = String.sub r.text (g - r.col) (n - g + r.col); look = r.look; link = r.link; pic = r.pic } :: !move
    end) (List.rev f.made);
  (* the line kept without the spaces at its end *)
  let rec strip s = let n = String.length s in if n > 0 && s.[n - 1] = ' ' then strip (String.sub s 0 (n - 1)) else s in
  f.made <- (match !keep with
    | r :: rest -> let t = strip r.text in if t = "" then rest else { col = r.col; text = t; look = r.look; link = r.link; pic = r.pic } :: rest
    | [] -> []);
  end_line f;
  let shift = g - f.left in
  f.made <- List.map (fun (r : run) -> { col = r.col - shift; text = r.text; look = r.look; link = r.link; pic = r.pic }) !move;
  f.at <- f.at - shift;
  f.glue <- f.left

let word (f : flow) text look link space =
  let len = String.length text in
  if f.made = [] then f.at <- f.left;
  let space = space && f.made <> [] in
  let space = if space && f.at + 1 + len > f.width then (end_line f; f.at <- f.left; false) else space in
  if (not space) && f.made <> [] && f.at + len > f.width && f.glue > f.left then carry f;
  let col = if space then f.at + 1 else f.at in
  if space || f.made = [] then f.glue <- col;
  (match f.made with
   | r :: rest when r.look = look && r.link = link && r.col + String.length r.text = f.at ->
       f.made <- { col = r.col; text = r.text ^ (if space then " " else "") ^ text; look = look; link = link; pic = -1 } :: rest
   | _ ->
       (* The space between two different runs belongs to neither, so a
        * link's underline stops where its text stops. *)
       f.made <- { col = col; text = text; look = look; link = link; pic = -1 } :: f.made);
  f.at <- col + len

(* A picture of [rows] rows of the screen: a line for
 * each row, whose one run is the picture's slice there (its number
 * times 256, plus the row), at the left margin. The text goes on under
 * it. *)
let picture_block (f : flow) id rows link =
  end_line f;
  for s = 0 to rows - 1 do
    push f { runs = [ { col = f.left; text = ""; look = 0; link = link; pic = (id * 256) + s } ]; rule = false }
  done

(* Adds a text exactly as it is, with no wrapping (for <pre>). *)
let verbatim (f : flow) text look link =
  if f.made = [] then f.at <- f.left;
  if text <> "" then begin
    f.made <- { col = f.at; text = text; look = look; link = link; pic = -1 } :: f.made;
    f.at <- f.at + String.length text
  end

(*****************************************************************************)
(* Tables *)
(*****************************************************************************)

(* The words of a cell are kept until the end of the table, when the
 * widths of its columns are known. *)
type item = Word of string * int * string * bool | Break | Pic of int * int * int * string

type cell = { mutable items : item list; span : int; head : bool }
type table = {
  mutable rows : cell list list;  (* the rows so far, last row first *)
  mutable row : cell list;
  mutable cell : cell option;
  mutable depth : int;            (* how many tables are open inside it; their
                                   * cells just become text of the current cell *)
}

let cell_words (c : cell) = List.rev c.items

(* Returns the narrowest a cell can be (its longest word) and the widest
 * it would like to be (its text with no wrapping, except at its own
 * line breaks). *)
let measure (c : cell) =
  let narrow = ref 0 and wide = ref 0 and line = ref 0 in
  List.iter (function
    | Word (t, _, _, sp) ->
        let len = String.length t in
        narrow := max !narrow len;
        line := !line + len + (if sp && !line > 0 then 1 else 0);
        wide := max !wide !line
    | Pic (_, cols, _, _) -> narrow := max !narrow cols; wide := max !wide cols; line := 0
    | Break -> line := 0) (cell_words c);
  !narrow, !wide

(* Computes the widths of n columns that must fit in [room]. If every
 * column fits at its widest, it gets that. Otherwise each column gets
 * its narrowest width, plus a share of the remaining room proportional
 * to how much wider it would like to be. *)
let widths rows n room =
  let narrow = Array.make n 0 and wide = Array.make n 0 in
  List.iter (fun row ->
    ignore (List.fold_left (fun k (c : cell) ->
      if k < n && c.span = 1 then begin
        let a, b = measure c in
        narrow.(k) <- max narrow.(k) a;
        wide.(k) <- max wide.(k) b
      end;
      k + c.span) 0 row)) rows;
  let sn = ref 0 and sw = ref 0 in
  for k = 0 to n - 1 do sn := !sn + narrow.(k); sw := !sw + wide.(k) done;
  if !sw <= room then wide
  else if !sn >= room then narrow
  else begin
    let w = Array.make n 0 in
    for k = 0 to n - 1 do w.(k) <- narrow.(k) + ((wide.(k) - narrow.(k)) * (room - !sn) / (!sw - !sn)) done;
    w
  end

let gap = 2

(* Lays out a finished table into the flow: each cell is wrapped in its
 * column, and the cells of a row are put side by side. *)
let lay_table (f : flow) (t : table) =
  let rows = List.rev (List.map List.rev t.rows) in
  let rows = List.filter (fun r -> r <> []) rows in
  (* A caption spans all the columns, but counts as one here. *)
  let n = List.fold_left (fun m r -> max m (List.fold_left (fun s (c : cell) -> s + (if c.span >= 1000 then 1 else c.span)) 0 r)) 0 rows in
  if n > 0 then begin
    let room = f.width - f.left - (gap * (n - 1)) in
    let w = widths rows n room in
    (* A cell spanning several columns gets their widths plus the gaps
     * between them. *)
    let span_width k span = let s = ref 0 in for j = k to min n (k + span) - 1 do s := !s + w.(j) + gap done; !s - gap in
    let x = Array.make (n + 1) f.left in
    for k = 1 to n do x.(k) <- x.(k - 1) + w.(k - 1) + gap done;
    end_line f;
    f.blank <- true;
    List.iter (fun row ->
      let k = ref 0 in
      let laid = List.map (fun (c : cell) ->
        let cw = if !k < n then max 1 (span_width !k c.span) else 1 in
        let g = flow cw in
        List.iter (function
          | Word (text, look, link, sp) -> word g text (if c.head then look lor bold else look) link sp
          | Pic (id, _, rows, link) -> picture_block g id rows link
          | Break -> end_line g) (cell_words c);
        end_line g;
        let at = if !k < n then x.(!k) else x.(n) in
        k := !k + c.span;
        at, List.rev g.out) row in
      let height = List.fold_left (fun h (_, ls) -> max h (List.length ls)) 0 laid in
      for i = 0 to height - 1 do
        let runs = List.concat (List.map (fun (at, ls) ->
          match List.nth_opt ls i with
          | Some (l : line) -> List.map (fun (r : run) -> { col = r.col + at; text = r.text; look = r.look; link = r.link; pic = r.pic }) l.runs
          | None -> []) laid) in
        push f { runs = runs; rule = false }
      done) rows;
    f.blank <- true
  end

(*****************************************************************************)
(* The tags *)
(*****************************************************************************)

(* A picture of the page: where it is, the size it is shown at in
 * pixels, its alternative text, and how far it has come: -1 not asked
 * yet, -3 asked, -2 not to be had, or the rows of it received. *)
type picture = { pc_src : string; pc_w : int; pc_h : int; pc_alt : string; mutable pc_got : int }

(* An open element. Besides its tag, it records how its text should be
 * shown, combining what it says with what its parents say, so the top
 * of the stack alone tells how to show the next text. *)
type elem = {
  tag : string;
  face : int;                 (* the look of its text: bold, emph, code *)
  href : string;
  hide : bool;
  pre : bool;
  margin : int;               (* the column where its lines start *)
  mutable count : int;        (* the next number, for an <ol> *)
}

type page = {
  reader : reader;
  page_flow : flow;
  mutable stack : elem list;
  mutable tables : table list;  (* the open table, if any (at most one: see depth) *)
  mutable space : bool;         (* whether a space was read since the last word *)
  mutable page_title : string;
  mutable page_base : string;
  mutable anchors : (string * int) list;  (* an element's id, and the line it starts at *)
  mutable pictures : picture list;        (* the page's pictures, the last first *)
  mutable npictures : int;
  mutable heading : (string * int * string * bool) list;  (* a large heading's words, the last first *)
}

let root = { tag = ""; face = 0; href = ""; hide = false; pre = false; margin = 0; count = 0 }

(* (the reader and the flow made first: tiny-ml computes a record's
 * fields in tiny-machine's 11 registers) *)
let create width =
  let reader = { tail = ""; raw = "" } and page_flow = flow width in
  { reader = reader; page_flow = page_flow; stack = [ root ]; tables = []; space = false; page_title = ""; page_base = ""; anchors = []; pictures = []; npictures = 0; heading = [] }

let top p = match p.stack with e :: _ -> e | [] -> root

(* The table of tags. Each tag has some of these bits:
 *  - void: the element has no end tag (like <br>);
 *  - block: it ends the current line before and after it;
 *  - spaced: it also wants a blank line before and after it;
 *  - hidden: its text is not shown;
 *  - deeper: it indents its lines.
 * The look of its text (bold, emph, code, big, under) is in the bits
 * above those, multiplied by 32. *)
let void = 1
let block = 2
let spaced = 4
let hidden = 8
let deeper = 16
let kinds = [
  "a", 0; "address", block; "area", void; "article", block; "aside", block;
  "b", bold * 32; "base", void; "blockquote", block + spaced + deeper; "body", block; "br", void; "button", hidden;
  "caption", block; "center", block; "code", code * 32; "col", void;
  "dd", block + deeper; "dfn", emph * 32; "div", block; "dl", block + spaced; "dt", block + bold * 32;
  "em", emph * 32; "embed", void;
  "figcaption", block; "figure", block + spaced; "footer", block;
  "h1", block + spaced + (bold + big) * 32; "h2", block + spaced + (bold + big) * 32; "h3", block + spaced + bold * 32;
  "h4", block + spaced + bold * 32; "h5", block + spaced + bold * 32; "h6", block + spaced + bold * 32;
  "head", hidden; "header", block; "hr", void; "html", block;
  "i", emph * 32; "img", void; "input", void + hidden; "ins", under * 32;
  "kbd", code * 32; "li", block; "link", void; "main", block; "math", hidden; "meta", void; "nav", block; "noscript", hidden;
  "ol", block + deeper; "p", block + spaced; "param", void; "pre", block + spaced + code * 32;
  "samp", code * 32; "script", hidden; "section", block; "select", hidden; "source", void; "strong", bold * 32;
  "style", hidden; "svg", hidden;
  "table", block; "td", block; "template", hidden; "textarea", hidden; "th", block + bold * 32; "title", hidden;
  "tr", block; "tt", code * 32; "u", under * 32; "ul", block + deeper; "var", emph * 32; "wbr", void ]

(* A tag is looked up only among the tags with the same first letter,
 * because in tiny-ml comparing two strings is a call to the runtime. *)
let by_letter =
  let a = Array.make 26 [] in
  List.iter (fun (name, k) -> let i = Char.code name.[0] - 97 in a.(i) <- (name, k) :: a.(i)) kinds;
  a
let kind tag =
  let i = if tag = "" then -1 else Char.code tag.[0] - 97 in
  if i < 0 || i >= 26 then 0 else match List.assoc_opt tag by_letter.(i) with Some k -> k | None -> 0
let is k bit = k land bit <> 0
(* The classes Wikipedia uses for parts that are not worth showing on a
 * small screen (navigation boxes, edit links, ...). *)
let hidden_classes = [ "navbox"; "noprint"; "metadata"; "mw-editsection"; "mw-empty-elt"; "sistersitebox"; "mw-jump-link" ]

let attr attrs a = match List.assoc_opt a attrs with Some v -> v | None -> ""

let hides k attrs =
  is k hidden
  || (let cl = attr attrs "class" in cl <> "" && List.exists (has_class cl) hidden_classes)
  || (let st = attr attrs "style" in find st "display:none" 0 >= 0 || find st "display: none" 0 >= 0)

(* Sends a word to the current cell if a table is open (large text is
 * not, there), to the large heading being made, or to the page's flow. *)
let emit p text =
  let e = top p in
  if not e.hide then begin
    (match p.tables with
     | t :: _ -> (match t.cell with Some c -> c.items <- Word (text, e.face land lnot big, e.href, p.space) :: c.items | None -> ())
     | [] -> if e.face land big <> 0 then p.heading <- (text, e.face, e.href, p.space) :: p.heading else word p.page_flow text e.face e.href p.space);
    p.space <- false
  end

(* Ends the current line. *)
let break p =
  (match p.tables with
   | t :: _ -> (match t.cell with Some c -> (match c.items with Break :: _ | [] -> () | _ -> c.items <- Break :: c.items) | None -> ())
   | [] -> end_line p.page_flow);
  p.space <- false

let paragraph p = break p; if p.tables = [] then p.page_flow.blank <- true

let text p s =
  let e = top p in
  if e.tag = "title" then p.page_title <- p.page_title ^ s
  else if e.hide then ()
  else if e.pre && p.tables = [] then begin
    let f = p.page_flow in
    let pieces = String.split_on_char '\n' s in
    List.iteri (fun i piece ->
      if i > 0 then (if f.made = [] then push f { runs = []; rule = false } else end_line f);
      verbatim f piece e.face e.href) pieces
  end
  else begin
    let n = String.length s in
    let i = ref 0 in
    while !i < n do
      if is_space s.[!i] then begin p.space <- true; incr i end
      else begin
        let j = ref !i in
        while !j < n && not (is_space s.[!j]) do incr j done;
        emit p (String.sub s !i (!j - !i));
        i := !j
      end
    done
  end

let rule p = if p.tables = [] then begin end_line p.page_flow; push p.page_flow { runs = []; rule = true } end

(* A large heading (<h1>, <h2>): its words laid out at half the width,
 * each of its lines two of the page's, its top half and its bottom half
 * (the same runs, their pic -2), so that the page is still rows of 16
 * pixels, each drawn on its own. *)
let lay_heading p =
  let f = p.page_flow in
  let g = flow (max 1 ((f.width - f.left) / 2)) in
  List.iter (fun (text, look, link, sp) -> word g text look link sp) (List.rev p.heading);
  end_line g;
  p.heading <- [];
  end_line f;
  List.iter (fun (l : line) ->
    let runs = List.map (fun (r : run) -> { col = f.left + (2 * r.col); text = r.text; look = r.look; link = r.link; pic = -1 }) l.runs in
    push f { runs = runs; rule = false };
    push f { runs = List.map (fun (r : run) -> { col = r.col; text = r.text; look = r.look; link = r.link; pic = -2 }) runs; rule = false })
    (List.rev g.out)

(* The pixels the pictures of a page may have in all: they are images of
 * the kernel's, which has 2 MB for them, the windows' included. *)
let picture_room = 1048576

(* A picture: a box of the size the page says (its width and height
 * attributes), smaller if it is wider than the room it has, kept in the
 * page's pictures and drawn when its pixels come. The text never moves
 * when they do: its place is known before the picture is. Small icons
 * (under 24 pixels) are left out. Wikipedia shows math as a picture
 * whose alternative text is the TeX source, which we show instead. *)
let picture p attrs =
  let alt = attr attrs "alt" and cl = attr attrs "class" and src = attr attrs "src" in
  let w = number (attr attrs "width") and h = number (attr attrs "height") in
  if has_class cl "mwe-math-fallback-image-inline" || has_class cl "mwe-math-fallback-image-display" then begin
    let pre = "{\\displaystyle " in
    let n = String.length alt and m = String.length pre in
    (* (as text, so that a long formula wraps at its spaces) *)
    text p (if n > m + 1 && String.sub alt 0 m = pre then String.sub alt m (n - m - 1) else alt)
  end
  else if (w >= 24 || h >= 24) && w > 0 && h > 0 && src <> "" then begin
    let f = p.page_flow in
    let room = 8 * (if p.tables = [] then f.width - f.left else f.width / 2) in
    let w, h = if w > room then room, max 1 (h * room / w) else w, h in
    let used = List.fold_left (fun n (pc : picture) -> n + (pc.pc_w * pc.pc_h)) 0 p.pictures in
    if used + (w * h) > picture_room then emit p ("[" ^ (if alt = "" then "picture" else alt) ^ "]")
    else begin
      let id = p.npictures in
      p.pictures <- { pc_src = src; pc_w = w; pc_h = h; pc_alt = alt; pc_got = -1 } :: p.pictures;
      p.npictures <- id + 1;
      let cols = (w + 7) / 8 and rows = (h + 15) / 16 and link = (top p).href in
      match p.tables with
      | t :: _ -> (match t.cell with Some c -> c.items <- Pic (id, cols, rows, link) :: Break :: c.items | None -> ())
      | [] -> picture_block f id rows link
    end
  end

(* Some elements close implicitly when another one opens: a paragraph
 * when any block starts, a list item when the next one starts, a cell
 * when the next one starts. *)
let implied p tag k =
  let close_to names stop =
    let rec find = function
      | [] -> false
      | (e : elem) :: rest -> if List.mem e.tag names then true else if List.mem e.tag stop then false else find rest in
    if find p.stack then begin
      let rec pop = function (e : elem) :: rest when not (List.mem e.tag names) -> pop rest | _ :: rest -> rest | [] -> [] in
      p.stack <- pop p.stack
    end in
  if is k block then begin
    (match tag with
     | "li" -> close_to [ "li" ] [ "ul"; "ol" ]
     | "dt" | "dd" -> close_to [ "dt"; "dd" ] [ "dl" ]
     | "tr" -> close_to [ "tr" ] [ "table" ]
     | "td" | "th" -> close_to [ "td"; "th" ] [ "tr"; "table" ]
     | _ -> ());
    if (top p).tag = "p" then p.stack <- (match p.stack with _ :: rest -> rest | [] -> [])
  end

let open_tag p tag k attrs =
  implied p tag k;
  let e = top p in
  let hide = e.hide || hides k attrs in
  (* An element with an id is a place a link can go to (#History,
   * #cite_note-2): the line it starts at is kept. Parsoid gives nearly
   * every element an id of its own, which starts with mw, and no link
   * names those. *)
  let id = attr attrs "id" in
  if id <> "" && not hide && not (String.length id > 1 && id.[0] = 'm' && id.[1] = 'w') then
    p.anchors <- (id, p.page_flow.nlines + (if p.page_flow.made <> [] || p.page_flow.blank then 1 else 0)) :: p.anchors;
  (* Inside a table, a <tr> starts a new row and a <td> or <th> a new
   * cell, whose words are kept until the end of the table. *)
  if is k block then
    (match p.tables, tag with
     | [], "table" when not hide -> end_line p.page_flow; p.tables <- [ { rows = []; row = []; cell = None; depth = 0 } ]
     | t :: _, "table" when not hide -> t.depth <- t.depth + 1; break p
     | t :: _, "tr" when t.depth = 0 && not hide ->
         if t.row <> [] then t.rows <- t.row :: t.rows;
         t.row <- []; t.cell <- None
     | t :: _, ("td" | "th" | "caption") when t.depth = 0 && not hide ->
         let span = if tag = "caption" then 1000 else max 1 (number (attr attrs "colspan")) in
         let c = { items = []; span = span; head = tag = "th" || tag = "caption" } in
         if tag = "caption" then begin t.rows <- [ c ] :: t.rows; t.cell <- Some c end
         else begin t.row <- c :: t.row; t.cell <- Some c end;
         p.space <- false
     | _ :: _, ("tr" | "td" | "th") when not hide -> if tag = "tr" then break p else p.space <- true
     | _ -> ());
  if not hide then begin
    if is k spaced then paragraph p
    else if is k block then break p;
    if is k void then
      match tag with
      | "br" -> if p.tables = [] && p.page_flow.made = [] then push p.page_flow { runs = []; rule = false } else break p
      | "hr" -> rule p
      | "img" -> picture p attrs
      | "base" -> if p.page_base = "" then p.page_base <- attr attrs "href"
      | _ -> ()
  end;
  if not (is k void) then begin
    let face = e.face lor (k / 32) in
    let href = if tag = "a" && attr attrs "href" <> "" then attr attrs "href" else e.href in
    let margin = if p.tables = [] && is k deeper then min (e.margin + 3) (p.page_flow.width / 2) else e.margin in
    let pre = e.pre || (is k spaced && is k (code * 32)) in
    let el = { tag = tag; face = face; href = href; hide = hide; pre = pre; margin = margin; count = max 1 (number (attr attrs "start")) } in
    p.stack <- el :: p.stack;
    if not hide then begin
      p.page_flow.left <- margin;
      if is k block && tag = "li" then begin
        (* The bullet, or the number of an <ol>, goes in the margin. *)
        let mark = match p.stack with
          | _ :: (l : elem) :: _ when l.tag = "ol" -> let n = l.count in l.count <- n + 1; string_of_int n ^ "."
          | _ -> "*" in
        match p.tables with
        | [] ->
            let f = p.page_flow in
            f.at <- max 0 (margin - String.length mark - 1);
            f.made <- [ { col = f.at; text = mark; look = 0; link = ""; pic = -1 } ];
            (* If the number is wider than the margin, the item's text
             * starts after it. *)
            f.at <- max margin (f.at + String.length mark + 1)
        | _ -> emit p mark; p.space <- true
      end
    end
  end

let close_tag p tag k =
  let rec opened = function [] -> None | (e : elem) :: rest -> if e.tag = tag then Some e else opened rest in
  match (if is k void then None else opened p.stack) with
  | None -> ()
  | Some was ->
      let rec pop = function (e : elem) :: rest when e.tag <> tag -> pop rest | _ :: rest -> rest | [] -> [] in
      p.stack <- pop p.stack;
      let e = top p in
      if not was.hide then begin
        p.page_flow.left <- e.margin;
        if is k block then
          (match p.tables, tag with
           | t :: rest, "table" ->
               if t.depth > 0 then begin t.depth <- t.depth - 1; break p end
               else begin
                 if t.row <> [] then t.rows <- t.row :: t.rows;
                 p.tables <- rest;
                 lay_table p.page_flow t
               end
           | t :: _, ("td" | "th" | "caption") when t.depth = 0 -> t.cell <- None
           | _ -> ());
        if p.heading <> [] then lay_heading p;
        if is k spaced && tag = "h2" && p.tables = [] then rule p;
        if is k spaced then paragraph p
        else if is k block then break p
      end

let token p = function
  | Text s -> text p s
  | Open (tag, attrs) -> open_tag p tag (kind tag) attrs
  | Close tag -> close_tag p tag (kind tag)

let feed p chunk = List.iter (token p) (tokens p.reader chunk false)

let finish p =
  List.iter (token p) (tokens p.reader "" true);
  (match p.tables with t :: _ -> (if t.row <> [] then t.rows <- t.row :: t.rows); p.tables <- []; lay_table p.page_flow t | [] -> ());
  if p.heading <> [] then lay_heading p;
  end_line p.page_flow

let lines p = List.rev p.page_flow.out
let title p = p.page_title
let base p = p.page_base
let anchor p id = List.assoc_opt id p.anchors
let pictures p = p.npictures
let picture_of p id = List.nth p.pictures (p.npictures - 1 - id)
let count p = p.page_flow.nlines

(* The lines from the a-th to before the b-th, from the top. The lines
 * are kept last first, as they are made; an array of them from the top
 * is made again when lines have come since it was made, so that the
 * lines a scroll asks for are found at once (walking the list from its
 * end each time was a tenth of a page down). *)
let lines_between p a b =
  let f = p.page_flow in
  let n = f.nlines in
  let b = min b n and a = max a 0 in
  if a >= b then []
  else begin
    if f.cached <> n then begin
      let arr = Array.make n { runs = []; rule = false } in
      List.iteri (fun k l -> arr.(n - 1 - k) <- l) f.out;
      f.cache <- arr;
      f.cached <- n
    end;
    let rec take k acc = if k < a then acc else take (k - 1) (f.cache.(k) :: acc) in
    take (b - 1) []
  end

(*****************************************************************************)
(* The lines as text *)
(*****************************************************************************)

(* A picture's first row shows as [its alternative text, w x h]; its
 * other rows as nothing. *)
let show_line p width (l : line) =
  if l.rule then String.make width '-'
  else begin
    let at = ref 0 in
    String.concat "" (List.map (fun (r : run) ->
      let pad = if r.pic = -2 then "" else if r.col > !at then String.make (r.col - !at) ' ' else "" in
      let text =
        if r.pic >= 0 && r.pic mod 256 = 0 then
          let pc = picture_of p (r.pic / 256) in
          "[" ^ (if pc.pc_alt = "" then "picture" else pc.pc_alt) ^ ", " ^ string_of_int pc.pc_w ^ "x" ^ string_of_int pc.pc_h ^ "]"
        else if r.pic = -2 then ""
        else r.text in
      if r.pic <> -2 then at := max !at r.col + String.length text;
      pad ^ text) l.runs)
  end

let dump p = String.concat "" (List.map (fun l -> show_line p p.page_flow.width l ^ "\n") (lines p))

(*****************************************************************************)
(* The screen *)
(*****************************************************************************)

(* The colours, each an image of one pixel on our connection to the
 * screen (image 0 is where we draw: the screen, or our window). The
 * numbers in d_colour are bytes of the machine's palette. *)
let c_white = 1
let c_black = 2
let c_link = 3
let c_code = 4
let c_rule = 5
let c_bar = 7
let c_text = 8
let colours =
  d_colour c_white 255 ^ d_colour c_black 0 ^ d_colour c_link 23 ^ d_colour c_code 221
  ^ d_colour c_rule 136 ^ d_colour c_bar 3 ^ d_colour c_text 68

(*****************************************************************************)
(* Addresses *)
(*****************************************************************************)

let starts pre s = String.length s >= String.length pre && String.sub s 0 (String.length pre) = pre

(* an address and its #fragment, apart ("" when there is none) *)
let fragment url =
  match String.index_opt url '#' with
  | Some i -> String.sub url 0 i, String.sub url (i + 1) (String.length url - i - 1)
  | None -> url, ""

(* What was typed, as a full address, by the rules of the wire's other
 * end (TinyMachinePeer.www_address), which this side needs to know too to
 * find where a relative link goes: a title is an English Wikipedia
 * article, a name with a dot is https://. *)
let absolute typed =
  let s = String.trim typed in
  if starts "http://" s || starts "https://" s then s
  else begin
    let first = match String.index_opt s '/' with Some i -> String.sub s 0 i | None -> s in
    if String.contains first '.' && not (String.contains first ' ') then "https://" ^ s
    else "https://en.wikipedia.org/wiki/" ^ String.map (fun c -> if c = ' ' then '_' else c) s
  end

(* "https://host" of an address *)
let site url =
  match find url "://" 0 with
  | -1 -> ""
  | i -> (match String.index_from_opt url (i + 3) '/' with Some j -> String.sub url 0 j | None -> url)

(* Where a link goes, from the page at [url] whose <base> is [base]
 * (Wikipedia's is //en.wikipedia.org/wiki/, and its links ./OCaml). *)
let resolve url base href =
  if href = "" then url
  else if starts "http://" href || starts "https://" href then href
  else if starts "//" href then "https:" ^ href
  else if href.[0] = '#' then fst (fragment url) ^ href
  else if href.[0] = '/' then site url ^ href
  else begin
    let dir =
      if base <> "" then (if starts "//" base then "https:" ^ base else base)
      else begin
        let u = fst (fragment url) in
        match String.rindex_opt u '/' with
        | Some i when i > String.length (site url) -> String.sub u 0 (i + 1)
        | _ -> site url ^ "/"
      end in
    dir ^ (if starts "./" href then String.sub href 2 (String.length href - 2) else href)
  end

(*****************************************************************************)
(* The browser *)
(*****************************************************************************)

(* What the screen shows. Row 0 is a bar with the page's title, the last
 * row says how the reading goes, and the rows between show the page's
 * lines, scrolled by pixels (sc_y). A line that arrives is drawn if it
 * falls in the page's area.
 * A page is read from [nv_wire], the connection to the wire's other end,
 * -1 when the page is all there; [nv_history] holds the pages seen
 * before, each with the first line that was shown. Where the browsing
 * is (the nav) is a record of its own, as tiny-ml builds a record's
 * fields on its 11 registers. *)
type nav = {
  mutable nv_address : string;       (* the page's full address, without its #fragment *)
  mutable nv_wire : int;
  mutable nv_history : (string * int) list;
  mutable nv_goal : int;             (* a line to show first once it has come (back), or -1 *)
  mutable nv_goal_id : string;       (* an anchor to show once it has come (#fragment), or "" *)
  mutable nv_pressed : bool;         (* the mouse's button is down *)
  mutable nv_fetch : int;            (* the picture [nv_wire] brings, or -1 for the page *)
  mutable nv_hover : bool;           (* the mouse is over a link: its look is a hand *)
}

type screen = {
  mutable sc_page : page;
  sc_nav : nav;
  mutable sc_typing : string option;  (* g: the address being typed *)
  sc_cols : int;
  sc_rows : int;
  mutable sc_y : int;               (* the page's pixel at the top of its area *)
  mutable sc_drawn : int;           (* the lines before this one that are in the area are drawn *)
  mutable sc_got : int;             (* the bytes of the page read so far *)
  mutable sc_state : string;        (* "reading", "done", or why there is no page *)
  mutable sc_msgs : string list;    (* drawing messages not yet written, last first *)
}

let rows_of_page sc = sc.sc_rows - 2
let put sc m = sc.sc_msgs <- m :: sc.sc_msgs
let flush sc = if sc.sc_msgs <> [] then begin ignore (u_write 3 (String.concat "" (List.rev sc.sc_msgs))); sc.sc_msgs <- [] end

let clip sc s = if String.length s > sc.sc_cols - 2 then String.sub s 0 (max 0 (sc.sc_cols - 2)) else s

(* a row, filled with a colour *)
let fill_row sc row colour = put sc (d_fill 0 colour 0 (row * 16) (sc.sc_cols * 8) ((row * 16) + 16))

(* The page's area on the screen: from the row under the bar, [area sc]
 * pixels high. The page scrolls by pixels: its line i is at
 * area_top + 16 i - sc_y. *)
let area_top = 16
let area sc = rows_of_page sc * 16

(* A line cut by the page area's edge (half scrolled out) is drawn first
 * into [c_strip], an image of one line kept for that, then copied to
 * its place on the screen, cut to the area: so it never draws over the
 * bar or the status line. A line all inside the area is drawn on the
 * screen itself. *)
let c_strip = 9

(* A picture's image on our connection is its number plus 16 (the
 * colours and the strip are below). *)
let image_of id = 16 + id

(* A slice of a picture (16 rows of it) into dst at row y: the rows that
 * have come, from the picture's image, and a grey box for the rest;
 * until its first rows come, its alternative text on the grey. *)
let draw_slice sc dst y (r : run) =
  let id = r.pic / 256 and s = r.pic mod 256 in
  let pc = picture_of sc.sc_page id in
  let x = r.col * 8 and from = s * 16 in
  let high = min 16 (pc.pc_h - from) in
  if high > 0 then begin
    let have = if pc.pc_got > from then min high (pc.pc_got - from) else 0 in
    if have > 0 then put sc (d_draw dst (image_of id) (-1) x y (x + pc.pc_w) (y + have) 0 from);
    if have < high then begin
      put sc (d_fill dst c_code x (y + have) (x + pc.pc_w) (y + high));
      if s = 0 && pc.pc_got <= 0 && pc.pc_w >= 24 && high = 16 then begin
        let alt = if pc.pc_alt = "" then "picture" else pc.pc_alt in
        let fits = (pc.pc_w / 8) - 1 in
        put sc (d_text dst c_text (x + 4) y (if String.length alt > fits then String.sub alt 0 (max 0 fits) else alt))
      end
    end
  end

(* The page's line i, put on the screen (by the strip when it is cut by
 * the area's edge, or is half of a large heading's line). The text is a
 * dark grey, bold black in the kernel's bold font (its strokes wider,
 * an m's gaps kept: drawn twice, a pixel apart, an m was a block);
 * emphasis is italic; a link is blue and underlined; code is on light grey; a large
 * heading's characters are 16 by 32, the kernel's large font, its top
 * half on one line, its bottom half (pic -2) on the next. *)
let draw_line sc i (l : line) =
  let w = sc.sc_cols * 8 and at = area_top + (i * 16) - sc.sc_y in
  let tall = List.exists (fun (r : run) -> r.look land big <> 0) l.runs in
  let whole = not tall && at >= area_top && at + 16 <= area_top + area sc in
  let dst = if whole then 0 else c_strip and y = if whole then at else 0 in
  put sc (d_fill dst c_white 0 y w (y + 16));
  if l.rule then put sc (d_fill dst c_rule 0 (y + 7) w (y + 9))
  else
    List.iter (fun (r : run) ->
      if r.pic >= 0 then draw_slice sc dst y r
      else if r.col < sc.sc_cols && r.text <> "" then begin
        let k = if r.look land big <> 0 then 2 else 1 in
        let n = min (String.length r.text) ((sc.sc_cols - r.col) / k) in
        let t = String.sub r.text 0 n and x = r.col * 8 and ry = if r.pic = -2 then y - 16 else y in
        if r.look land code <> 0 then put sc (d_fill dst c_code x y (x + (n * 8)) (y + 16));
        let ink = if r.link <> "" then c_link else if r.look land bold <> 0 then c_black else c_text in
        (* (a look's bold and emph are the kernel's style's bits) *)
        let style = (r.look land (bold + emph)) lor (if r.look land under <> 0 then 4 else 0) lor (if k = 2 then 8 else 0) in
        put sc (if style = 0 then d_text dst ink x ry t else d_styled dst ink x ry style t);
        if r.link <> "" then put sc (d_line dst c_link x (ry + (16 * k) - 1) (x + (n * 8 * k) - 1) (ry + (16 * k) - 1))
      end) l.runs;
  if not whole then begin
    let y0 = max at area_top and y1 = min (at + 16) (area_top + area sc) in
    if y0 < y1 then put sc (d_draw 0 c_strip (-1) 0 y0 w y1 0 (y0 - at))
  end

let draw_bar sc =
  fill_row sc 0 c_bar;
  let t = if title sc.sc_page <> "" then title sc.sc_page else sc.sc_nav.nv_address in
  put sc (d_text 0 c_white 8 0 (clip sc t))

let draw_status sc =
  let row = sc.sc_rows - 1 in
  fill_row sc row c_code;
  let text =
    match sc.sc_typing with
    | Some typed -> "go to: " ^ typed ^ "_"
    | None ->
        let kb = string_of_int ((sc.sc_got + 1023) / 1024) ^ " KB" in
        (if sc.sc_state = "reading" then "reading, " ^ kb
         else if sc.sc_state = "done" then
           kb ^ ", " ^ string_of_int (count sc.sc_page) ^ " lines"
           ^ (if sc.sc_nav.nv_fetch >= 0 then ", picture " ^ string_of_int (sc.sc_nav.nv_fetch + 1) ^ " of " ^ string_of_int (pictures sc.sc_page) else "")
         else sc.sc_state)
        ^ "   space -: page, b: back, g: go to, q: quit" in
  put sc (d_text 0 c_black 8 (row * 16) (clip sc text))

(* The page's lines that fall in its area, from pixel [a] to pixel [b]
 * of the page, drawn; white where the page has ended. *)
let draw_between sc a b =
  let first = a / 16 and last = (b + 15) / 16 in
  let ls = lines_between sc.sc_page first last in
  List.iteri (fun k l -> draw_line sc (first + k) l) ls;
  let bottom = area_top + ((first + List.length ls) * 16) - sc.sc_y in
  let y0 = max bottom (area_top + a - sc.sc_y) and y1 = area_top + b - sc.sc_y in
  if y0 < y1 then put sc (d_fill 0 c_white 0 y0 (sc.sc_cols * 8) y1);
  first + List.length ls

(* the whole area drawn again *)
let redraw sc = sc.sc_drawn <- draw_between sc sc.sc_y (sc.sc_y + area sc)

let max_y sc = max 0 ((count sc.sc_page * 16) - area sc)

(* Scrolls by [d] pixels (up when negative). What stays on the screen is
 * moved there by one copy of the screen onto itself, and only the strip
 * that comes in is drawn: a scroll of a line draws one line, not the
 * screen's thirty. *)
let scroll_by sc d =
  let y = max 0 (min (sc.sc_y + d) (max_y sc)) in
  let delta = y - sc.sc_y and h = area sc and w = sc.sc_cols * 8 in
  if delta <> 0 then begin
    if abs delta >= h then begin sc.sc_y <- y; redraw sc end
    else if delta > 0 then begin
      put sc (d_draw 0 0 (-1) 0 area_top w (area_top + h - delta) 0 (area_top + delta));
      sc.sc_y <- y;
      let first = (y + h - delta) / 16 in
      let drawn = draw_between sc (y + h - delta) (y + h) in
      if sc.sc_drawn >= first then sc.sc_drawn <- max sc.sc_drawn drawn
    end
    else begin
      put sc (d_draw 0 0 (-1) 0 (area_top - delta) w (area_top + h) 0 area_top);
      sc.sc_y <- y;
      ignore (draw_between sc y (y - delta));
      sc.sc_drawn <- min sc.sc_drawn ((y + h + 15) / 16)
    end
  end

(* A screenful at a time, in steps of a few lines, so that the page is
 * seen moving rather than jumping: the same lines are drawn as by a
 * jump, as each step only draws what comes in. *)
let glide sc d =
  let step = 64 in
  let rec go left =
    if left <> 0 then begin
      let s = if left > 0 then min step left else max (- step) left in
      let before = sc.sc_y in
      scroll_by sc s;
      flush sc;
      if sc.sc_y <> before then go (left - s)
    end in
  go d

(* the page from line [line] on, as far as the page allows *)
let show_from sc line =
  let y = max 0 (min (line * 16) (max_y sc)) in
  if y <> sc.sc_y then begin sc.sc_y <- y; redraw sc end

(* The lines that arrived and fit below the ones on the screen; and the
 * place a page was asked to show (back, or a #fragment), once it has
 * come. *)
let show_new sc =
  if sc.sc_nav.nv_goal_id <> "" then
    (match anchor sc.sc_page sc.sc_nav.nv_goal_id with
     | Some line when line + rows_of_page sc <= count sc.sc_page || sc.sc_nav.nv_wire < 0 -> sc.sc_nav.nv_goal_id <- ""; show_from sc line
     | _ -> ());
  if sc.sc_nav.nv_goal >= 0 && ((sc.sc_nav.nv_goal / 16) + rows_of_page sc <= count sc.sc_page || sc.sc_nav.nv_wire < 0) then begin
    let goal = sc.sc_nav.nv_goal in
    sc.sc_nav.nv_goal <- -1;
    let y = max 0 (min goal (max_y sc)) in
    if y <> sc.sc_y then begin sc.sc_y <- y; redraw sc end
  end;
  let last = min (count sc.sc_page) ((sc.sc_y + area sc + 15) / 16) in
  if sc.sc_drawn < last then begin
    List.iteri (fun k l -> draw_line sc (sc.sc_drawn + k) l) (lines_between sc.sc_page sc.sc_drawn last);
    sc.sc_drawn <- last
  end

(* The mouse's look: a hand over a link, the arrow elsewhere (d_cursor:
 * the machine's window or page shows it). Sent when it changes. *)
let hover sc over =
  if over <> sc.sc_nav.nv_hover then begin
    sc.sc_nav.nv_hover <- over;
    put sc (d_cursor (if over then 1 else 0))
  end

(* Asks for the page at [url] (a full address), which replaces the one
 * shown; its #fragment, if any, is shown when it comes. *)
let load sc url =
  if sc.sc_nav.nv_wire >= 0 then ignore (u_close sc.sc_nav.nv_wire);
  for i = 0 to pictures sc.sc_page - 1 do if (picture_of sc.sc_page i).pc_got >= 0 then put sc (d_free (image_of i)) done;
  sc.sc_nav.nv_fetch <- -1;
  hover sc false;
  let address, id = fragment url in
  sc.sc_page <- create sc.sc_cols;
  sc.sc_nav.nv_address <- address;
  sc.sc_nav.nv_goal_id <- id;
  sc.sc_y <- 0;
  sc.sc_got <- 0;
  sc.sc_state <- "reading";
  draw_bar sc;
  redraw sc;
  (* the page asked of the wire's other end, on its port 70 *)
  sc.sc_nav.nv_wire <- u_dial "10.0.0.1" 70;
  if sc.sc_nav.nv_wire < 0 then begin
    sc.sc_state <- "www: no network (tiny-machine -net dir gives one)";
    finish sc.sc_page
  end
  else ignore (u_write sc.sc_nav.nv_wire ("www " ^ url ^ "\r\n"));
  draw_status sc

(* The pictures, once the page is all there: the next one asked of the
 * wire's other end, as "img w h address", the ones on the screen first,
 * then in the page's order. Its answer is a line "0 w h", then a row of
 * pixels a message, which go into the picture's image as they come. *)
let rec next_picture sc =
  let p = sc.sc_page in
  let pending id = (picture_of p id).pc_got = -1 in
  let rec on_screen = function
    | [] -> -1
    | (l : line) :: rest ->
        (match List.filter (fun (r : run) -> r.pic >= 0 && pending (r.pic / 256)) l.runs with
         | r :: _ -> r.pic / 256
         | [] -> on_screen rest) in
  let rec first id = if id >= pictures p then -1 else if pending id then id else first (id + 1) in
  let id = match on_screen (lines_between p (sc.sc_y / 16) ((sc.sc_y + area sc + 15) / 16)) with -1 -> first 0 | id -> id in
  if id >= 0 then begin
    let pc = picture_of p id in
    let fd = u_dial "10.0.0.1" 70 in
    if fd < 0 then begin pc.pc_got <- -2; next_picture sc end
    else begin
      pc.pc_got <- -3;
      let url = resolve sc.sc_nav.nv_address (base p) pc.pc_src in
      ignore (u_write fd ("img " ^ string_of_int pc.pc_w ^ " " ^ string_of_int pc.pc_h ^ " " ^ url ^ "\r\n"));
      sc.sc_nav.nv_wire <- fd;
      sc.sc_nav.nv_fetch <- id
    end
  end;
  draw_status sc

(* A message of the picture being fetched: its first line, then its
 * rows. A row that comes is drawn at once if its slice is on the
 * screen, so a picture is painted as it arrives. *)
let picture_message sc s =
  let id = sc.sc_nav.nv_fetch in
  let pc = picture_of sc.sc_page id in
  if pc.pc_got = -3 then begin
    match String.split_on_char ' ' s with
    | [ _; w; h ] when number w = pc.pc_w && number h = pc.pc_h ->
        put sc (d_image (image_of id) 0 0 pc.pc_w pc.pc_h 255);
        pc.pc_got <- 0
    | _ -> pc.pc_got <- -2
  end
  else if pc.pc_got >= 0 && pc.pc_got < pc.pc_h then begin
    let y = pc.pc_got in
    put sc (d_pixels (image_of id) 0 y s);
    pc.pc_got <- y + 1;
    let slice = (id * 256) + (y / 16) and first = sc.sc_y / 16 in
    List.iteri (fun k (l : line) ->
      List.iter (fun (r : run) ->
        if r.pic = slice then begin
          let x = r.col * 8 and sy = area_top + ((first + k) * 16) - sc.sc_y + (y mod 16) in
          if sy >= area_top && sy < area_top + area sc then put sc (d_draw 0 (image_of id) (-1) x sy (x + pc.pc_w) (sy + 1) 0 y)
        end) l.runs)
      (lines_between sc.sc_page first ((sc.sc_y + area sc + 15) / 16))
  end

(* Goes to an address, remembering where we were. A link to a place of
 * the page shown (#cite_note-2) only moves to it. *)
let go sc url =
  let address, id = fragment url in
  sc.sc_nav.nv_history <- (sc.sc_nav.nv_address, sc.sc_y) :: sc.sc_nav.nv_history;
  if address = sc.sc_nav.nv_address && id <> "" then begin
    (match anchor sc.sc_page id with Some line -> show_from sc line | None -> ());
    draw_status sc
  end
  else load sc url

(* Back to the page before, scrolled where it was: moved to if it is the
 * same page, asked for again if not. *)
let back sc =
  match sc.sc_nav.nv_history with
  | [] -> ()
  | (address, y) :: rest ->
      sc.sc_nav.nv_history <- rest;
      if address = sc.sc_nav.nv_address then begin
        let y = max 0 (min y (max_y sc)) in
        if y <> sc.sc_y then begin sc.sc_y <- y; redraw sc end
      end
      else begin load sc address; sc.sc_nav.nv_goal <- y end

(* the link under the mouse, if any *)
let link_at sc x y =
  let col = x / 8 and line = (sc.sc_y + y - area_top) / 16 in
  if y < area_top || y >= area_top + area sc then None
  else
    match lines_between sc.sc_page line (line + 1) with
    | [ l ] ->
        (match List.filter (fun (r : run) -> r.link <> "" && col >= r.col && col < r.col + (String.length r.text * if r.look land big <> 0 then 2 else 1)) l.runs with
         | r :: _ -> Some r.link
         | [] -> None)
    | _ -> None

(* The mouse: over a link it is a hand; the left button pressed on a link
 * follows it; the wheel (the buttons 8 and 16, Plan 9's) scrolls. *)
let mouse sc x y buttons =
  if buttons >= 0 then begin
    hover sc (link_at sc x y <> None);
    if buttons land 1 <> 0 && not sc.sc_nav.nv_pressed then
      (match link_at sc x y with Some href -> go sc (resolve sc.sc_nav.nv_address (base sc.sc_page) href) | None -> ());
    sc.sc_nav.nv_pressed <- buttons land 1 <> 0;
    if buttons land 8 <> 0 then scroll_by sc (-48);
    if buttons land 16 <> 0 then scroll_by sc 48
  end

(* The window's size in pixels, asked as emacs asks it: an ENQ (ASCII's
 * 5) printed, which tiny-windows answers in the window's mouse box, the
 * descriptor 4, as a mouse at (width, height) with the buttons -1. On
 * the console no one answers, and the screen is 640 by 480. *)
let size () =
  ignore (u_write 1 "\005");
  let fds = Array.make 1 4 and until = u_ticks () + 200 in
  let rec answer () =
    if u_ready fds 1 until <> 4 then 640, 480
    else (let s = u_read 4 12 in if String.length s = 12 && int16 s 8 = -1 then int16 s 0, int16 s 4 else answer ()) in
  answer ()

(* What a key does; false for q, which quits. While an address is typed
 * (after g), the keys are its characters, Enter goes, Escape gives up.
 * The arrows are 128 to 131 (up, down, left, right): up and down scroll
 * a line (the wheel and the trackpad come as these: tiny-machine's
 * window and page send a step of the wheel as an arrow), left and right
 * a screenful, as - and space do. Backspace is 8 or 127. *)
let key sc k =
  match sc.sc_typing with
  | Some typed ->
      if k = 10 || k = 13 then begin sc.sc_typing <- None; if typed <> "" then go sc (absolute typed) end
      else if k = 27 then sc.sc_typing <- None
      else if k = 8 || k = 127 then sc.sc_typing <- Some (if typed = "" then "" else String.sub typed 0 (String.length typed - 1))
      else if k >= 32 && k < 127 then sc.sc_typing <- Some (typed ^ String.make 1 (Char.chr k));
      draw_status sc;
      true
  | None ->
      let page = area sc - 16 in
      if k = Char.code 'q' then false
      else begin
        (if k = Char.code ' ' || k = 131 then glide sc page
         else if k = Char.code '-' || k = 130 then glide sc (- page)
         else if k = 129 then scroll_by sc 16
         else if k = 128 then scroll_by sc (-16)
         else if k = Char.code 'b' || k = 8 || k = 127 then back sc
         else if k = Char.code 'g' then begin sc.sc_typing <- Some ""; draw_status sc end);
        true
      end

let browse typed =
  let w, h = size () in
  let nav = { nv_address = ""; nv_wire = -1; nv_history = []; nv_goal = -1; nv_goal_id = ""; nv_pressed = false; nv_fetch = -1; nv_hover = false } in
  let sc = { sc_page = create (w / 8); sc_nav = nav; sc_typing = None; sc_cols = w / 8; sc_rows = h / 16; sc_y = 0; sc_drawn = 0;
             sc_got = 0; sc_state = "reading"; sc_msgs = [] } in
  put sc colours;
  put sc (d_image c_strip 0 0 (sc.sc_cols * 8) 16 255);
  load sc (absolute typed);
  flush sc;
  let fds = Array.make 3 0 in
  (* [keys]: whether keys may still come. When they have ended and the
   * page is all there, the program ends and leaves the page on the
   * screen. *)
  let rec loop keys =
    if sc.sc_nav.nv_wire >= 0 || keys then begin
      let n = ref 0 in
      if keys then begin fds.(0) <- 0; fds.(1) <- 4; n := 2 end;
      if sc.sc_nav.nv_wire >= 0 then begin fds.(!n) <- sc.sc_nav.nv_wire; n := !n + 1 end;
      let ready = u_ready fds !n 0 in
      if sc.sc_nav.nv_wire >= 0 && ready = sc.sc_nav.nv_wire && sc.sc_nav.nv_fetch >= 0 then begin
        let s = u_read sc.sc_nav.nv_wire 1024 in
        if s = "" then begin
          ignore (u_close sc.sc_nav.nv_wire);
          sc.sc_nav.nv_wire <- -1;
          let pc = picture_of sc.sc_page sc.sc_nav.nv_fetch in
          if pc.pc_got < 0 then pc.pc_got <- -2;
          sc.sc_nav.nv_fetch <- -1;
          next_picture sc
        end
        else picture_message sc s;
        flush sc;
        loop keys
      end
      else if sc.sc_nav.nv_wire >= 0 && ready = sc.sc_nav.nv_wire then begin
        let s = u_read sc.sc_nav.nv_wire 1024 in
        if s = "" then begin
          finish sc.sc_page;
          ignore (u_close sc.sc_nav.nv_wire);
          sc.sc_nav.nv_wire <- -1;
          sc.sc_state <- "done";
          show_new sc; draw_bar sc; draw_status sc;
          next_picture sc
        end
        else begin
          let before = sc.sc_got / 16384 in
          sc.sc_got <- sc.sc_got + String.length s;
          feed sc.sc_page s;
          show_new sc;
          if sc.sc_got / 16384 <> before then draw_status sc
        end;
        flush sc;
        loop keys
      end
      else if keys && ready = 4 then begin
        let s = u_read 4 12 in
        if String.length s = 12 then mouse sc (int16 s 0) (int16 s 4) (int16 s 8);
        flush sc;
        loop keys
      end
      else if keys && ready = 0 then begin
        let typed = u_read 0 16 in
        if typed = "" then loop false
        else begin
          let rec each i = i >= String.length typed || (key sc (Char.code typed.[i]) && each (i + 1)) in
          let go_on = each 0 in
          flush sc;
          if go_on then loop keys
          else begin
            if sc.sc_nav.nv_wire >= 0 then ignore (u_close sc.sc_nav.nv_wire);
            hover sc false;
            for row = 0 to sc.sc_rows - 1 do fill_row sc row c_white done;
            flush sc
          end
        end
      end
      else loop keys
    end in
  loop true
