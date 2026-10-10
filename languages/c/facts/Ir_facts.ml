(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Ir_facts.mli *)

let quote (s : string) : string =
  let b = Buffer.create (String.length s + 2) in
  Buffer.add_char b '\'';
  String.iter (fun (c : char) -> if c = '\'' || c = '\\' then Buffer.add_char b '\\'; Buffer.add_char b c) s;
  Buffer.add_char b '\'';
  Buffer.contents b

let fact (b : Buffer.t) (relation : string) (args : string list) : unit =
  Buffer.add_string b (relation ^ "(" ^ String.concat ", " args ^ ").\n")

let point (fn : Ir.func) (i : int) : string = quote (Printf.sprintf "%s:%d" fn.name.name i)

let variable (fn : Ir.func) (m : Ir.mem) : string =
  let name : string = match m.name with Some (n : Asm.name) -> n.sym | None -> "" in
  quote (Printf.sprintf "%s:%s/%Ld" fn.name.name name m.off)

let func (fn : Ir.func) : string =
  let b = Buffer.create 1024 in
  let code : Ir.t array = Array.of_list fn.code in
  let vars : Ir.mem list = List.map fst (Opti.variables code) in
  let named (m : Ir.mem) : string list = if List.mem m vars then [ variable fn m ] else [] in
  fact b "function" [ quote fn.name.name ];
  let succ : int list array = Opti.successors code in
  Array.iteri
    (fun (i : int) (ins : Ir.t) ->
      let here = point fn i in
      fact b "point" [ here; quote fn.name.name ];
      List.iter (fun (j : int) -> fact b "succ" [ here; point fn j ]) succ.(i);
      match ins with
      | Ir.LoadAt (m, _) -> List.iter (fun (v : string) -> fact b "use" [ v; here ]) (named m)
      | Ir.StoreAt (m, _) | Ir.PutAt (m, _) -> List.iter (fun (v : string) -> fact b "def" [ v; here ]) (named m)
      | Ir.Call _ -> fact b "call" [ here ]
      | _ -> ())
    code;
  Buffer.contents b

let own (fn : Ir.func) : string =
  let b = Buffer.create 1024 in
  let code : Ir.t array = Array.of_list fn.code in
  let vars : Ir.mem array = Array.of_list (List.map fst (Opti.variables code)) in
  let index (m : Ir.mem) : int option =
    let rec go (i : int) : int option = if i >= Array.length vars then None else if vars.(i) = m then Some i else go (i + 1) in
    go 0 in
  let live : int Set_.t array = Opti.liveness code (Opti.successors code) index in
  Array.iteri
    (fun (i : int) (s : int Set_.t) -> List.iter (fun (v : int) -> fact b "own_live_out" [ variable fn vars.(v); point fn i ]) (Set_.elements s))
    live;
  Buffer.contents b
