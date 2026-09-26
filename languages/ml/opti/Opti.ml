(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* See Opti.mli *)

open Lower

(*****************************************************************************)
(* tails: a self tail call is a jump into the body *)
(*****************************************************************************)

(* a label no function of the unit uses (Lower numbers them across the
 * unit, and the assembler's labels are the file's) *)
let labels = ref 0
let label () = incr labels; !labels

let highest (u : unit_) =
  List.fold_left (fun m (f : func) ->
    List.fold_left (fun m -> function Label l | Jmp l | Jz l | Jnz l | TryEnter (_, l) -> max m l | _ -> m) m f.code) 0 u.funcs

(* the closure and the arguments all pushed, then stored into the
 * parameters' slots from the last (so that f b a finds a and b), then a
 * jump to the body's first instruction, past the prologue *)
let tails (f : func) =
  let body = label () in
  let self = ref false in
  let code =
    List.concat_map (function
      | Call (Direct g, slots, true) when g = f.name && List.length slots = f.nparams + 1 ->
          self := true;
          List.map (fun s -> Get s) slots @ List.init (f.nparams + 1) (fun i -> Set (f.nparams - i)) @ [ Jmp body ]
      | i -> [ i ]) f.code
  in
  if !self then { f with code = Label body :: code } else f

(*****************************************************************************)
(* eqs: an equality with an integer, the words compared *)
(*****************************************************************************)

(* a tagged integer equals only itself, and a block (a pointer, even)
 * never equals one: so x = 0 needs no test that x is an integer, nor
 * the runtime's compare; an order would (a pointer against an integer
 * is the address's), so only = and <> *)
let eqs (f : func) =
  let rec go = function
    | Int n :: Op (Poly ((Eq | Ne) as r)) :: rest -> Int n :: Op (Cmp r) :: go rest
    (* either side: the constant pushed first, then a variable *)
    | Int n :: ((Get _ | GetG _) as v) :: Op (Poly ((Eq | Ne) as r)) :: rest -> Int n :: v :: Op (Cmp r) :: go rest
    | i :: rest -> i :: go rest
    | [] -> []
  in
  { f with code = go f.code }

(*****************************************************************************)
(* The passes *)
(*****************************************************************************)

let passes = [ "tails", tails; "eqs", eqs ]

let run names (u : unit_) =
  labels := highest u;
  let pass f (name, p) = if List.mem name names then p f else f in
  { u with funcs = List.map (fun f -> List.fold_left pass f passes) u.funcs }
