(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Tree_facts.mli *)

open Scope

let fact (r : string) (args : Closure_facts.arg list) : unit = !Closure_facts.added r args

let kind (e : exp) : string =
  match e with
  | Evar _ -> "var" | Econst _ -> "const" | Elet _ -> "let" | Efunction _ -> "function"
  (* (a && b, a || b: b after a, if at all; not an application) *)
  | Eapply ({ e = Evar (Prim (("%sequand" | "%sequor"), _, _)); _ }, _) ->
      "andor"
  | Eapply _ -> "apply" | Ematch _ -> "match" | Etry _ -> "try" | Etuple _ -> "tuple"
  | Econs _ -> "cons" | Erecord _ -> "record" | Ewith _ -> "with" | Efield _ -> "field"
  | Esetfield _ -> "setfield" | Earray _ -> "array" | Eif _ -> "if" | Eseq _ -> "seq"
  | Ewhile _ -> "while" | Efor _ -> "for" | Eassert _ -> "assert"
  | Econstraint _ -> "constraint"

(* an expression's children, in the text's order *)
let children (e : exp) : expr list =
  let cases (cs : case list) =
    List.concat_map (fun ((_, g, b) : case) -> Option.to_list g @ [ b ]) cs in
  match e with
  | Evar _ | Econst _ -> []
  | Elet (_, bs, body) -> List.map snd bs @ [ body ]
  | Efunction cs -> cases cs
  | Eapply (f, args) -> f :: args
  | Ematch (x, cs) | Etry (x, cs) -> x :: cases cs
  | Etuple es | Econs (_, es) | Earray es -> es
  | Erecord (_, fs) -> List.map snd fs
  | Ewith (x, _, fs) -> x :: List.map snd fs
  | Efield (x, _) | Eassert x | Econstraint (x, _) -> [ x ]
  | Esetfield (x, _, v) -> [ x; v ]
  | Eif (c, a, b) -> c :: a :: Option.to_list b
  | Eseq (a, b) | Ewhile (a, b) -> [ a; b ]
  | Efor (_, lo, hi, _, body) -> [ lo; hi; body ]

let unit_ (name : string) (text : string) (items : item list) : unit =
  let count = ref 0 in
  (* each line's first offset *)
  let starts = ref [ 0 ] in
  String.iteri (fun (i : int) (c : char) -> if c = '\n' then starts := (i + 1) :: !starts) text;
  let starts = Array.of_list (List.rev !starts) in
  let line_of (off : int) : int =
    (* (the last start at or before off: a binary search) *)
    let rec go lo hi = if lo >= hi then lo else
        let mid = (lo + hi + 1) / 2 in if starts.(mid) <= off then go mid hi else go lo (mid - 1) in
    go 0 (Array.length starts - 1) in
  let rec walk (x : expr) : string =
    incr count;
    let n = Printf.sprintf "%s:e%d" name !count in
    let a, _ = x.span in
    fact "expr" [ Sym n; Sym (kind x.e) ];
    (* (an application by its function's span, as Closure_facts' site_key) *)
    (match x.e with
     | Eapply (f, _) ->
         let a, b = f.span in
         fact "tree_site" [ Sym n; Sym (Printf.sprintf "%s:%d-%d" name a b) ]
     | _ -> ());
    if a >= 0 && a < String.length text then begin
      let l = line_of a in
      let col = a - starts.(l) in
      fact "pos" [ Sym n; Num (l + 1); Num col ];
      (* (nothing but blanks before it on its line) *)
      let lead = ref true in
      for i = starts.(l) to a - 1 do if text.[i] <> ' ' && text.[i] <> '\t' then lead := false done;
      if !lead then fact "leading" [ Sym n ]
    end;
    List.iteri (fun (k : int) (c : expr) -> fact "child" [ Sym n; Num k; Sym (walk c) ]) (children x.e);
    n in
  List.iter
    (fun (i : item) ->
      match i with
      | Ieval e -> ignore (walk e)
      | Ivalue (_, bs, _) -> List.iter (fun ((_, e) : pattern * expr) -> ignore (walk e)) bs
      | Iexception _ | Iexternal _ -> ())
    items
