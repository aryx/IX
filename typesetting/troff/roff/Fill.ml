(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Fill.mli *)

type item =
  | Par of float * Doc.par
  | Tag of float * float * Doc.inline list
  | Gap of float
  | Head of int * Doc.inline list
  | Open of wrapper
  | Close
  | Whole of float * Doc.block

and wrapper = Footnote | Keep

type t = {
  roff : Roff.t;
  base : float;
  length : float;
  mutable indent : float;
  mutable indent_before : float;
  mutable ti : float option;
  mutable short : float;
  mutable short_before : float;
  mutable fill : bool;
  mutable tabs : float list;
  mutable center : int;
  mutable no_space : bool;
  mutable par : Doc.inline list;
  mutable started : bool;
  mutable first : float;
  mutable par_tabs : float list;
  mutable sentence : bool;
  mutable glued : bool;
  mutable blank_end : bool;
  mutable capture : (Doc.inline list -> unit) option;
  mutable tag_open : bool;
  mutable one_line : bool;
  mutable heading : int option;
  mutable items : item list;
}

let create (roff : Roff.t) (base : float) (length : float) (tabs : float list) : t =
  { roff; base; length; indent = 0.; indent_before = 0.; ti = None; short = 0.; short_before = 0.; fill = true; tabs; center = 0;
    no_space = false; par = []; started = false; first = 0.; par_tabs = []; sentence = false; glued = false; blank_end = false;
    capture = None; tag_open = false; one_line = false; heading = None; items = [] }

let emit (m : t) (it : item) = m.items <- it :: m.items

let break (m : t) =
  (* (a tag whose line is ended before any word: it has the line to
   * itself, said by a paragraph of nothing) *)
  if m.tag_open && not m.started then begin m.started <- true; m.first <- m.indent; m.par_tabs <- m.tabs end;
  m.tag_open <- false;
  if m.started then begin
    (match m.heading with
     | Some level -> m.heading <- None; emit m (Head (level, List.rev m.par))
     | None ->
         emit m (Par (m.indent, { fill = m.fill; first = m.first -. m.indent; short = m.short; tabs = m.par_tabs; center = m.center > 0; body = List.rev m.par })));
    (* (a line written: a .ns said while it was being filled is forgotten) *)
    m.par <- []; m.started <- false; m.glued <- false; m.sentence <- false; m.blank_end <- false; m.no_space <- false
  end

let gap (m : t) (n : float) = if not m.no_space && n > 0. then emit m (Gap n)

let space : Doc.inline = Doc.Text (Doc.plain, " ")

(* A tab in a line that is filled: troff makes of it a move as wide as
 * it would be from the start of the line as it was written, wherever
 * its words end up on the page; so "int", a tab and a name are a word
 * with a hole in it. Said here by spaces a line is not cut at (U+00A0). *)
let untab (tabs : float list) (words : Doc.inline list) : Doc.inline list =
  let col = ref 0 in
  List.map (fun (w : Doc.inline) ->
    match w with
    | Doc.Break | Doc.Page _ -> w
    | Doc.Text (_, s) when not (String.contains s '\t') -> col := !col + Utf8.length (Doc.letters s); w
    | Doc.Text (style, s) ->
        let out = Buffer.create (String.length s) in
        List.iter (fun c ->
          if c = "\t" then begin
            let stop = match List.find_opt (fun t -> t > float_of_int !col +. 0.01) tabs with Some t -> int_of_float t | None -> !col in
            (* (at the line's start it is a word of its own: the line before
             * may end there) *)
            if !col = 0 then Buffer.add_string out "\xe2\x80\x8b";
            Buffer.add_string out (String.concat "" (List.init (max 0 (stop - !col)) (fun _ -> "\xc2\xa0")));
            col := stop
          end
          else begin Buffer.add_string out c; if Doc.letters c <> "" then incr col end) (fst (Utf8.chars s));
        Doc.Text (style, Buffer.contents out)) words

(* does a text start with a tab *)
let rec tab_first (words : Doc.inline list) : bool =
  match words with
  | Doc.Text (_, s) :: rest -> if Doc.letters s = "" then tab_first rest else (Doc.letters s).[0] = '\t'
  | _ -> false

let text (m : t) (words : Doc.inline list) (sentence : bool) (glued : bool) =
  (match m.capture with
   | Some f -> m.capture <- None; f words
   | None ->
       m.tag_open <- false;
       if not m.started then begin
         m.started <- true; m.par_tabs <- m.tabs;
         m.first <- (match m.ti with Some x -> x | None -> m.indent);
         m.ti <- None
       end
       else if not m.fill then m.par <- Doc.Break :: m.par
       (* (the end of a line is a space, two after a sentence; one, when
        * the line ended with blanks; none before a tab) *)
       else if m.glued then ()
       else if m.blank_end then m.par <- space :: m.par
       else if not (tab_first words) then m.par <- (if m.sentence then [ space; space ] else [ space ]) @ m.par;
       (* (on paper a letter has no column: a tab is left to the layout,
        * which takes it from the start of the line it is on) *)
       let words = if m.fill && Roff.device m.roff = Roff.Terminal then untab m.tabs words else words in
       m.blank_end <- false;
       m.par <- List.rev_append words m.par;
       m.sentence <- sentence; m.glued <- glued; m.no_space <- false;
       if m.center > 0 then begin break m; m.center <- m.center - 1 end);
  if m.one_line then begin m.one_line <- false; Roff.reset_style m.roff end

