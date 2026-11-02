(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See C_flow.mli *)

(* (was mini-cc's flow_backend) *)
let file (caps : < Cap.open_in; .. >) ~(own : bool) (defs, incs) (file : Fpath.t) :
    (string, string) result =
  let text = Buffer.create 1024 in
  let passes : string list =
    List.filter (fun (p : string) -> p <> "regs") (List.map fst Opti.passes) in
  let init () =
    Check.xcom := Lower.calls64;
    Check.outstring := Emit.outstring;
    Declare.gextern := Emit.gextern;
    Emit.init () in
  let codgen (f : Tree.sym) (body : Tree.stmt) =
    let fn = Opti.run passes (Lower.func f body) in
    Buffer.add_string text (if own then Ir_facts.own fn else Ir_facts.func fn) in
  match C_front.read caps (defs, incs) ~init ~codgen file with
  | Ok () -> Ok (Buffer.contents text)
  | Error m -> Error m
