(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* See Pp.mli *)

exception Error of int * string

type mli = { mli_file : string; mli_text : string; mli_decls : Ast.type_decl list }

let error line fmt = Printf.ksprintf (fun m -> raise (Error (line, m))) fmt

(*****************************************************************************)
(* The output *)
(*****************************************************************************)

(* line: the source's line the output's current line is (0: none, after
 * generated lines); col: the output's column *)
type out = { buf : Buffer.t; mutable file : string; mutable line : int; mutable col : int }

(* s's lines and its last line's length *)
let advance o s =
  match String.rindex_opt s '\n' with
  | None -> o.col <- o.col + String.length s
  | Some i -> o.line <- o.line + List.length (String.split_on_char '\n' s) - 1; o.col <- String.length s - i - 1

(* generated text: after a newline, the output is no line of the source *)
let add o s =
  Buffer.add_string o.buf s;
  advance o s;
  if String.contains s '\n' then o.line <- 0

let directive o file line =
  if o.col > 0 || Buffer.length o.buf = 0 then Buffer.add_char o.buf '\n';
  Buffer.add_string o.buf (Printf.sprintf "# %d %S\n" line file);
  o.file <- file; o.line <- line; o.col <- 0

(* a text's line and column at an offset *)
let position text ofs =
  let line = ref 1 and bol = ref 0 in
  for i = 0 to ofs - 1 do if text.[i] = '\n' then (incr line; bol := i + 1) done;
  !line, ofs - !bol

(* text's [a, b), at its place: on the output's line when it is that
 * line of the file, else after a # line; then at its column *)
let rec copy o file text (a, b) =
  let line, col = position text a in
  let rec blanks i = i < b && (text.[i] = ' ' || text.[i] = '\t') && blanks (i + 1) || (i < b && text.[i] = '\n') in
  let rec eol i = if text.[i] = '\n' then i else eol (i + 1) in
  (* only blanks left on a line after generated text: its newline *)
  if a < b && o.file = file && o.line = line && o.col > col && blanks a then begin
    let i = eol a in
    Buffer.add_char o.buf '\n';
    o.line <- line + 1; o.col <- 0;
    copy o file text (i + 1, b)
  end
  else if a < b then begin
    if o.file <> file || o.line <> line || o.col > col then directive o file line;
    Buffer.add_string o.buf (String.make (col - o.col) ' ');
    o.col <- col;
    let s = String.sub text a (b - a) in
    Buffer.add_string o.buf s;
    advance o s
  end

(* what replaces a stretch of the text *)
type piece =
  | Gen of string
  | Copy of string * string * Ast.span          (* a file, its text, the stretch *)
  | Gen_lines of int * string                   (* generated lines, the first that line *)

let rewrite file text edits =
  let edits = List.sort (fun (a, _, _) (b, _, _) -> compare a b) edits in
  let o = { buf = Buffer.create (String.length text * 2); file; line = 1; col = 0 } in
  let last =
    List.fold_left (fun pos (a, b, pieces) ->
      if a < pos then error (fst (position text a)) "two of mlpp's constructs overlap";
      copy o file text (pos, a);
      List.iter (function
        | Gen s -> add o s
        | Copy (f, t, span) -> copy o f t span
        | Gen_lines (line, s) -> directive o file line; add o s) pieces;
      b) 0 edits
  in
  copy o file text (last, String.length text);
  Buffer.contents o.buf

(*****************************************************************************)
(* The constructs *)
(*****************************************************************************)

let is_ident c = c = '_' || c = '\'' || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')

(* whether x is used in text[a, b): a word, not a label after a dot; so
 * that the rewrite binds only those (an unused let is an error in dune's
 * default profile) *)
let mentions text (a, b) x =
  let n = String.length x in
  let rec from i =
    i + n <= b
    && ((String.sub text i n = x
        && (i = a || (not (is_ident text.[i - 1]) && text.[i - 1] <> '.'))
        && (i + n = b || not (is_ident text.[i + n])))
       || from (i + 1))
  in
  from a

let lets binds = if binds = [] then "" else "let " ^ String.concat " and " (List.map (fun (x, e) -> x ^ " = " ^ e) binds) ^ " in "

(* | [%bits "..."] when g -> body, as
 * | __bits when <tests> && (let <g's fields> in (g)) -> let <body's> in body *)
let bits_clause file text (payload, line, (a, _)) (guard : Ast.expr option) (body : Ast.expr) =
  let tests, binds = try Bits.pattern payload "__bits" with Bits.Error m -> error line "[%%bits]: %s" m in
  let used span = List.filter (fun (x, _) -> mentions text span x) binds in
  let tests = if tests = "" then [] else [ tests ] in
  let pieces =
    match guard with
    | None -> [ Gen ("__bits" ^ (if tests = [] then "" else " when " ^ List.hd tests) ^ " -> " ^ lets (used body.espan)) ]
    | Some g ->
        [ Gen ("__bits when " ^ String.concat "" (List.map (fun t -> t ^ " && ") tests) ^ "(" ^ lets (used g.espan) ^ "(");
          Copy (file, text, g.espan); Gen (")) -> " ^ lets (used body.espan)) ]
  in
  (a, fst body.espan, pieces)

let the_mli mli (d : Ast.type_decl) = match mli () with Some m -> m | None -> error d.tloc "type %s = _: no .mli" d.tname

let find_decl (m : mli) (d : Ast.type_decl) =
  match List.filter (fun (d' : Ast.type_decl) -> d'.tname = d.tname) m.mli_decls with
  | [ d' ] -> d'
  | [] -> error d.tloc "type %s = _: %s declares no %s" d.tname m.mli_file d.tname
  | _ -> error d.tloc "type %s = _: %s declares several %s" d.tname m.mli_file d.tname

(* type t = _: the .mli's "= ...", its lines joined, on the hole's line:
 * so that an error in it, or merlin's go-to-definition of one of its
 * constructors, names the hole (merlin takes a # line's line, not its
 * file) *)
let hole mli (d : Ast.type_decl) =
  let m = the_mli mli d in
  let d' = find_decl m d in
  if d'.tkind = Abstract && d'.tmanifest = None then
    error d.tloc "type %s = _: abstract in %s, the .ml must say what it is" d.tname m.mli_file;
  if d'.tparams <> d.tparams then error d.tloc "type %s = _: not the parameters of %s's" d.tname m.mli_file;
  let a, b = d'.tspan in
  (fst d.tspan, snd d.tspan, [ Gen (String.map (fun c -> if c = '\n' then ' ' else c) (String.sub m.mli_text a (b - a))) ])

let is_mli file = Filename.check_suffix file ".mli"

(* a group of types: its holes, its derivings (of the .mli's
 * declarations, for a hole) *)
let types file mli (ds : Ast.type_decl list) =
  let holes =
    List.filter_map (fun (d : Ast.type_decl) ->
      if d.tkind <> Hole then None
      else if is_mli file then error d.tloc "type %s = _: in a .ml, not a .mli" d.tname
      else Some (hole mli d)) ds
  in
  (* the others, [@@unboxed]..., are OCaml's: left in the text *)
  let deriving (a : Ast.attribute) =
    if a.aname <> "deriving" then []
    else
    List.map (fun name ->
      if name <> "show" then error a.aloc "[@@deriving %s]: only show" name;
      let ds = List.map (fun (d : Ast.type_decl) -> if d.tkind = Hole then find_decl (the_mli mli d) d else d) ds in
      let code = try if is_mli file then Derive.show_sig ds else Derive.show ds with Derive.Error m -> error a.aloc "%s" m in
      (a.aend, a.aend, [ Gen_lines (a.aloc, code) ])) a.aargs
  in
  holes @ List.concat_map (fun (d : Ast.type_decl) -> List.concat_map deriving d.tattrs) ds

(*****************************************************************************)
(* The tree's constructs *)
(*****************************************************************************)

let rec no_bits (p : Ast.pattern) =
  match p.p with
  | Pextension (n, _, _) -> error p.ploc "[%%%s]: only as a clause's whole pattern" n
  | Palias (p, _) | Pconstruct (_, Some p) | Pconstraint (p, _) -> no_bits p
  | Ptuple ps -> List.iter no_bits ps
  | Precord fs -> List.iter (fun (_, p) -> no_bits p) fs
  | Por (a, b) -> no_bits a; no_bits b
  | Pany | Pvar _ | Pconst _ | Prange _ | Pconstruct (_, None) -> ()

let rec expr file text (e : Ast.expr) =
  let exs = List.concat_map (expr file text) in
  match e.e with
  | Eextension ("bits", payload, span) ->
      [ (fst span, snd span, [ Gen (try Bits.expr payload with Bits.Error m -> error e.eloc "[%%bits]: %s" m) ]) ]
  | Eextension (n, _, _) -> error e.eloc "[%%%s]: not one of mlpp's" n
  | Eident _ | Econst _ -> []
  | Elet (_, bs, b) -> List.iter (fun (p, _) -> no_bits p) bs; exs (List.map snd bs @ [ b ])
  | Efunction cs -> cases file text cs
  | Ematch (e, cs) | Etry (e, cs) -> exs [ e ] @ cases file text cs
  | Eapply (f, args) -> exs (f :: args)
  | Etuple es | Earray es -> exs es
  | Econstruct (_, arg) -> exs (Option.to_list arg)
  | Erecord fs -> exs (List.map snd fs)
  | Ewith (e, fs) -> exs (e :: List.map snd fs)
  | Efield (e, _) | Econstraint (e, _) | Eassert e -> exs [ e ]
  | Esetfield (a, _, b) | Eseq (a, b) | Ewhile (a, b) -> exs [ a; b ]
  | Eif (c, a, b) -> exs (c :: a :: Option.to_list b)
  | Efor (_, a, b, _, body) -> exs [ a; b; body ]

and cases file text cs =
  List.concat_map (fun ((p : Ast.pattern), g, body) ->
    let inside = List.concat_map (expr file text) (Option.to_list g @ [ body ]) in
    match p.p with
    | Pextension ("bits", payload, span) -> bits_clause file text (payload, p.ploc, span) g body :: inside
    | _ -> no_bits p; inside) cs

let rec structure file text mli (items : Ast.structure) =
  List.concat_map (fun (it : Ast.item) ->
    match it.i with
    | Ieval e -> expr file text e
    | Ivalue (_, bs) -> List.iter (fun (p, _) -> no_bits p) bs; List.concat_map (fun (_, e) -> expr file text e) bs
    | Itype ds -> types file mli ds
    | Imodule (_, m) -> module_expr file text mli m
    | Iexternal _ | Iexception _ | Iopen _ -> []) items

and module_expr file text mli (m : Ast.module_expr) =
  match m with
  | Mstruct items -> structure file text mli items
  | Mconstraint (m, _) -> module_expr file text mli m
  | Mident _ -> []

let rec signature file mli (items : Ast.signature) =
  List.concat_map (fun (it : Ast.sig_item) ->
    match it.s with
    | Stype ds -> types file mli ds
    | Smodule (_, MTsig s) -> signature file mli s
    | Sval _ | Sexternal _ | Sexception _ | Smodule _ | Sopen _ -> []) items

let file ~file text tree ~mli =
  let edits = match (tree : Ast.source) with Structure s -> structure file text mli s | Signature s -> signature file mli s in
  if edits = [] then text else rewrite file text edits

(*****************************************************************************)
(* Without parsing *)
(*****************************************************************************)

let contains s sub =
  let n = String.length sub in
  let rec from i = i + n <= String.length s && (String.sub s i n = sub || from (i + 1)) in
  from 0

(* [%bits, [@@deriving, or a line type ... = _ (and ... = _) *)
let has_constructs text =
  let hole line =
    let l = String.trim line in
    (String.starts_with ~prefix:"type " l || String.starts_with ~prefix:"and " l)
    && List.exists (fun e -> String.ends_with ~suffix:e l || contains l (e ^ " ")) [ "= _" ]
  in
  contains text "[%bits" || contains text "[@@deriving" || List.exists hole (String.split_on_char '\n' text)