(* do these words end a sentence: with a dot, a question or an
 * exclamation mark, and what may close after it. (Not "e.g.\&": the
 * nothing that \& is, U+2060, is after the dot.) *)
let ends_sentence (words : Doc.inline list) : bool =
  let s = String.concat "" (List.map (fun (w : Doc.inline) -> match w with Doc.Text (_, t) | Doc.Page (_, _, t) -> t | Doc.Break -> "") words) in
  let rec go i = i >= 0 && (if String.contains "\"')]*" s.[i] then go (i - 1) else String.contains ".?!" s.[i]) in
  go (String.length s - 1)

let glued (args : string list) : bool = match List.rev args with last :: _ -> Roff.continues last | [] -> false

let length (m : t) (s : string) : float = Roff.ens m.roff (Roff.number m.roff 'n' s)

(* a terminal has no place between two columns: nroff takes the one on
 * the left, of where a request ends up (an indent of 12.5 is 12, and
 * 2.5 to its left is 9) *)
let column (m : t) (x : float) : float = if Roff.device m.roff = Roff.Terminal then Float.floor (x +. 0.001) else x

let moved (m : t) (from : float) (s : string) : float =
  if s = "" then from
  else if s.[0] = '+' then column m (from +. length m (String.sub s 1 (String.length s - 1)))
  else if s.[0] = '-' then column m (from -. length m (String.sub s 1 (String.length s - 1)))
  else column m (length m s -. m.base)

(* a line without the blanks at its end (not one after a backslash) *)
let rec without_end (s : string) : string =
  let n = String.length s in
  if n > 0 && s.[n - 1] = ' ' && not (n > 1 && s.[n - 2] = '\\') then without_end (String.sub s 0 (n - 1)) else s

let line (m : t) (raw : string) =
  let s = if m.fill then without_end raw else raw in
  if s = "" then begin
    (* a blank line is a .sp, a line of an example when not filling *)
    if m.fill then begin break m; gap m 1. end else text m [] false false
  end
  else begin
    if m.fill && s.[0] = ' ' then break m;
    let words = Roff.inlines m.roff s in
    let blank = String.length s < String.length raw in
    (* (a line that only changes the font is no word, and no space; a
     * blank at a line's end is enough for troff to see no sentence's
     * end) *)
    if words <> [] || not m.fill || m.capture <> None then begin
      text m words (ends_sentence words && not blank) (Roff.continues s);
      if m.started && m.fill then m.blank_end <- blank
    end
  end

