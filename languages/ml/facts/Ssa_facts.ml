(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Ssa_facts.mli *)

(* an atom, quoted: a function's name has a capital, a dot, a <> *)
let quote (s : string) : string =
  let b = Buffer.create (String.length s + 2) in
  Buffer.add_char b '\'';
  String.iter (fun (c : char) -> if c = '\'' || c = '\\' then Buffer.add_char b '\\'; Buffer.add_char b c) s;
  Buffer.add_char b '\'';
  Buffer.contents b

let name (fn : Ssa.func) (kind : char) (n : int) : string = quote (Printf.sprintf "%s:%c%d" fn.name kind n)

let fact (b : Buffer.t) (relation : string) (args : string list) : unit =
  Buffer.add_string b (relation ^ "(" ^ String.concat ", " args ^ ").\n")

let func (fn : Ssa.func) : string =
  let b = Buffer.create 1024 in
  let block (n : int) : string = name fn 'b' n and value (v : Ssa.value) : string = name fn 'v' v in
  fact b "function" [ quote fn.name ];
  if Array.length fn.blocks > 0 then fact b "entry" [ block 0 ];
  Array.iter
    (fun (bl : Ssa.block) ->
      let here = block bl.id and last = name fn 't' bl.id in
      fact b "block" [ here; quote fn.name ];
      List.iter
        (fun (v : Ssa.value) ->
          fact b "phi" [ value v; here ];
          match Hashtbl.find fn.defs v with
          | Ssa.Phi ops -> List.iter (fun ((p, x) : int * Ssa.value) -> fact b "phi_arg" [ value v; block p; value x ]) ops
          | _ -> ())
        bl.phis;
      (* the points, in order: each instruction, then the end *)
      let points : string list = List.map value bl.body @ [ last ] in
      fact b "first" [ here; List.hd points ];
      let rec chain (ps : string list) : unit =
        match ps with
        | p :: (q :: _ as rest) -> fact b "next" [ p; q ]; chain rest
        | _ -> () in
      chain points;
      fact b "last" [ here; last ];
      List.iter
        (fun (v : Ssa.value) ->
          let ins : Ssa.ins = Hashtbl.find fn.defs v in
          fact b "def" [ value v; value v ];
          (match ins with Ssa.Zero -> fact b "zero" [ value v ] | _ -> ());
          List.iter (fun (x : Ssa.value) -> fact b "use" [ value x; value v ]) (Ssa_build.operands ins))
        bl.body;
      let used : Ssa.value list =
        match bl.term with
        | Ssa.Br (v, _, _) | Ssa.Ret v | Ssa.Raise v -> [ v ]
        | Ssa.Tail (_, vs) -> vs
        | Ssa.Jmp _ | Ssa.Try _ -> [] in
      List.iter (fun (x : Ssa.value) -> fact b "use" [ value x; last ]) used;
      let after : int list =
        match bl.term with
        | Ssa.Jmp s -> [ s ]
        | Ssa.Br (_, s, t) | Ssa.Try (_, s, t) -> [ s; t ]
        | Ssa.Ret _ | Ssa.Raise _ | Ssa.Tail _ -> [] in
      List.iter (fun (s : int) -> fact b "succ" [ here; block s ]) after)
    fn.blocks;
  Buffer.contents b

let own (fn : Ssa.func) : string =
  let b = Buffer.create 1024 in
  let block (n : int) : string = name fn 'b' n and value (v : Ssa.value) : string = name fn 'v' v in
  let live_in, live_out = Alloc.liveness fn in
  Array.iteri (fun (n : int) (live : int Set_.t) -> List.iter (fun (v : int) -> fact b "own_live_in" [ value v; block n ]) (Set_.elements live)) live_in;
  Array.iteri (fun (n : int) (live : int Set_.t) -> List.iter (fun (v : int) -> fact b "own_live_out" [ value v; block n ]) (Set_.elements live)) live_out;
  Array.iteri (fun (n : int) (d : int) -> if n <> 0 && d >= 0 then fact b "own_idom" [ block d; block n ]) (Ssa_build.dominators fn);
  Buffer.contents b
