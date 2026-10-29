(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Ssa_gen.mli *)

(* Ir for its types' I and F, Ssa for the instructions *)
open Ir
open Ssa
module A = Asm
module G = Gen

(* the registers Alloc colors with, and the two scratch ones of each
 * kind: Gen's stack registers and its variables' (arm64), less the
 * scratch, R0 and Gen's tmp; s2 -1: none *)
type regs = {
  iregs : int list; fregs : int list; s1 : int; s2 : int; f1 : int; f2 : int
}

(* OPTIMIZATION (R8 the allocator's): on arm, 5c's registers are R0-R8
 * (R9 and R10 the external ones, R11 the linker's, then SB, SP, the
 * link and the PC), and R0 is the only scratch: R1-R8 Alloc's, eight.
 * Not R9 or R10, though no C of ix declares an extern register: R10 is
 * mini-ml's value stack's top, a register for a program's whole run,
 * which the ML code does not load back after calling C (mini-ml's
 * Emit; runtime.c's ml_vsp): C that changed it would lose the ML
 * caller's values. R9 is mini-ml's temporary, by its code only between
 * calls as far as read, but nothing says so; Plan 9's rule, both kept,
 * is the one place that does. Nor R26 on arm64, the value stack's
 * there.
 * A function with an instruction that needs a second scratch (two
 * operands in memory, a cycle of phis' moves) is made again with
 * seven, R8 that scratch.
 * old: R1-R7 always, R0 and R8 the scratch *)
exception No_scratch

let regs ~eight =
  if G.a64 () then
    { iregs = List.init 15 (fun i -> i + 1) @ [ 19; 20; 21; 22; 23; 24; 25 ];
      fregs = List.init 15 (fun i -> i + 1) @ [ 17; 18; 19; 20; 21; 22; 23 ];
      s1 = 0; s2 = 16; f1 = 0; f2 = 16 }
  else if eight then
    { iregs = [ 1; 2; 3; 4; 5; 6; 7; 8 ]; fregs = [ 1; 2; 3; 4; 5; 6 ];
      s1 = 0; s2 = -1; f1 = 0; f2 = 7 }
  else
    { iregs = [ 1; 2; 3; 4; 5; 6; 7 ]; fregs = [ 1; 2; 3; 4; 5; 6 ];
      s1 = 0; s2 = 8; f1 = 0; f2 = 7 }

(* where a jump goes: a block, or an edge's moves of its own *)
type dest = Block of int | Edge of int

(* a phi's move: to a register (a float's?) or a slot, from a value or
 * from the scratch a cycle was broken by *)
type place = Preg of bool * int | Pslot of int
type source = From of Ssa.value | Temp of bool

let gen rg (fn : func) =
  let m = G.mach () in
  let s2 () = if rg.s2 < 0 then raise No_scratch else rg.s2 in
  let loc, saves, spill, nslots =
    Alloc.alloc fn ~nregs:(List.length rg.iregs)
      ~nfregs:(List.length rg.fregs) in
  let def v = Hashtbl.find fn.defs v and ty v = Hashtbl.find fn.types v in
  let fl v = match ty v with F _ -> true | I _ -> false in
  let r x = A.Reg x and f x = A.FReg x in
  let reg float x = if float then f x else r x in
  let move float x y =
    if x <> y then
      G.i2 (if float then G.fmov () else G.mov ()) (reg float x) (reg float y)
  in
  let imm c = A.Imm (if G.a64 () then c else Emit.sx32 c) in
  let slot k =
    A.Mem { A.base = A.SP; name = Some { A.sym = ".safe"; static = false };
            off = Int64.of_int (- (fn.locals + (8 * (k + 1)))); index = None }
  in
  let machine v c = List.nth (if fl v then rg.fregs else rg.iregs) c in
  let scratch v n =
    match fl v, n with
    | false, 1 -> rg.s1 | false, _ -> s2 ()
    | true, 1 -> rg.f1 | true, _ -> rg.f2 in
  (* v's value into register x *)
  let load_into v x =
    match loc v with
    | Alloc.Reg c -> move (fl v) (machine v c) x
    | Slot k ->
        G.i2 (if fl v then G.fmov () else G.mov ()) (slot k) (reg (fl v) x)
    | Home mm -> G.i2 (G.load_op (ty v)) (A.Mem mm) (reg (fl v) x)
    | Nil -> (
        match def v with
        | Const (c, _) -> G.i2 (G.mov ()) (imm c) (r x)
        | Fconst (c, t) -> G.i2 (G.load_op t) (A.Fimm c) (f x)
        | Addr mm -> G.i2 (G.mov ()) (A.Addr mm) (r x)
        | Undef (F _ as t) -> G.i2 (G.load_op t) (A.Fimm 0.) (f x)
        | _ -> G.i2 (G.mov ()) (A.Imm 0L) (r x))
  in
  (* OPTIMIZATION (a slot's value still in its register): a value just
   * stored to its slot (put), read by the next instruction, is the
   * register it was stored from, no instruction emitted between nor a
   * block begun: qsort's pi, live across its loop's call, stored then
   * loaded at once (str r1,[sp,#64]; ldr r1,[sp,#64]).
   * old: loaded from the slot at each read *)
  let stored = ref None in
  let forget () = stored := None in
  (* the register holding v, its n-th scratch if none *)
  let get v n =
    match loc v, !stored with
    | Alloc.Reg c, _ -> machine v c
    | Slot _, Some (v', x, pc) when v' = v && pc = !Emit.pc -> x
    | _ -> let x = scratch v n in load_into v x; x in
  (* the register v is computed into, and its store after *)
  let dst v =
    match loc v with Alloc.Reg c -> machine v c | _ -> scratch v 1 in
  let put v x =
    match loc v with
    | Slot k ->
        G.i2 (if fl v then G.fmov () else G.mov ()) (reg (fl v) x) (slot k);
        stored := Some (v, x, !Emit.pc)
    (* in a register, and live across calls: stored once, here *)
    | Reg _ -> (
        match spill v with
        | Some k ->
            G.i2 (if fl v then G.fmov () else G.mov ()) (reg (fl v) x) (slot k)
        | None -> ())
    | _ -> () in
  (* n bytes from src to dst+off, by words when they are all words: the
   * addresses got again for each word, a scratch each if not in a
   * register *)
  let copy src dst_addr off n =
    let w =
      if G.a64 () && n mod 8 = 0 then 8 else if n mod 4 = 0 then 4 else 1 in
    let t = I (w, false) in
    for k = 0 to (n / w) - 1 do
      G.i2 (G.load_op t) (G.at (src ()) (k * w)) (r rg.s1);
      G.i2 (G.store_op t) (r rg.s1) (G.at (dst_addr ()) (off + (k * w)))
    done
  in
  (* a second operand's register: the first scratch when the first
   * operand's is not it (arm's eight registers, R0 the only scratch) *)
  let second a ra b =
    if fl a = fl b && ra = scratch b 1 then get b 2 else get b 1 in
  let compare t a b =
    let ra = get a 1 in
    let b =
      match b with
      | V b ->
          (match t with F _ -> f (second a ra b) | I _ -> r (second a ra b))
      | Imm c -> imm c in
    match t with
    | I _ -> ignore (G.ins_reg "CMP" ra (Some b) None)
    | F _ ->
        ignore (G.ins_reg ((if G.a64 () then "FCMP" else "CMP") ^ G.prec t)
                  ra (Some b) None)
  in
  let pure = function
    | Op _ | OpImm _ | Neg _ | Com _ | Cvt _ | Param _ | Phi _ | Const _
    | Fconst _ | Addr _ | Undef _ -> true
    | _ -> false in
  (* OPTIMIZATION (post-index): a load or a store through q, then q + k
   * in q's register (Ssa_build's sink, Alloc's phi register), is one
   * access that moves q on after it, as the scan by hand had MOVW.P 4(R0),R7:
   * *q++ = *p++ two instructions. Not a float's (vfp's loads have no
   * such form), nor a store of q itself; k as small as arm64's 9 bits.
   * old: the access, then the ADD *)
  let fused = Hashtbl.create 16 in
  let post v next =
    match def v, next with
    | (Load ((I _ as t), a, 0) | Store ((I _ as t), a, 0, _)), Some w -> (
        match def w, loc a, loc w with
        | OpImm (Add, I (n, _), a', k), Alloc.Reg c, Alloc.Reg c'
          when a' = a && c = c' && n = m.word && k >= -255L && k <= 255L ->
            let ra = machine a c in
            (match def v with
             | Load _ ->
                 let d = dst v in
                 if d <> ra then begin
                   let q =
                     G.ins (G.load_op t) (Some (G.at ra (Int64.to_int k)))
                       (Some (r d)) in
                   q.cond <- [ "P" ]; put v d; Hashtbl.replace fused w (); true
                 end else false
             | Store (_, _, _, x) ->
                 let rx = get x 2 in
                 if rx <> ra then begin
                   let q =
                     G.ins (G.store_op t) (Some (r rx))
                       (Some (G.at ra (Int64.to_int k))) in
                   q.cond <- [ "P" ]; Hashtbl.replace fused w (); true
                 end else false
             | _ -> false)
        | _ -> false)
    | _ -> false
  in
  let body v =
    let ins = def v in
    if loc v = Nil && pure ins then ()
    else
      match ins with
      | Const _ | Fconst _ | Addr _ | Undef _ | Phi _ -> ()
      (* the first parameter from R0 still (the parameters are the
       * entry's first values, before any scratch is used) *)
      | Param (mm, t) -> (
          match loc v, fn.r0 with
          | Alloc.Reg _, Some (m0, _) when m0 = mm && not (fl v) ->
              let d = dst v in move false 0 d; G.extend t d
          | Alloc.Reg _, _ ->
              let d = dst v in G.i2 (G.load_op t) (A.Mem mm) (reg (fl v) d)
          | _ -> ())
      | Load (t, a, k) ->
          let ra = get a 1 in let d = dst v in
          G.i2 (G.load_op t) (G.at ra k) (reg (fl v) d); put v d
      | LoadAt (mm, t) ->
          let d = dst v in G.i2 (G.load_op t) (A.Mem mm) (reg (fl v) d); put v d
      | Store (t, a, k, x) ->
          let ra = get a 1 in let rx = second a ra x in
          G.i2 (G.store_op t) (reg (fl x) rx) (G.at ra k)
      | StoreAt (mm, t, x) ->
          let rx = get x 1 in G.i2 (G.store_op t) (reg (fl x) rx) (A.Mem mm)
      | Copy (n, d, s) -> copy (fun () -> get s 2) (fun () -> get d 2) 0 n
      | Op (o, t, a, b) when Tree_helpers.is_rel o ->
          compare t a (V b);
          let d = dst v in
          G.i2 (G.mov ()) (A.Imm 1L) (r d);
          let q =
            G.ins (G.branch (G.cond o
                               ~fl:(match t with F _ -> true | I _ -> false)))
              None None in
          G.i2 (G.mov ()) (A.Imm 0L) (r d);
          Emit.patch q !Emit.pc;
          put v d
      | Op (o, (I _ as t), a, b) ->
          let ra = get a 1 in let rb = second a ra b in let d = dst v in
          ignore (G.ins_reg (G.int_op o) ra (Some (r rb)) (Some (r d)));
          G.extend t d;
          put v d
      | Op (o, t, a, b) ->
          let ra = get a 1 in let rb = second a ra b in let d = dst v in
          ignore (G.ins_reg (G.float_op o t) ra (Some (f rb)) (Some (f d)));
          put v d
      | OpImm (o, t, a, c) ->
          let ra = get a 1 in let d = dst v in
          ignore (G.ins_reg (G.int_op o) ra (Some (imm c)) (Some (r d)));
          G.extend t d;
          put v d
      | Neg ((I _ as t), a) ->
          let ra = get a 1 in let d = dst v in
          G.i2 "NEG" (r ra) (r d); G.extend t d; put v d
      | Neg (t, a) ->
          let ra = get a 1 in let d = dst v in
          G.i2 ("FNEG" ^ G.prec t) (f ra) (f d); put v d
      | Com (t, a) ->
          let ra = get a 1 in let d = dst v in
          G.i2 "MVN" (r ra) (r d); G.extend t d; put v d
      | Cvt (x, y, a) when x = y ->
          let ra = get a 1 in let d = dst v in move (fl v) ra d; put v d
      | Cvt (I _, (I _ as y), a) ->
          let ra = get a 1 in let d = dst v in
          move false ra d; G.extend y d; put v d
      | Cvt (I (_, s), (F _ as y), a) ->
          let ra = get a 1 in let d = dst v in
          if G.a64 () then
            G.i2 ((if s then "SCVTF" else "UCVTF") ^ G.prec y) (r ra) (f d)
          else begin
            G.i2 "MOVWD" (r ra) (f d);
            (* the top bit apart: vfp's conversion is signed *)
            if not s then begin
              ignore (G.ins_reg "CMP" ra (Some (A.Imm 0L)) None);
              let q = G.ins "BGE" None None in
              G.i2 "MOVD" (A.Fimm 4294967296.) (f rg.f2);
              ignore (G.ins_reg "ADDD" d (Some (f rg.f2)) (Some (f d)));
              Emit.patch q !Emit.pc
            end;
            if y = F 4 then G.i2 "MOVDF" (f d) (f d)
          end;
          put v d
      | Cvt ((F _ as x), (I (_, s) as y), a) ->
          let ra = get a 1 in let d = dst v in
          if G.a64 () then
            G.i2 ("FCVTZ" ^ (if s then "S" else "U") ^ G.prec x) (f ra) (r d)
          else G.i2 (if x = F 4 then "MOVFW" else "MOVDW") (f ra) (r d);
          G.extend y d;
          put v d
      | Cvt (x, _, a) ->
          let ra = get a 1 in let d = dst v in
          G.i2 (match G.a64 (), x with
                | true, F 4 -> "FCVTSD" | true, _ -> "FCVTDS"
                | false, F 4 -> "MOVFD" | false, _ -> "MOVDF") (f ra) (f d);
          put v d
      | Arg (o, t, x) ->
          let rx = get x 1 in
          G.i2 (G.store_op t) (reg (fl x) rx) (G.at m.sp (m.word + o))
      | ArgBlock (o, n, x) ->
          copy (fun () -> get x 2) (fun () -> m.sp) (m.word + o) n
      | Call (target, a, r0, rt) ->
          (* the registers live across it loaded after it, from where
           * they were stored when made (put) *)
          let saved = saves v in
          let callee =
            match target, a with
            | Direct mm, _ -> A.Mem mm
            | Indirect, Some a -> G.at (get a 2) 0
            | Indirect, None -> failwith "ssa: a call without its address" in
          (match r0 with
           | Some (_, Some x) -> load_into x 0
           | Some (t, None) -> G.i2 (G.load_op t) (G.at m.sp m.word) (r 0)
           | None -> ());
          G.i1 "BL" callee;
          List.iter (fun (x, at) ->
            match at, loc x with
            | Alloc.Slot k, Alloc.Reg c ->
                G.i2 (if fl x then G.fmov () else G.mov ()) (slot k)
                  (reg (fl x) (machine x c))
            | Alloc.Home mm, Alloc.Reg c ->
                G.i2 (G.load_op (ty x)) (A.Mem mm) (reg (fl x) (machine x c))
            | _ -> ()) saved;
          Option.iter (fun t ->
            let d = dst v in
            move (fl v) 0 d;
            (match t with I _ -> G.extend t d | F _ -> ());
            put v d) rt
  in
  (* a phi's moves on the edge p -> s, as one parallel copy: a move
   * whose destination no other reads first; a cycle broken by the
   * second scratch *)
  let moves p s =
    let place v =
      match loc v with
      | Alloc.Reg c -> Some (Preg (fl v, machine v c))
      | Slot k -> Some (Pslot k)
      | _ -> None in
    let pending =
      ref (List.filter_map (fun phi ->
        match def phi with
        | Phi ops ->
            let src = List.assoc p ops in
            (match place phi with
             | Some d when place src <> Some d -> Some (d, From src, fl phi)
             | _ -> None)
        | _ -> None) fn.blocks.(s).phis)
    in
    let temp float = if float then rg.f2 else s2 () in
    let reads = function
      | From v -> place v | Temp float -> Some (Preg (float, temp float)) in
    let emit (d, src, float) =
      let into x =
        match src with
        | From v -> load_into v x
        | Temp _ -> move float (temp float) x in
      match d with
      | Preg (_, x) -> into x
      | Pslot k ->
          let x =
            match src with
            | From v ->
                (match loc v with
                 | Alloc.Reg c -> machine v c
                 | _ -> let x = scratch v 1 in into x; x)
            | Temp _ -> temp float in
          G.i2 (if float then G.fmov () else G.mov ()) (reg float x) (slot k)
    in
    while !pending <> [] do
      match List.find_opt (fun (d, _, _) ->
              not (List.exists (fun (d', src, _) ->
                     d' <> d && reads src = Some d) !pending)) !pending with
      | Some mv ->
          emit mv; pending := List.filter (fun mv' -> mv' <> mv) !pending
      | None ->
          (* a cycle: one destination's old value to the scratch *)
          let d, _, float = List.hd !pending in
          (match d with
           | Preg (_, x) -> move float x (temp float)
           | Pslot k ->
               G.i2 (if float then G.fmov () else G.mov ()) (slot k)
                 (reg float (temp float)));
          pending :=
            List.map (fun (d', src, fl') ->
              if reads src = Some d then (d', Temp float, fl')
              else (d', src, fl')) !pending
    done
  in
  let text = Emit.gpseudo "TEXT" fn.name (Emit.nodconst 0L) in
  text.pseudo <- Emit.Ptext (if !Pre.profile then 0 else 1);
  (* OPTIMIZATION (R0's store): the first parameter stored to its slot
   * only if something reads it there: a variable not SSA's (its address
   * taken), or its value in its slot (Home), or loaded from there after
   * a call. Else R0 is all: cmp's 8 instructions a call to 7.
   * old: always stored, as 5c does *)
  let r0_read (m0 : Ssa.mem) =
    let param = ref None and calls = ref [] in
    Hashtbl.iter (fun v ins ->
      match ins with
      | Param (m, _) when m = m0 -> param := Some v
      | Call _ -> calls := v :: !calls
      | _ -> ()) fn.defs;
    match !param with
    | None -> true
    | Some p -> (
        match loc p with
        | Alloc.Home _ -> true
        | Alloc.Reg _ ->
            List.exists (fun c -> List.mem_assoc p (saves c)) !calls
        | _ -> false)
  in
  Option.iter (fun (mm, t) ->
    if r0_read mm then G.i2 (G.store_op t) (r 0) (A.Mem mm)) fn.r0;
  let pcs = Hashtbl.create 16 and jumps = ref [] and edges = ref [] in
  let jump a d = jumps := (G.ins a None None, d) :: !jumps in
  let has_phis s = fn.blocks.(s).phis <> [] in
  (* the edge to s taken by a branch: its moves elsewhere if any *)
  let target b s =
    if has_phis s then
      (let k = List.length !edges in edges := (k, b, s) :: !edges; Edge k)
    else Block s in
  Array.iter (fun (bl : block) ->
    Hashtbl.replace pcs (Block bl.id) !Emit.pc;
    forget ();
    (* a phi live across calls stored where it is made, its block's
     * start *)
    List.iter (fun v ->
      match loc v with Alloc.Reg c -> put v (machine v c) | _ -> ()) bl.phis;
    let rec walk = function
      | v :: rest ->
          if Hashtbl.mem fused v then ()
          else if not (post v (match rest with w :: _ -> Some w | [] -> None))
          then body v;
          walk rest
      | [] -> ()
    in
    walk bl.body;
    match bl.term with
    | Jmp s -> moves bl.id s; if s <> bl.id + 1 then jump "B" (Block s)
    | Br (o, t, a, b, th, el) ->
        compare t a b;
        let c = G.cond o ~fl:(match t with F _ -> true | I _ -> false) in
        (* an integer's branch inverted to fall into the next block *)
        if th = bl.id + 1 && (not (has_phis th))
           && (match t with I _ -> true | F _ -> false)
        then jump (G.branch (A.invert c)) (target bl.id el)
        else begin
          jump (G.branch c) (target bl.id th);
          moves bl.id el;
          if el <> bl.id + 1 then jump "B" (Block el)
        end
    | Ret v ->
        Option.iter (fun v -> load_into v 0) v;
        ignore (G.ins m.ret None None)) fn.blocks;
  List.iter (fun (k, p, s) ->
    Hashtbl.replace pcs (Edge k) !Emit.pc;
    forget (); moves p s; jump "B" (Block s))
    (List.rev !edges);
  List.iter (fun (q, d) -> Emit.patch q (Hashtbl.find pcs d)) !jumps;
  let frame = fn.locals + (8 * nslots) + fn.args in
  text.to_ <-
    Some (A.Imm (Int64.of_int
                   (Declare.round frame (if G.a64 () then 8 else 4))))

let func (fn : func) =
  let progs = !Emit.progs and pc = !Emit.pc in
  try gen (regs ~eight:true) fn
  with No_scratch ->
    Emit.progs := progs; Emit.pc := pc;
    gen (regs ~eight:false) fn