let aside (m : t) (run : unit -> 'a) : Doc.inline list * 'a =
  let was = { m with roff = m.roff } and font = Roff.font m.roff in
  m.par <- []; m.started <- false; m.glued <- false; m.sentence <- false; m.blank_end <- false; m.capture <- None; m.tag_open <- false;
  m.heading <- None; m.fill <- true; m.center <- 0; m.ti <- None; m.indent <- 0.; m.short <- 0.;
  Roff.reset_style m.roff;
  let r = run () in
  break m;
  (* what it made, taken back: its paragraphs' words, a line's end between two *)
  let rec made (items : item list) (acc : Doc.inline list) : Doc.inline list =
    if items == was.items then acc
    else match items with
      | Par (_, p) :: rest -> made rest (p.body @ (if acc = [] then [] else Doc.Break :: acc))
      | _ :: rest -> made rest acc
      | [] -> acc in
  let words = made m.items [] in
  m.items <- was.items;
  m.par <- was.par; m.started <- was.started; m.first <- was.first; m.par_tabs <- was.par_tabs; m.glued <- was.glued;
  m.sentence <- was.sentence; m.blank_end <- was.blank_end; m.capture <- was.capture; m.tag_open <- was.tag_open;
  m.heading <- was.heading; m.fill <- was.fill; m.center <- was.center; m.ti <- was.ti; m.indent <- was.indent; m.short <- was.short;
  m.no_space <- was.no_space; Roff.reset_style m.roff; Roff.set_font m.roff font;
  (words, r)

let request (m : t) (name : string) (args : string list) : bool =
  let arg k = match List.nth_opt args k with Some a -> a | None -> "" in
  let roff = m.roff in
  match name with
  | "nf" -> break m; m.fill <- false; true
  | "fi" -> break m; m.fill <- true; true
  | "br" -> break m; true
  | "sp" -> break m; gap m (if arg 0 = "" then 1. else Roff.lines roff (Roff.number roff 'v' (arg 0))); true
  | "ti" -> break m; m.ti <- Some (moved m m.indent (arg 0)); true
  | "in" ->
      break m;
      let now = m.indent in
      m.indent <- (if arg 0 = "" then m.indent_before else moved m m.indent (arg 0));
      m.indent_before <- now; true
  | "ll" ->
      (* (no break: the line being filled keeps its length, in troff;
       * here the paragraph does) *)
      let now = m.short and a = arg 0 in
      m.short <- (if a = "" then m.short_before
                  else if a.[0] = '+' then m.short -. length m (String.sub a 1 (String.length a - 1))
                  else if a.[0] = '-' then m.short +. length m (String.sub a 1 (String.length a - 1))
                  else m.length -. length m a);
      m.short_before <- now; true
  | "ta" ->
      let rec stops (at : float) (l : string list) : float list =
        match l with
        | [] -> []
        | s :: rest ->
            let x = column m (if s <> "" && s.[0] = '+' then at +. length m (String.sub s 1 (String.length s - 1)) else length m s) in
            x :: stops x rest in
      (* (lines not filled are one paragraph, and a paragraph has one set
       * of stops: the lines after this are another) *)
      if m.started && not m.fill then break m;
      m.tabs <- stops 0. args; true
  | "tl" ->
      (* a line in three parts, 'left'middle'right': here one after the
       * other, the line not being measured *)
      let all = String.concat " " args in
      break m;
      if String.length all > 1 then begin
        let parts = List.filter (fun p -> p <> "") (String.split_on_char all.[0] all) in
        let fill = m.fill in
        m.fill <- false;
        text m (List.concat_map (fun p -> Roff.inlines roff p @ [ Doc.Text (Doc.plain, "  ") ]) parts) false false;
        break m; m.fill <- fill
      end;
      true
  | "ce" -> break m; m.center <- (if arg 0 = "" then 1 else int_of_float (Roff.number roff 'u' (arg 0))); true
  | "ns" -> m.no_space <- true; true
  | "rs" -> m.no_space <- false; true
  | "ft" -> Roff.set_font roff (Roff.font_named roff (arg 0)); true
  | "ps" -> Roff.resize roff (arg 0); true
  (* what is not done: the line's height, room asked on the page,
   * hyphens, the margins filled, a new sheet *)
  | "vs" | "ne" | "na" | "ad" | "nh" | "hy" | "lg" | "bp" -> true
  | _ -> false

(*****************************************************************************)
(* The tree, from the places *)
(*****************************************************************************)

let same (a : float) (b : float) : bool = Float.abs (a -. b) < 0.01

(* where the next thing that is not a space is *)
let rec place (base : float) (items : item list) : float =
  match items with
  | [] | Head _ :: _ -> 0.
  | Par (k, _) :: _ -> k
  | Tag (k, _, _) :: _ -> k
  | Gap _ :: rest -> place base rest
  | Whole (k, _) :: _ -> k
  (* (a footnote, a keep: where the text is; and what they have ends
   * with them) *)
  | Open _ :: _ | Close :: _ -> base

(* [blocks root base items]: the blocks at [base] and to its right, and
 * the items left: the first that is to its left closes it. (At the
 * root nothing is left: what is to the left of the text's margin is
 * an indent of less than nothing.) *)
let rec blocks (root : bool) (base : float) (items : item list) : Doc.block list * item list =
  match items with
  | [] -> ([], [])
  | Head (level, words) :: rest ->
      if not root then ([], items) else let bs, left = blocks root base rest in (Doc.Heading (level, words) :: bs, left)
  | Close :: _ -> ([], items)
  | Open w :: rest ->
      let inner, rest = blocks true base rest in
      let rest = match rest with Close :: after -> after | _ -> rest in
      let bs, left = blocks root base rest in
      ((match w with Footnote -> Doc.Footnote inner | Keep -> Doc.Keep inner) :: bs, left)
  | Gap n :: (Close :: _ as rest) -> let bs, left = blocks root base rest in (Doc.Space n :: bs, left)
  | _ ->
      let k = place base items in
      if k < base && not (same k base) && not root then ([], items)
      else if not (same k base) then begin
        let inner, rest = blocks false k items in
        let bs, left = blocks root base rest in
        (Doc.Indent (k -. base, inner) :: bs, left)
      end
      else
        match items with
        | Gap n :: rest -> let bs, left = blocks root base rest in (Doc.Space n :: bs, left)
        | Par (_, p) :: rest -> let bs, left = blocks root base rest in (Doc.Para p :: bs, left)
        | Whole (_, b) :: rest -> let bs, left = blocks root base rest in (b :: bs, left)
        | Tag (_, to_, tag) :: rest ->
            let body, rest = if to_ > base then blocks false to_ rest else ([], rest) in
            let bs, left = blocks root base rest in
            (Doc.Tagged { tag; width = to_ -. base; body } :: bs, left)
        | _ -> ([], [])


let tree (m : t) : Doc.block list = fst (blocks true 0. (List.rev m.items))
