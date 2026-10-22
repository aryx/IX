(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Opti.mli *)

open Ir

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
  (* more than the stack's registers (arm's 8: "an expression too
   * deep"): each through a slot of its own, after the frame's *)
  let many = f.nparams + 1 > 7 in
  let code =
    List.concat_map (function
      | Call (Direct g, slots, true) when g = f.name && List.length slots = f.nparams + 1 ->
          self := true;
          if many then
            List.concat (List.mapi (fun i s -> [ Get s; Set (f.nslots + i) ]) slots)
            @ List.concat (List.init (f.nparams + 1) (fun i -> [ Get (f.nslots + i); Set i ])) @ [ Jmp body ]
          else List.map (fun s -> Get s) slots @ List.init (f.nparams + 1) (fun i -> Set (f.nparams - i)) @ [ Jmp body ]
      | i -> [ i ]) f.code
  in
  if !self then { f with code = Label body :: code; nslots = (if many then f.nslots + f.nparams + 1 else f.nslots) } else f

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
(* refs: a ref that does not escape, a variable *)
(*****************************************************************************)

(* ocaml-light's Simplif.eliminate_ref, on the stack code: a slot set
 * once, by a new block of one field (ref e), whose every read is the
 * field's (!r) or a store into it (r := e), is that field itself; and so
 * is a copy of it into another slot (incr r inlined: the parameter's
 * slot), set once, read the same way. A read of any other kind (r
 * passed to a function, captured by a closure, compared by ==) and it
 * stays a block. Then a loop's counter is a slot, and in ssa/ a register
 * (tests/bench/pixels.ml's o, limbs.ml's c), not a word of the heap read
 * and written at each turn. *)
let refs (f : func) =
  let sets = Hashtbl.create 16 and banned = Hashtbl.create 16 in
  for i = 0 to f.nparams do Hashtbl.replace banned i () done;
  List.iter (function
    | Set s -> Hashtbl.replace sets s (1 + match Hashtbl.find_opt sets s with Some n -> n | None -> 0)
    | Call (_, slots, _) -> List.iter (fun s -> Hashtbl.replace banned s ()) slots
    | _ -> ()) f.code;
  let once s = Hashtbl.find_opt sets s = Some 1 && not (Hashtbl.mem banned s) in
  (* the refs, and the copies of one (a copy's slot, its ref's) *)
  let owner = Hashtbl.create 16 in
  let rec find = function
    | Alloc (0, 1) :: (Set s :: _ as rest) -> if once s then Hashtbl.replace owner s s; find rest
    | Get s :: (Set t :: _ as rest) -> (match Hashtbl.find_opt owner s with Some r when r = s && once t -> Hashtbl.replace owner t s | _ -> ()); find rest
    | _ :: rest -> find rest
    | [] -> ()
  in
  find f.code;
  (* a read of another kind: the ref and its copies stay blocks *)
  let drop s = match Hashtbl.find_opt owner s with
    | Some r -> List.iter (Hashtbl.remove owner) (Hashtbl.fold (fun t r' acc -> if r' = r then t :: acc else acc) owner [])
    | None -> () in
  let rec check = function
    | Get _ :: (Field 0 | SetField 0) :: rest -> check rest
    | Get s :: Set t :: rest when Hashtbl.find_opt owner t = Some s && t <> s -> check rest
    | Get s :: rest -> drop s; check rest
    | _ :: rest -> check rest
    | [] -> ()
  in
  check f.code;
  if Hashtbl.length owner = 0 then f
  else
    let var s = Hashtbl.find owner s in
    let mine s = Hashtbl.mem owner s in
    let rec go = function
      | Alloc (0, 1) :: Set s :: rest when mine s && var s = s -> Set s :: go rest
      | Get s :: Set t :: rest when mine t && var t <> t && var t = s -> go rest
      | Get s :: Field 0 :: rest when mine s -> Get (var s) :: go rest
      | Get s :: SetField 0 :: rest when mine s -> Set (var s) :: go rest
      | i :: rest -> i :: go rest
      | [] -> []
    in
    { f with code = go f.code }

(*****************************************************************************)
(* drops: a value pushed to be dropped, neither *)
(*****************************************************************************)

(* the unit of an assignment, a sequence's (r := e; ...): Int 0; Drop *)
let drops (f : func) =
  let rec go = function
    | (Int _ | Get _ | Block _) :: Drop :: rest -> go rest
    | i :: rest -> i :: go rest
    | [] -> []
  in
  { f with code = go f.code }

(*****************************************************************************)
(* The passes *)
(*****************************************************************************)

let passes = [ "tails", tails; "eqs", eqs; "refs", refs; "drops", drops ]

let run names (u : unit_) =
  labels := highest u;
  let pass f (name, p) = if List.mem name names then p f else f in
  { u with funcs = List.map (fun f -> List.fold_left pass f passes) u.funcs }
