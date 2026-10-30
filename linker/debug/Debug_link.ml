(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Debug_link.mli *)

open Program

(* the history's paths, as 5a writes them before the code: each
 * component a File symbol, numbered when it is new; a path is its
 * components' numbers (5l's ldobj's N_FILE, addhist) *)
let history lookup t (o : Asm.obj) =
  List.map (fun (path, line) ->
    let comps = match path with
      | None -> []
      | Some p ->
          (if p <> "" && p.[0] = '/' then [ "/" ] else []) @ List.filter (( <> ) "") (String.split_on_char '/' p) in
    Hist (List.map (fun c ->
      let s : sym = lookup ("<" ^ c) in
      if s.kind <> File then (s.kind <- File; t.nfiles <- t.nfiles + 1; s.value <- t.nfiles);
      s.value) comps, line)) o.history

(* a function's named parameters and locals, each once at its lowest
 * offset, the last met first (5l's inopd); the history before them
 * in the object's first function (histtoauto) *)
let autos history (progs : _ prog option array) =
  let cur = ref None and first = ref None in
  Array.iter (function
    | Some ({ op = Func; _ } as p) -> cur := Some p; if !first = None then first := Some p
    | Some p ->
        Option.iter (fun (f : _ prog) ->
          List.iter (function
            | Asm.Mem { base = (FP | SP) as b; name = Some n; off; _ } | Asm.Addr { base = (FP | SP) as b; name = Some n; off; _ } ->
                let off = Int64.to_int off in
                let same = function Param (m, _) -> b = FP && m = n.sym | Local (m, _) -> b = SP && m = n.sym | Hist _ -> false in
                if List.exists same f.autos then
                  f.autos <- List.map (function Param (m, o) when same (Param (m, o)) -> Param (m, min o off)
                                              | Local (m, o) when same (Local (m, o)) -> Local (m, min o off) | a -> a) f.autos
                else f.autos <- (if b = FP then Param (n.sym, off) else Local (n.sym, off)) :: f.autos
            | _ -> ()) p.args) !cur
    | None -> ()) progs;
  Option.iter (fun (f : _ prog) -> f.autos <- history @ f.autos) !first

(* the objects' acid declarations in the data, .acid, each once in
 * the order met, a string to its NUL *)
let acid_data lookup t =
  if t.acid <> [] then begin
    let seen = Hashtbl.create 1024 in
    let text = String.concat "" (List.filter (fun d ->
      if Hashtbl.mem seen d then false else (Hashtbl.replace seen d (); true)) (List.rev t.acid)) in
    let s : sym = lookup ".acid" in
    s.kind <- Data;
    s.size <- String.length text + 1;
    t.datas <- { dsym = s; off = 0; width = s.size; value = Asm.Str text; dversion = 0 } :: t.datas
  end
