(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Ms.mli *)

type state = {
  fill : Fill.t;
  roff : Roff.t;
  (* .RS's levels: where the text of each is, the deepest first; and
   * how far right of the deepest an .IP's body is (0: no .IP yet) *)
  mutable levels : float list;
  mutable ip : float;
  (* the sections' numbers, the first level's first *)
  mutable sections : int list;
  (* the lines set in from both sides: an abstract's *)
  mutable inset : float;
  (* a display or a program is being read: what to put back at its end *)
  mutable display : float option;
  (* some text was written: a paragraph has a space before it *)
  mutable begun : bool;
  (* what .FS put aside of the text it interrupts *)
  mutable aside : (Fill.t * Doc.font) option;
}

(* a register of the paper's, a length in ens, or what tmac.s has *)
let ens (m : state) (name : string) (default : float) : float =
  match Roff.register m.roff name with Some u when u <> 0. -> Roff.ens m.roff u | _ -> default

let lines (m : state) (name : string) (default : float) : float =
  match Roff.register m.roff name with Some u -> Roff.lines m.roff u | None -> default

let terminal (m : state) : bool = Roff.device m.roff = Roff.Terminal

(* \n(PI, \n(PD, \n(DV: a paragraph's indent, the space between two
 * paragraphs, and round a display *)
let pi (m : state) = ens m "PI" 5.
let pd (m : state) = lines m "PD" (if terminal m then 1. else 0.3)
let dv (m : state) = lines m "DV" (if terminal m then 1. else 0.5)

let base (m : state) : float = match m.levels with l :: _ -> l | [] -> 0.

(* tmac.s's .RT: what every paragraph starts from: the text's own font
 * and size, filled, at its level's place *)
let reset (m : state) =
  let f = m.fill in
  Fill.break f;
  Roff.reset_style m.roff;
  f.fill <- true; f.center <- 0; f.ti <- None; f.heading <- None;
  f.indent <- base m +. m.inset; f.short <- m.inset

(* a space that is not added to the one before it: after a display's,
 * a paragraph's own is not one more *)
let gap (m : state) (n : float) =
  match m.fill.items with
  | Fill.Gap g :: rest -> if n > g then m.fill.items <- Fill.Gap n :: rest
  | Fill.Close :: Fill.Gap _ :: _ | Fill.Open _ :: Fill.Gap _ :: _ -> ()
  | _ -> Fill.gap m.fill n

(* the space before a paragraph: none before the first *)
let space (m : state) (n : float) = if m.begun then gap m n; m.begun <- true

let text (m : state) (words : Doc.inline list) = Fill.text m.fill words (Fill.ends_sentence words) false

(* .I word after before: the word in a font, with what touches it in
 * the font there was; alone: the font from here on *)
let in_font (m : state) (f : Doc.font) (args : string list) =
  let arg k = match List.nth_opt args k with Some a -> a | None -> "" in
  if args = [] then Roff.set_font m.roff f
  else text m (Roff.inlines m.roff (arg 2) @ Roff.inlines_in m.roff f (arg 0) @ Roff.inlines m.roff (arg 1))

(* a size for a word, or from here on *)
let in_size (m : state) (by : int) (args : string list) =
  let arg k = match List.nth_opt args k with Some a -> a | None -> "" in
  if args = [] then Roff.resize m.roff (if by > 0 then "+2" else "-2")
  else begin
    let small = List.map (fun (x : Doc.inline) -> match x with Doc.Text (s, w) -> Doc.Text ({ s with size = s.size + by }, w) | Doc.Break -> x) (Roff.inlines m.roff (arg 0)) in
    text m (Roff.inlines m.roff (arg 2) @ small @ Roff.inlines m.roff (arg 1))
  end

(* a display starts: its lines as they are, kept on one sheet, [by]
 * further right *)
let display (m : state) (by : float) =
  let f = m.fill in
  Fill.break f; space m (dv m);
  Fill.emit f (Fill.Open Fill.Keep);
  m.display <- Some f.indent;
  f.fill <- false; f.indent <- f.indent +. by

let display_end (m : state) =
  let f = m.fill in
  Fill.break f;
  (match m.display with Some back -> f.indent <- back; Fill.emit f Fill.Close | None -> ());
  m.display <- None;
  f.center <- 0; f.fill <- true; Roff.reset_style m.roff;
  gap m (dv m)

(* the next section's number at a level: "2.", "2.1." *)
let number (m : state) (level : int) : string =
  let rec bump (k : int) (l : int list) : int list =
    match l with
    | n :: rest -> if k = 1 then [ n + 1 ] else n :: bump (k - 1) rest
    | [] -> if k = 1 then [ 1 ] else 1 :: bump (k - 1) [] in
  m.sections <- bump (max 1 level) m.sections;
  String.concat "" (List.map (fun n -> string_of_int n ^ ".") m.sections)

let rec request (m : state) (name : string) (args : string list) =
  let arg k = match List.nth_opt args k with Some a -> a | None -> "" in
  let roff = m.roff and f = m.fill in
  match name with
  (* the title's lines, the authors', their institution's: each in the
   * middle of the line *)
  | "TL" -> reset m; f.center <- 100000; Roff.set_font roff Doc.Bold; if not (terminal m) then Roff.resize roff "+2"; m.begun <- true
  | "AU" -> reset m; gap m 1.; f.center <- 100000; Roff.set_font roff Doc.Italic
  | "AI" -> reset m; gap m 1.; f.center <- 100000
  | "MH" -> text m (Roff.inlines roff "Bell Laboratories"); text m (Roff.inlines roff "Murray Hill, New Jersey 07974")
  | "AB" ->
      reset m; gap m 1.;
      if arg 0 <> "no" && arg 0 <> "-" then begin
        f.center <- 1; Roff.set_font roff Doc.Italic;
        text m (Roff.inlines roff (if arg 0 = "" then "ABSTRACT" else arg 0));
        Roff.reset_style roff; gap m 1.
      end;
      (* (tmac.s's lines of 5/6 of the others, in the middle) *)
      m.inset <- Fill.column f (f.length /. 12.);
      reset m; f.ti <- Some (f.indent +. pi m)
  | "AE" -> reset m; m.inset <- 0.; reset m; gap m 1.
  | "PP" -> reset m; space m (pd m); f.ti <- Some (f.indent +. pi m); m.ip <- 0. +. m.ip
  | "LP" -> reset m; space m (pd m)
  | "QP" ->
      reset m; space m (pd m);
      let q = ens m "QI" 5. in
      f.indent <- f.indent +. q; f.short <- f.short +. q
  | "IP" ->
      reset m; space m (pd m);
      if arg 1 <> "" then m.ip <- Fill.column f (Fill.length f (arg 1));
      if m.ip = 0. then m.ip <- pi m;
      if arg 0 <> "" then begin Fill.emit f (Fill.Tag (f.indent, f.indent +. m.ip, Roff.inlines roff (arg 0))); f.tag_open <- true end;
      f.indent <- f.indent +. m.ip
  | "RS" ->
      (* further right by the .IP's indent if there is one, else by a
       * paragraph's *)
      Fill.break f;
      m.levels <- (base m +. (if m.ip > 0. then m.ip else pi m)) :: m.levels; m.ip <- 0.;
      reset m
  | "RE" -> Fill.break f; (match m.levels with _ :: rest -> m.levels <- rest | [] -> ()); m.ip <- 0.; reset m
  | "SH" | "NH" ->
      reset m; space m 1.;
      Roff.set_font roff Doc.Bold;
      let level = if name = "SH" then 1 else max 1 (int_of_float (Roff.number roff 'u' (if arg 0 = "" then "1" else arg 0))) in
      (* (the paragraph that follows, to the next macro, is the heading) *)
      f.heading <- Some level; m.ip <- 0.;
      if name = "NH" then begin
        text m (Roff.inlines roff (number m level ^ "\\ \\ "));
        f.glued <- true
      end
  (* a display: .DS L at the left, .DS C each line in the middle, else
   * further right (8 letters on a terminal, half an inch on paper) *)
  | "DS" | "ID" | "LD" | "CD" | "BD" ->
      let kind = if name = "DS" then (if arg 0 = "" then "I" else arg 0) else String.sub name 0 1 in
      let by = if arg 1 <> "" then Fill.length f (arg 1) else if terminal m then 8. else 7.2 in
      display m (if kind = "I" then by else 0.);
      if kind = "C" then f.center <- 100000
  | "DE" -> display_end m
  (* a program's text: in its font, two ems right, a tab every 8 letters *)
  | "P1" ->
      display m (if arg 0 <> "" then Fill.length f (arg 0) else if terminal m then 2. else 4.);
      Roff.set_font roff Doc.Mono;
      let w = if terminal m then 8. else 9.6 in
      f.tabs <- List.init 14 (fun k -> w *. float_of_int (k + 1))
  | "P2" -> display_end m
  | "KS" | "KF" -> Fill.break f; Fill.emit f (Fill.Open Fill.Keep)
  | "KE" -> Fill.break f; Fill.emit f Fill.Close
  | "FS" ->
      (* the text it interrupts is put aside, with its font: a footnote
       * is a text of its own, said in the middle of another *)
      m.aside <- Some ({ f with roff = f.roff }, Roff.font roff);
      f.par <- []; f.started <- false; f.glued <- false; f.sentence <- false; f.blank_end <- false; f.capture <- None; f.tag_open <- false;
      f.heading <- None; f.fill <- true; f.center <- 0; f.ti <- None; f.indent <- 0.; f.short <- 0.;
      Roff.reset_style roff;
      Fill.emit f (Fill.Open Fill.Footnote);
      if arg 0 <> "" then text m (Roff.inlines roff (arg 0))
  | "FE" ->
      Fill.break f; Fill.emit f Fill.Close;
      (match m.aside with
       | Some (was, font) ->
           f.par <- was.par; f.started <- was.started; f.first <- was.first; f.par_tabs <- was.par_tabs; f.glued <- was.glued;
           f.sentence <- was.sentence; f.blank_end <- was.blank_end; f.capture <- was.capture; f.tag_open <- was.tag_open;
           f.heading <- was.heading; f.fill <- was.fill; f.center <- was.center; f.ti <- was.ti; f.indent <- was.indent; f.short <- was.short;
           f.no_space <- was.no_space; Roff.reset_style roff; Roff.set_font roff font
       | None -> ());
      m.aside <- None
  | "I" -> in_font m Doc.Italic args
  | "B" -> in_font m Doc.Bold args
  | "CW" -> in_font m Doc.Mono args
  | "BI" | "UL" -> in_font m Doc.Italic args
  | "BX" -> in_font m Doc.Roman args
  | "R" -> if args = [] then Roff.set_font roff Doc.Roman else in_font m Doc.Roman args
  | "SM" -> in_size m (-2) args
  | "LG" -> in_size m 2 args
  | "NL" -> Roff.resize roff ""
  (* what is for another program (Plan 9's ms2html), or has nothing to
   * show here: a font's family, the date, a memorandum's kind *)
  | "HT" | "FP" | "ND" | "DA" | "TM" | "RP" | "AT" | "nm" | "hw" | "bd" | "fp" | "mk" | "rt" -> ()
  | "TS" ->
      Fill.break f;
      let table = Tbl.read roff (fun () -> block m) in
      Fill.emit f (Fill.Whole (f.indent, Doc.Table table)); m.begun <- true
  | "PS" ->
      Fill.break f;
      (* .PS <file: the picture is in a file; .PS 3i: it is 3 inches wide *)
      let all = String.concat "" args in
      let text, width =
        if String.length all > 0 && all.[0] = '<' then
          ((match Roff.load roff (String.trim (String.sub all 1 (String.length all - 1))) with Some t -> t | None -> ""), 0.)
        else begin
          let lines = ref [] in
          let rec until () =
            match Roff.next roff with
            | None | Some (Roff.Request (("PE" | "PF"), _)) -> ()
            | Some (Roff.Text s) -> lines := s :: !lines; until ()
            | Some (Roff.Request (_, _)) -> until () in
          until ();
          let w = let a = arg 0 in if a <> "" && a.[String.length a - 1] = 'i' then String.sub a 0 (String.length a - 1) else a in
          (String.concat "\n" (List.rev !lines), (match float_of_string_opt w with Some v -> v | None -> 0.))
        end in
      (match Pic.read (Roff.load roff) width (fun s -> let w = Roff.inlines roff s in Roff.reset_style roff; w) text with
       | Ok p -> Fill.emit f (Fill.Whole (f.indent, Doc.Picture p)); m.begun <- true
       | Error why -> Roff.unknown roff (".PS (a picture, " ^ why ^ ")"))
  | "EQ" ->
      (* not read yet: its lines passed over *)
      Roff.unknown roff ".EQ";
      let rec until () = match Roff.next roff with None -> () | Some (Roff.Request ("EN", _)) -> () | Some _ -> until () in
      until ()
  | _ -> if not (Fill.request f name args) then Roff.unknown roff ("." ^ name)

(* a table's cell of several lines, to its T}: a text of its own, with
 * the paper's macros in it *)
and block (m : state) : Doc.inline list * string =
  Fill.aside m.fill (fun () ->
    let rec go () : string =
      match Roff.next m.roff with
      | None -> ""
      | Some (Roff.Text s) when String.starts_with ~prefix:"T}" s -> String.sub s 2 (String.length s - 2)
      | Some (Roff.Text s) -> Fill.line m.fill s; go ()
      | Some (Roff.Request (name, args)) -> request m name args; go () in
    go ())

let read (roff : Roff.t) : Doc.t =
  let term = Roff.device roff = Roff.Terminal in
  let length = if term then 60. else 86.4 in
  let step = if term then 5. else 7.2 in
  let m = { fill = Fill.create roff 0. length (List.init 16 (fun k -> step *. float_of_int (k + 1))); roff; levels = []; ip = 0.; sections = [];
            inset = 0.; display = None; begun = false; aside = None } in
  (* tmac.s's strings: the quotation marks, the dash *)
  Roff.set_string roff "Q" (if term then "\"" else "\xe2\x80\x9c");
  Roff.set_string roff "U" (if term then "\"" else "\xe2\x80\x9d");
  Roff.set_string roff "-" (if term then "--" else "\xe2\x80\x94");
  let rec go () =
    match Roff.next roff with
    | None -> ()
    | Some (Roff.Request (name, args)) -> request m name args; go ()
    | Some (Roff.Text s) -> m.begun <- true; Fill.line m.fill s; go () in
  go (); Fill.break m.fill;
  { header = ("", "", ""); width = length; margin = 0.; sub = 0.; body = Fill.tree m.fill }
