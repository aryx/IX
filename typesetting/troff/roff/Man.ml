(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Man.mli *)

type state = {
  fill : Fill.t;
  roff : Roff.t;
  (* tmac.an's )M: a tag's width when none is said, a .RS's, and the
   * text's own margin: 5 letters on a terminal, 3.6 ems on paper *)
  step : float;
  (* tmac.an's )R and )I: the text's place (.RS), and how far right of
   * it a tagged paragraph's body is *)
  mutable r : float;
  mutable i : float;
  (* the lines between two paragraphs (.PD) *)
  mutable pd : float;
  (* what it is when none is said: a line on a terminal, 0.4 on paper *)
  pd0 : float;
  (* what .RS put aside, the last first: i and r *)
  mutable levels : (float * float) list;
  mutable header : string * string * string;
}

let default_tabs (step : float) : float list = List.init 13 (fun k -> step *. float_of_int (k + 1))

(* tmac.an's }E: the margin back where the text is *)
let margin (m : state) = m.fill.indent <- m.r; Roff.reset_style m.roff

let break (m : state) = Fill.break m.fill
let gap (m : state) (n : float) = Fill.gap m.fill n
let text (m : state) (words : Doc.inline list) (sentence : bool) (glued : bool) = Fill.text m.fill words sentence glued
let ends_sentence = Fill.ends_sentence
let glued = Fill.glued
let length (m : state) (s : string) : float = Fill.length m.fill s
let column (m : state) (x : float) : float = Fill.column m.fill x

let tag_width (m : state) (s : string) = if s <> "" then begin let v = column m (length m s) in m.i <- (if v = 0. then m.step else v) end

(* the next line of text is a section's heading; a tag *)
let heading (m : state) (level : int) (words : Doc.inline list) =
  Fill.emit m.fill (Fill.Head (level, words));
  m.i <- m.step; margin m; m.fill.no_space <- true

let tag (m : state) (words : Doc.inline list) =
  Fill.emit m.fill (Fill.Tag (m.r, m.r +. m.i, words));
  m.fill.indent <- m.r +. m.i; Roff.reset_style m.roff; m.fill.no_space <- false; m.fill.tag_open <- true

let font_of (name : char) : Doc.font = match name with 'I' -> Doc.Italic | 'R' -> Doc.Roman | _ -> Doc.Mono

(* arguments set in a font, a space between: .B, .I. (No sentence
 * ends there for troff: tmac.an writes its six arguments, and the
 * blanks between those not given are at the line's end.) *)
let in_font (m : state) (f : Doc.font) (args : string list) =
  if args = [] then begin Roff.set_font m.roff f; m.fill.one_line <- true end
  else begin
    Roff.set_font m.roff f;
    (* (.B's first word is not to be cut: tmac.an's \%) *)
    (* (tmac.an writes its six arguments with a blank between: those
     * not given leave blanks at the line's end, which count when the
     * line is centered) *)
    let blanks = if m.fill.center > 0 then String.concat "" (List.init (max 0 (6 - List.length args)) (fun _ -> "\\ ")) else "" in
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
      break m; m.pd <- m.pd0; gap m m.pd;
      m.r <- 0.; m.levels <- []; m.fill.fill <- true; m.fill.ti <- None;
      Roff.reset_style roff; Roff.set_font roff Doc.Bold;
      m.fill.capture <- Some (heading m (if name = "SH" then 1 else 2));
      if args <> [] then text m (Roff.inlines roff (String.concat " " args)) false false
  | "PP" | "LP" | "P" -> break m; gap m m.pd; m.i <- m.step; margin m; m.fill.no_space <- true
  | "PD" -> m.pd <- (if arg 0 = "" then m.pd0 else Roff.lines roff (Roff.number roff 'v' (arg 0)))
  | "TP" ->
      tag_width m (arg 0);
      break m; gap m m.pd; m.fill.indent <- m.r; m.fill.no_space <- true; m.fill.capture <- Some (tag m)
  | "IP" ->
      if arg 0 <> "" then begin
        request m "TP" [ arg 1 ];
        text m (Roff.inlines roff (arg 0)) false false
      end
      else begin break m; gap m m.pd; tag_width m (arg 1); Roff.reset_style roff; m.fill.indent <- m.r +. m.i end
  | "HP" ->
      break m; gap m m.pd; tag_width m (arg 0);
      m.fill.indent <- m.r +. m.i; m.fill.ti <- Some m.r; Roff.reset_style roff
  | "TF" ->
      (* a list of names as wide as the widest, closed up *)
      request m "IP" [ ""; "\\w'" ^ arg 0 ^ "\\ \\ 'u" ]; m.pd <- 0.
  | "RS" ->
      break m;
      m.levels <- (m.i, m.r) :: m.levels;
      m.r <- m.r +. (if arg 0 = "" then m.i else column m (length m (arg 0)));
      m.i <- m.step; margin m
  | "RE" ->
      break m;
      (* .RE 2: back to what it was before the second .RS *)
      let keep = if arg 0 = "" then List.length m.levels - 1 else max 0 (int_of_float (Roff.number roff 'u' (arg 0)) - 1) in
      let rec pop () =
        match m.levels with
        | (i, r) :: rest when List.length m.levels > keep -> m.i <- i; m.r <- r; m.levels <- rest; pop ()
        | _ -> () in
      pop (); margin m
  | "EX" -> break m; m.fill.fill <- false; if Roff.device roff = Roff.Typesetter then Roff.set_font roff Doc.Mono
  | "EE" -> break m; m.fill.fill <- true; Roff.reset_style roff
  | "DT" -> if m.fill.started && not m.fill.fill then break m; m.fill.tabs <- default_tabs m.step
  (* (the size and the line's length are tmac.an's own business) *)
  | "ps" | "ll" -> ()
  | "B" | "I" -> in_font m (font_of name.[0]) args
  | "L" ->
      if args = [] then begin Roff.set_font roff Doc.Mono; m.fill.one_line <- true end
      else begin let words = quote m (String.concat " " args) in text m words (ends_sentence words) false end
  | "SM" ->
      (* each argument as a line of its own, a size smaller *)
      if args = [] then m.fill.one_line <- true
      else
        List.iter (fun a ->
          let small = List.map (fun (x : Doc.inline) -> match x with Doc.Text (s, w) -> Doc.Text ({ s with size = s.size - 1 }, w) | Doc.Break | Doc.Page _ -> x) (Roff.inlines roff a) in
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
  | "TS" ->
      break m;
      let table = Tbl.read roff (fun () -> block m) in
      Fill.emit m.fill (Fill.Whole (m.fill.indent, Doc.Table table))
  | "PS" ->
      break m; let f = m.fill in
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
       | Ok p -> Fill.emit f (Fill.Whole (f.indent, Doc.Picture p)); ()
       | Error why -> Roff.unknown roff (".PS (a picture, " ^ why ^ ")"))
  | "EQ" ->
      (* not read yet: its lines passed over *)
      Roff.unknown roff ".EQ";
      let rec until () = match Roff.next roff with None -> () | Some (Roff.Request ("EN", _)) -> () | Some _ -> until () in
      until ()
  | _ -> if not (Fill.request m.fill name args) then Roff.unknown roff ("." ^ name)

(* a table's cell of several lines, to its T} *)
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
  let terminal = Roff.device roff = Roff.Terminal in
  let step = if terminal then 5. else 7.2 and pd0 = if terminal then 1. else 0.4 in
  let m = { fill = Fill.create roff step (if terminal then 65. else 93.6) (default_tabs step); roff; step; r = 0.; i = step; pd = pd0; pd0;
            levels = []; header = ("", "", "") } in
  let rec go () =
    match Roff.next roff with
    | None -> ()
    | Some (Roff.Request (name, args)) -> request m name args; go ()
    | Some (Roff.Text s) -> Fill.line m.fill s; go () in
  go (); break m;
  { header = m.header; width = (if terminal then 65. else 93.6); margin = step; sub = 3.; body = Fill.tree m.fill }
