(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Safe.mli *)

let allowed = [
  "Pervasives"; "List"; "Array"; "String"; "Bytes"; "Char"; "Uchar"; "Buffer"; "Printf"; "Format"; "Printexc";
  "Hashtbl"; "Queue"; "Stack"; "Seq"; "Option"; "Result"; "Either"; "Int"; "Int32"; "Int64"; "Bool"; "Float";
  "Fun"; "Random"; "Digest"; "Lexing"; "Parsing"; "Filename";
  "Sip"; "Contract";
]

let check (allowed : string list) (tree : Ast.structure) : (int * string) list =
  let found = ref [] in
  let refuse (line : int) fmt = Printf.ksprintf (fun (m : string) -> found := (line, m) :: !found) fmt in
  (* the modules the program defines itself, wherever: theirs to name *)
  let own = ref [] in
  let rec defined (l : Ast.structure) : unit =
    List.iter (fun (item : Ast.item) ->
      match item.i with
      | Imodule (m, body) -> own := m :: !own; defined_in body
      | _ -> ()) l
  and defined_in (m : Ast.module_expr) : unit =
    match m with
    | Mstruct l -> defined l
    | Mconstraint (m, _) -> defined_in m
    | Mident _ -> ()
  in
  defined tree;
  let a_module (line : int) (m : string) : unit =
    if not (List.mem m allowed || List.mem m !own) then refuse line "module %s is not one a process may name" m in
  (* a name: its module, if it has one, and itself *)
  let name (line : int) (id : Ast.longid) : unit =
    (match id with
     | m :: _ :: _ -> a_module line m
     | _ -> ());
    match List.rev id with
    | x :: _ ->
        if String.length x >= 7 && String.sub x 0 7 = "unsafe_" then refuse line "%s: an unsafe_ name" (String.concat "." id)
        else if x = "input_value" then refuse line "%s reads a value as any type" (String.concat "." id)
    | [] -> ()
  in
  let rec ty (line : int) (t : Ast.ty) : unit =
    match t with
    | Tvar _ -> ()
    | Tarrow (a, b) -> ty line a; ty line b
    | Ttuple l -> List.iter (ty line) l
    | Tconstr (id, l) -> name line id; List.iter (ty line) l
    | Tlabel (_, t) -> ty line t
    | Trecord l -> List.iter (fun ((_, _, t) : string * bool * Ast.ty) -> ty line t) l
    | Tusing _ -> refuse line "[%%using]: an extension"
  in
  let rec pattern (p : Ast.pattern) : unit =
    let line = p.ploc in
    match p.p with
    | Pany | Pvar _ | Pconst _ | Prange _ -> ()
    | Palias (p, _) | Plabel (_, p) | Pexception p -> pattern p
    | Ptuple l -> List.iter pattern l
    | Pconstruct (id, arg) -> name line id; Option.iter pattern arg
    | Precord l -> List.iter (fun ((id, p) : Ast.longid * Ast.pattern) -> name line id; pattern p) l
    | Por (a, b) -> pattern a; pattern b
    | Pconstraint (p, t) -> pattern p; ty line t
    | Pextension (x, _, _) -> refuse line "[%%%s]: an extension" x
    | Pusing _ -> refuse line "[%%using]: an extension"
  in
  let rec expr (e : Ast.expr) : unit =
    let line = e.eloc in
    let fields (l : (Ast.longid * Ast.expr) list) : unit =
      List.iter (fun ((id, e) : Ast.longid * Ast.expr) -> name line id; expr e) l in
    match e.e with
    | Eident id -> name line id
    | Econst _ -> ()
    | Elet (_, l, body) -> List.iter binding l; expr body
    | Efunction l -> cases l
    | Eapply (f, l) -> expr f; List.iter expr l
    | Ematch (e, l) | Etry (e, l) -> expr e; cases l
    | Etuple l | Earray l -> List.iter expr l
    | Econstruct (id, arg) -> name line id; Option.iter expr arg
    | Erecord l -> fields l
    | Ewith (e, l) -> expr e; fields l
    | Efield (e, id) -> expr e; name line id
    | Esetfield (e, id, v) -> expr e; name line id; expr v
    | Eif (c, a, b) -> expr c; expr a; Option.iter expr b
    | Eseq (a, b) | Ewhile (a, b) -> expr a; expr b
    | Efor (_, a, b, _, body) -> expr a; expr b; expr body
    | Econstraint (e, t) -> expr e; ty line t
    | Eassert e | Elabel (_, e) -> expr e
    | Eopen (id, e) -> (match id with m :: _ -> a_module line m | [] -> ()); expr e
    | Eextension (x, _, _) | Equote (x, _, _) -> refuse line "[%%%s]: an extension" x
    | Egenerator (_, e) -> expr e
  and binding ((p, e) : Ast.binding) : unit = pattern p; expr e
  and cases (l : Ast.case list) : unit =
    List.iter (fun ((p, guard, e) : Ast.case) -> pattern p; Option.iter expr guard; expr e) l
  in
  let type_decl (d : Ast.type_decl) : unit =
    Option.iter (ty d.tloc) d.tmanifest;
    match d.tkind with
    | Hole -> refuse d.tloc "[%%mli]: an extension"
    | Abstract -> ()
    | Variant l -> List.iter (fun ((_, args) : string * Ast.ty list) -> List.iter (ty d.tloc) args) l
    | Record l -> List.iter (fun ((_, _, t) : string * bool * Ast.ty) -> ty d.tloc t) l
  in
  let rec structure (l : Ast.structure) : unit =
    List.iter (fun (item : Ast.item) ->
      let line = item.iloc in
      match item.i with
      | Ieval e -> expr e
      | Ivalue (_, l, _) -> List.iter binding l
      | Iexternal (x, _, _) -> refuse line "external %s: a process's code names no C function" x
      | Itype l -> List.iter type_decl l
      | Iexception (_, l) -> List.iter (ty line) l
      | Imodule (_, m) -> module_expr line m
      | Iopen id -> (match id with m :: _ -> a_module line m | [] -> ())) l
  and module_expr (line : int) (m : Ast.module_expr) : unit =
    match m with
    | Mident id -> (match id with m :: _ -> a_module line m | [] -> ())
    | Mstruct l -> structure l
    | Mconstraint (m, t) -> module_expr line m; module_type line t
  and module_type (line : int) (t : Ast.module_type) : unit =
    match t with
    | MTident _ -> ()
    | MTsig l ->
        List.iter (fun (s : Ast.sig_item) ->
          match s.s with
          | Sexternal (x, _, _) -> refuse s.sloc "external %s: a process's code names no C function" x
          | Smodule (_, t) -> module_type line t
          | _ -> ()) l
  in
  structure tree;
  List.stable_sort (fun ((a, _) : int * string) ((b, _) : int * string) -> compare a b) (List.rev !found)
