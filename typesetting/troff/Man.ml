(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Man.mli *)

(* What is read, before it is a tree: each thing with how far right
 * of the text's margin it is. A tag has two places, its own and its
 * body's. *)
type item =
  | Par of float * Doc.par
  | Tag of float * float * Doc.inline list
  | Gap of float
  | Head of int * Doc.inline list

(* the next line of text is not the paragraph's: a heading's words
 * (.SH alone on its line), a tag (.TP) *)
type capture = Nothing | Heading of int | Tag_line

type state = {
  roff : Roff.t;
  (* tmac.an's )R and )I: the text's place (.RS), and how far right of
   * it a tagged paragraph's body is *)
  mutable r : float;
  mutable i : float;
  (* the lines between two paragraphs (.PD) *)
  mutable pd : float;
  (* troff's own indent, from the text's margin: r, or r + i under a tag *)
  mutable indent : float;
  mutable indent_before : float;
  (* .ti: the next line's place *)
  mutable ti : float option;
  mutable fill : bool;
  mutable tabs : float list;
  mutable center : int;
  (* .ns: the spaces asked are not made, until some text *)
  mutable no_space : bool;
  (* the paragraph being read, its last words first *)
  mutable par : Doc.inline list;
  mutable started : bool;
  mutable first : float;
  (* the stops there were when it started *)
  mutable par_tabs : float list;
  (* the line before ended a sentence; it ended with \c *)
  mutable sentence : bool;
  mutable glued : bool;
  (* it ended with a blank: that is the space before the next line's words *)
  mutable blank_end : bool;
  mutable capture : capture;
  (* a tag was just said, and no word of its body yet *)
  mutable tag_open : bool;
  (* a font asked for one line (.B alone on its line) *)
  mutable one_line : bool;
  (* what .RS put aside, the last first: i and r *)
  mutable levels : (float * float) list;
  mutable items : item list;
  mutable header : string * string * string;
}

(* tmac.an's )M: a tag's width when none is said, and a .RS's *)
let step = 5.

let default_tabs : float list = List.init 13 (fun k -> float_of_int (5 * (k + 1)))

let emit (m : state) (it : item) = m.items <- it :: m.items

(* the paragraph so far is one: every request that ends a line *)
let break (m : state) =
  (* (a tag whose line is ended before any word: it has the line to
   * itself, said by a paragraph of nothing) *)
  if m.tag_open && not m.started then begin m.started <- true; m.first <- m.indent; m.par_tabs <- m.tabs end;
  m.tag_open <- false;
  if m.started then begin
    emit m (Par (m.indent, { fill = m.fill; first = m.first -. m.indent; tabs = m.par_tabs; center = m.center > 0; body = List.rev m.par }));
    (* (a line written: a .ns said while it was being filled is forgotten) *)
    m.par <- []; m.started <- false; m.glued <- false; m.sentence <- false; m.blank_end <- false; m.no_space <- false
  end

let gap (m : state) (n : float) = if not m.no_space && n > 0. then emit m (Gap n)

(* tmac.an's }E: the margin back where the text is *)
let margin (m : state) = m.indent <- m.r; Roff.reset_style m.roff

let space : Doc.inline = Doc.Text (Doc.plain, " ")

(* A tab in a line that is filled: troff makes of it a move as wide as
 * it would be from the start of the line as it was written, wherever
 * its words end up on the page; so "int", a tab and a name are a word
 * with a hole in it. Said here by spaces a line is not cut at (U+00A0). *)
let untab (tabs : float list) (words : Doc.inline list) : Doc.inline list =
  let col = ref 0 in
  List.map (fun (w : Doc.inline) ->
    match w with
    | Doc.Break -> w
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

(* a line's words: the paragraph's, or what was waiting for them *)
let text (m : state) (words : Doc.inline list) (sentence : bool) (glued : bool) =
  (match m.capture with
   | Heading level ->
       m.capture <- Nothing;
       emit m (Head (level, words));
       m.i <- step; margin m; m.no_space <- true
   | Tag_line ->
       m.capture <- Nothing;
       emit m (Tag (m.r, m.r +. m.i, words));
       m.indent <- m.r +. m.i; Roff.reset_style m.roff; m.no_space <- false; m.tag_open <- true
   | Nothing ->
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
       let words = if m.fill then untab m.tabs words else words in
       m.blank_end <- false;
       m.par <- List.rev_append words m.par;
       m.sentence <- sentence; m.glued <- glued; m.no_space <- false;
       if m.center > 0 then begin break m; m.center <- m.center - 1 end);
  if m.one_line then begin m.one_line <- false; Roff.reset_style m.roff end

(* do these words end a sentence: with a dot, a question or an
 * exclamation mark, and what may close after it. (Not "e.g.\&": the
 * nothing that \& is, U+2060, is after the dot.) *)
let ends_sentence (words : Doc.inline list) : bool =
  let s = String.concat "" (List.map (fun (w : Doc.inline) -> match w with Doc.Text (_, t) -> t | Doc.Break -> "") words) in
  let rec go i = i >= 0 && (if String.contains "\"')]*" s.[i] then go (i - 1) else String.contains ".?!" s.[i]) in
  go (String.length s - 1)

let length (m : state) (s : string) : float = Roff.ens (Roff.number m.roff 'n' s)

(* a terminal has no place between two columns: nroff takes the one on
 * the left, of where a request ends up (an indent of 12.5 is 12, and
 * 2.5 to its left is 9) *)
let column (m : state) (x : float) : float = if Roff.device m.roff = Roff.Terminal then Float.floor (x +. 0.001) else x

(* a place said from the one there is: +2, -2, or 7 (from the paper's
 * edge, the text's margin being [step] in) *)
let moved (m : state) (from : float) (s : string) : float =
  if s = "" then from
  else if s.[0] = '+' then column m (from +. length m (String.sub s 1 (String.length s - 1)))
  else if s.[0] = '-' then column m (from -. length m (String.sub s 1 (String.length s - 1)))
  else column m (length m s -. step)

let tag_width (m : state) (s : string) = if s <> "" then begin let v = column m (length m s) in m.i <- (if v = 0. then step else v) end

let font_of (name : char) : Doc.font = match name with 'I' -> Doc.Italic | 'R' -> Doc.Roman | _ -> Doc.Mono

(* does a macro's last argument end with \c *)
let glued (args : string list) : bool = match List.rev args with last :: _ -> Roff.continues last | [] -> false

(* arguments set in a font, a space between: .B, .I. (No sentence
 * ends there for troff: tmac.an writes its six arguments, and the
 * blanks between those not given are at the line's end.) *)
let in_font (m : state) (f : Doc.font) (args : string list) =
  if args = [] then begin Roff.set_font m.roff f; m.one_line <- true end
  else begin
    Roff.set_font m.roff f;
    (* (.B's first word is not to be cut: tmac.an's \%) *)
    (* (tmac.an writes its six arguments with a blank between: those
     * not given leave blanks at the line's end, which count when the
     * line is centered) *)
    let blanks = if m.center > 0 then String.concat "" (List.init (max 0 (6 - List.length args)) (fun _ -> "\\ ")) else "" in
    let words = Roff.inlines m.roff ((if f = Doc.Mono then "\\%" else "") ^ String.concat " " args ^ blanks) in
    Roff.reset_style m.roff;
    text m words false (glued args)
  end

let quote (m : state) (s : string) : Doc.inline list =
  match Roff.device m.roff with
  | Roff.Terminal -> Roff.inlines_in m.roff Doc.Mono ("`" ^ s ^ "'")
  | Roff.Typesetter -> Roff.inlines_in m.roff Doc.Mono s

let rec request (m : state) (name : string) (args : string list) =
  (* (tmac.an's macros read six arguments) *)
  let args = if List.mem name [ "B"; "I"; "SM"; "RI"; "IR"; "IB"; "RB"; "BR"; "BI" ] then List.filteri (fun k _ -> k < 6) args else args in
  let arg k = match List.nth_opt args k with Some a -> a | None -> "" in
  let roff = m.roff in
  match name with
  | "TH" ->
      let title = arg 0 ^ "(" ^ arg 1 ^ ")" in
      m.header <- (title, (if arg 2 = "" then "" else "(" ^ arg 2 ^ ")"), title)
  | "SH" | "SS" ->
      break m; m.pd <- 1.; gap m m.pd;
      m.r <- 0.; m.levels <- []; m.fill <- true; m.ti <- None;
      Roff.reset_style roff; Roff.set_font roff Doc.Bold;
      m.capture <- Heading (if name = "SH" then 1 else 2);
      if args <> [] then text m (Roff.inlines roff (String.concat " " args)) false false
  | "PP" | "LP" | "P" -> break m; gap m m.pd; m.i <- step; margin m; m.no_space <- true
  | "PD" -> m.pd <- (if arg 0 = "" then 1. else Roff.lines (Roff.number roff 'v' (arg 0)))
  | "TP" ->
      tag_width m (arg 0);
      break m; gap m m.pd; m.indent <- m.r; m.no_space <- true; m.capture <- Tag_line
  | "IP" ->
      if arg 0 <> "" then begin
        request m "TP" [ arg 1 ];
        text m (Roff.inlines roff (arg 0)) false false
      end
      else begin break m; gap m m.pd; tag_width m (arg 1); Roff.reset_style roff; m.indent <- m.r +. m.i end
  | "HP" ->
      break m; gap m m.pd; tag_width m (arg 0);
      m.indent <- m.r +. m.i; m.ti <- Some m.r; Roff.reset_style roff
  | "TF" ->
      (* a list of names as wide as the widest, closed up *)
      request m "IP" [ ""; "\\w'" ^ arg 0 ^ "\\ \\ 'u" ]; m.pd <- 0.
  | "RS" ->
      break m;
      m.levels <- (m.i, m.r) :: m.levels;
      m.r <- m.r +. (if arg 0 = "" then m.i else column m (length m (arg 0)));
      m.i <- step; margin m
  | "RE" ->
      break m;
      (* .RE 2: back to what it was before the second .RS *)
      let keep = if arg 0 = "" then List.length m.levels - 1 else max 0 (int_of_float (Roff.number roff 'u' (arg 0)) - 1) in
      let rec pop () =
        match m.levels with
        | (i, r) :: rest when List.length m.levels > keep -> m.i <- i; m.r <- r; m.levels <- rest; pop ()
        | _ -> () in
      pop (); margin m
  | "EX" -> break m; m.fill <- false; if Roff.device roff = Roff.Typesetter then Roff.set_font roff Doc.Mono
  | "EE" -> break m; m.fill <- true; Roff.reset_style roff
  | "nf" -> break m; m.fill <- false
  | "fi" -> break m; m.fill <- true
  | "br" -> break m
  | "sp" -> break m; gap m (if arg 0 = "" then 1. else Roff.lines (Roff.number roff 'v' (arg 0)))
  | "ti" -> break m; m.ti <- Some (moved m m.indent (arg 0))
  | "in" ->
      break m;
      let now = m.indent in
      m.indent <- (if arg 0 = "" then m.indent_before else moved m m.indent (arg 0));
      m.indent_before <- now
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
      m.tabs <- stops 0. args
  | "DT" -> if m.started && not m.fill then break m; m.tabs <- default_tabs
  | "ce" -> break m; m.center <- (if arg 0 = "" then 1 else int_of_float (Roff.number roff 'u' (arg 0)))
  | "ns" -> m.no_space <- true
  | "rs" -> m.no_space <- false
  | "ft" -> Roff.set_font roff (Roff.font_named roff (arg 0))
  (* what a terminal's page has nothing to do with: the size, the
   * line's height, room asked on the page, hyphens, the margins filled *)
  | "ps" | "vs" | "ne" | "na" | "ad" | "nh" | "hy" | "lg" | "ll" | "bp" -> ()
  | "B" | "I" -> in_font m (font_of name.[0]) args
  | "L" ->
      if args = [] then begin Roff.set_font roff Doc.Mono; m.one_line <- true end
      else begin let words = quote m (String.concat " " args) in text m words (ends_sentence words) false end
  | "SM" ->
      (* each argument as a line of its own, a size smaller *)
      if args = [] then m.one_line <- true
      else
        List.iter (fun a ->
          let small = List.map (fun (x : Doc.inline) -> match x with Doc.Text (s, w) -> Doc.Text ({ s with size = s.size - 1 }, w) | Doc.Break -> x) (Roff.inlines roff a) in
          text m small (ends_sentence small) (Roff.continues a)) args
  | "RI" | "IR" | "IB" | "RB" | "BR" | "BI" ->
      (* the arguments in the two fonts in turn, nothing between *)
      (* (tmac.an's \%, but for .RI and .IR: the word is not to be cut) *)
      let args = match args with a :: rest when name <> "RI" && name <> "IR" -> ("\\%" ^ a) :: rest | _ -> args in
      let words = List.concat (List.mapi (fun k a -> Roff.inlines_in roff (font_of name.[k mod 2]) a) args) in

      Roff.reset_style roff;
      (* (not .IR of two arguments: tmac.an ends the second with a note
       * for the HTML manual, and troff sees no dot at the end) *)
      text m words ((name <> "IR" || List.length args > 2) && ends_sentence words) (glued args)
  | "LR" ->
      let words = quote m ("\\%" ^ arg 0) @ Roff.inlines_in roff Doc.Roman (arg 1) in
      text m words (ends_sentence words) false
  | "RL" ->
      let words = Roff.inlines_in roff Doc.Roman ("\\%" ^ arg 0) @ quote m (arg 1) @ Roff.inlines_in roff Doc.Roman (arg 2) in
      text m words (ends_sentence words) false
  | "TS" | "PS" | "EQ" ->
      (* not read yet: its lines passed over *)
      Roff.unknown roff ("." ^ name);
      let stop = match name with "TS" -> "TE" | "PS" -> "PE" | _ -> "EN" in
      let rec until () = match Roff.next roff with None -> () | Some (Roff.Request (n, _)) when n = stop -> () | Some _ -> until () in
      until ()
  | _ -> Roff.unknown roff ("." ^ name)

(* a line without the blanks at its end (not one after a backslash) *)
let rec without_end (s : string) : string =
  let n = String.length s in
  if n > 0 && s.[n - 1] = ' ' && not (n > 1 && s.[n - 2] = '\\') then without_end (String.sub s 0 (n - 1)) else s

let line (m : state) (raw : string) =
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
    if words <> [] || not m.fill || m.capture <> Nothing then begin
      text m words (ends_sentence words && not blank) (Roff.continues s);
      if m.started && m.fill then m.blank_end <- blank
    end
  end

(*****************************************************************************)
(* The tree, from the places *)
(*****************************************************************************)

let same (a : float) (b : float) : bool = Float.abs (a -. b) < 0.01

(* where the next thing that is not a space is *)
let rec place (items : item list) : float =
  match items with
  | [] | Head _ :: _ -> 0.
  | Par (k, _) :: _ -> k
  | Tag (k, _, _) :: _ -> k
  | Gap _ :: rest -> place rest

(* [blocks root base items]: the blocks at [base] and to its right, and
 * the items left: the first that is to its left closes it. (At the
 * root nothing is left: what is to the left of the text's margin is
 * an indent of less than nothing.) *)
let rec blocks (root : bool) (base : float) (items : item list) : Doc.block list * item list =
  match items with
  | [] -> ([], [])
  | Head (level, words) :: rest ->
      if not root then ([], items) else let bs, left = blocks root base rest in (Doc.Heading (level, words) :: bs, left)
  | _ ->
      let k = place items in
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
        | Tag (_, to_, tag) :: rest ->
            let body, rest = if to_ > base then blocks false to_ rest else ([], rest) in
            let bs, left = blocks root base rest in
            (Doc.Tagged { tag; width = to_ -. base; body } :: bs, left)
        | _ -> ([], [])

let read (roff : Roff.t) : Doc.t =
  let m = { roff; r = 0.; i = step; pd = 1.; indent = 0.; indent_before = 0.; ti = None; fill = true; tabs = default_tabs; center = 0;
            no_space = false; par = []; started = false; first = 0.; par_tabs = []; sentence = false; glued = false; blank_end = false; capture = Nothing; tag_open = false; one_line = false;
            levels = []; items = []; header = ("", "", "") } in
  let rec go () =
    match Roff.next roff with
    | None -> ()
    | Some (Roff.Request (name, args)) -> request m name args; go ()
    | Some (Roff.Text s) -> line m s; go () in
  go (); break m;
  { header = m.header; body = fst (blocks true 0. (List.rev m.items)) }
