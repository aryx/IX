(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Latex_output.mli *)

open Latex_state

let fresh () : out = { blocks = []; line = []; feet = [] }

let mono_of (style : Doc.style) : Doc.style = { style with font = Doc.Mono }

(* the document's lengths are in ens, a source's in a terminal's
 * columns, ten to the inch: 1.44 ens of a text of 10 points *)
let cols (t : t) (n : float) : float = if t.paper then n *. 1.44 else n

let gap (t : t) : float = if t.paper then 0.3 else 1.

let say (t : t) (what : string) =
  if t.final then begin
    let file, line = Latex_input.place t in
    t.said <- (line, (if file = "" then "" else file ^ ": ") ^ what) :: t.said
  end

(* (once: a book has the same command a thousand times) *)
let say_once (t : t) (what : string) =
  if not (Hashtbl.mem t.unknown what) then begin Hashtbl.replace t.unknown what true; say t what end

let text (t : t) (s : string) =
  if s <> "" && t.body then begin
    let style = if t.look.caps then { t.look.style with size = t.look.style.size - 2 } else t.look.style in
    let s = if t.look.caps then String.uppercase_ascii s else s in
    match t.out.line with
    | Doc.Text (st, p) :: rest when st = style -> t.out.line <- Doc.Text (st, p ^ s) :: rest
    | _ -> t.out.line <- Doc.Text (style, s) :: t.out.line
  end

let put (t : t) (i : Doc.inline) = if t.body then t.out.line <- i :: t.out.line

(* a space, unless the line is at its start or has one *)
let space (t : t) =
  match t.out.line with
  | [] | Doc.Break :: _ -> ()
  | Doc.Text (_, p) :: _ when p <> "" && p.[String.length p - 1] = ' ' -> ()
  | _ -> text t " "

let emit (t : t) (b : Doc.block) = if t.body then t.out.blocks <- b :: t.out.blocks

(* a block after a blank, when it is not the first *)
let block (t : t) (b : Doc.block) =
  if t.body then begin
    (match t.out.blocks with [] | Doc.Space _ :: _ | Doc.Heading _ :: _ -> () | _ -> emit t (Doc.Space (gap t)));
    emit t b
  end

let blank_line (l : Doc.inline list) : bool =
  List.for_all (fun (i : Doc.inline) -> match i with Doc.Text (_, s) -> String.trim s = "" | Doc.Break -> true) l

(* the paragraph being filled is ended *)
let par (t : t) =
  let l = match t.out.line with Doc.Text (st, p) :: rest when p <> "" && p.[String.length p - 1] = ' ' -> Doc.Text (st, String.sub p 0 (String.length p - 1)) :: rest | l -> l in
  t.out.line <- [];
  if not (blank_line l) then begin
    let p : Doc.par = { fill = true; first = 0.; short = 0.; tabs = []; center = t.look.center; body = List.rev l } in
    block t (Doc.Para p)
  end;
  t.out.blocks <- t.out.feet @ t.out.blocks;
  t.out.feet <- []

(* lines as they are, in the typed font: a display, a chunk *)
let lines_as_they_are (t : t) (size : int) (lines : Doc.inline list list) : Doc.block =
  let body = List.concat (List.mapi (fun k l -> if k > 0 then Doc.Break :: l else l) lines) in
  let stop = (if t.paper then 9.6 else 8.) *. float_of_int (10 + (if t.paper then size else 0)) /. 10. in
  let p : Doc.par = { fill = false; first = 0.; short = 0.; tabs = List.init 20 (fun k -> stop *. float_of_int (k + 1)); center = false; body } in
  Doc.Para p

(* ---------------------------------------------------------------- *)
(* A text read apart *)
(* ---------------------------------------------------------------- *)

(* a text read apart, where it is written *)
let capture (t : t) (raw : string) =
  t.input <- { s = raw; i = 0; stop = true; file = ""; line = 1; counts = false } :: t.input;
  let groups = t.groups and envs = t.envs in
  t.run t;
  t.groups <- groups;
  t.envs <- envs;
  (match t.input with f :: rest when f.stop -> t.input <- rest | _ -> ())

(* a text read apart: its paragraph *)
let inlines_of (t : t) (raw : string) : Doc.inline list =
  let saved = t.out and look = t.look in
  t.out <- fresh ();
  capture t raw;
  let l = List.rev t.out.line in
  (* (a text of several paragraphs, where one is wanted: its words) *)
  let before = List.concat_map (fun (b : Doc.block) -> match b with Doc.Para p -> p.body @ [ Doc.Text (look.style, " ") ] | _ -> []) (List.rev t.out.blocks) in
  saved.feet <- t.out.feet @ List.filter (fun (b : Doc.block) -> match b with Doc.Footnote _ -> true | _ -> false) t.out.blocks @ saved.feet;
  t.out <- saved;
  t.look <- look;
  before @ l

let with_look (t : t) (look : look) (raw : string) : Doc.inline list =
  let saved = t.look in
  t.look <- look;
  let l = inlines_of t raw in
  t.look <- saved;
  l
