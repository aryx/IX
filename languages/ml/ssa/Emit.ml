(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Emit.mli *)

open Ssa
module L = Ir

(* the machines, as simple's Gen has them (its record is its own) *)
type mach = {
  arch : Asm.arch;
  w : int;
  mov : string;
  tmp : int;
  vsp : int;
  sp : string;
  link : string;
  frame : string;
  regs : int list;          (* the scratch registers *)
  vregs : int list;         (* the values' (Alloc's) *)
}

let arm = { arch = Arm; w = 4; mov = "MOVW"; tmp = 9; vsp = 10; sp = "R13"; link = "R14"; frame = "$-4"; regs = [ 1; 2; 3 ]; vregs = [] }
let arm64 = { arch = Arm64; w = 8; mov = "MOV"; tmp = 16; vsp = 26; sp = "RSP"; link = "R30"; frame = "$-8"; regs = [ 1; 2; 3 ];
              vregs = [ 20; 21; 22; 23; 24; 25 ] }
let sprintf = Printf.sprintf

let tagged m n =
  let v = Int64.add (Int64.mul 2L (Int64.of_int n)) 1L in
  if m.w = 4 then Int64.of_int32 (Int64.to_int32 v) else v

let round n a = (n + a - 1) / a * a
let labels = ref 0 and funcs = ref 0
let glabel () = incr labels; sprintf "Q%d" !labels

(*****************************************************************************)
(* A function *)
(*****************************************************************************)

(* The frame, as simple's: on the value stack f words below its top,
 * slot 0 the closure, then the parameters, then the stack code's slots
 * (a handler's function's variables), then one per value; on the
 * machine stack the link at 0, C's outgoing arguments, the handlers'
 * records. Every value lives in its slot (phase 3a): an instruction
 * loads its operands into registers, computes, stores its result *)
let func m out (fn : func) (lf : L.func) =
  let w = m.w and mov = m.mov and vsp = m.vsp and t = m.tmp in
  let lines = ref [] in
  let line f = lines := f :: !lines in
  let ins fmt = Printf.ksprintf (fun s -> line (fun _ _ _ -> "\t" ^ s ^ "\n")) fmt in
  let lab l = line (fun _ _ _ -> l ^ ":\n") in
  let tries = ref 0 and cargs = ref (if m.arch = Arm then 1 else 0) in
  let loc, frame = Alloc.alloc fn ~nregs:(List.length m.vregs) ~base:lf.nslots in
  (* the phis' copies go through slots of their own, after memory's *)
  let stage = frame and staged = ref 0 in
  let slot_ref f i =
    let off = w * (i - f) in
    if m.arch = Arm64 && off < -256 then sprintf "\tSUB\t$%d, R%d, R19\n" (-off) vsp, "0(R19)" else "", sprintf "%d(R%d)" off vsp
  in
  let get_slot i r = line (fun f _ _ -> let pre, a = slot_ref f i in sprintf "%s\t%s\t%s, R%d\n" pre mov a r) in
  let put_slot r i = line (fun f _ _ -> let pre, a = slot_ref f i in sprintf "%s\t%s\tR%d, %s\n" pre mov r a) in
  let vreg c = List.nth m.vregs c in
  (* v's register: its own, or v loaded into s *)
  let src v s =
    match loc v with
    | Alloc.Reg c -> vreg c
    | Mem i -> get_slot i s; s
    | Nil -> ins "%s\t$0, R%d" mov s; s
  in
  (* into register d: v, wherever it is *)
  let load v d = let r = src v d in if r <> d then ins "%s\tR%d, R%d" mov r d in
  (* the register to compute v in; then v put where it lives *)
  let dst v s = match loc v with Alloc.Reg c -> vreg c | _ -> s in
  let finish v r = match loc v with Alloc.Reg c -> if vreg c <> r then ins "%s\tR%d, R%d" mov r (vreg c) | Mem i -> put_slot r i | Nil -> () in
  let r1, r2, r3 = match m.regs with [ a; b; c ] -> a, b, c | _ -> 1, 2, 3 in
  let link = 0 in
  let epilogue () =
    line (fun f _ _ -> sprintf "\tSUB\t$%d, R%d\n" (w * f) vsp);
    ins "%s\t%d(%s), %s" mov link m.sp m.link;
    line (fun _ m' _ -> sprintf "\tADD\t$%d, %s\n" m' m.sp)
  in
  let record c k = c + (4 * w * k) in
  let at k d f = line (fun _ _ c -> "\t" ^ f (record c k + d) ^ "\n") in
  let shift = function
    | L.Lsl -> (match m.arch with Arm -> "SLL" | Arm64 -> "LSL")
    | Lsr -> (match m.arch with Arm -> "SRL" | Arm64 -> "LSR")
    | _ -> (match m.arch with Arm -> "SRA" | Arm64 -> "ASR")
  in
  let cond = function L.Eq -> "EQ" | Ne -> "NE" | Lt -> "LT" | Le -> "LE" | Gt -> "GT" | Ge -> "GE" in
  let set_bool r d =
    match m.arch with
    | Arm -> ins "MOVW\t$1, R%d" d; ins "MOVW.%s\t$3, R%d" (cond r) d
    | Arm64 -> ins "MOV\t$3, R%d" d; ins "B%s\t2(PC)" (cond r); ins "MOV\t$1, R%d" d
  in
  let branch_zero nonzero r l =
    match m.arch with
    | Arm -> ins "CMP\t$0, R%d" r; ins "%s\t%s" (if nonzero then "BNE" else "BEQ") l
    | Arm64 -> ins "%s\tR%d, %s" (if nonzero then "CBNZ" else "CBZ") r l
  in
  (* C's arguments: R0, then w*(i+1)(SP) (5c's and 7c's) *)
  let call_c f args =
    cargs := max !cargs (List.length args);
    List.iteri (fun k v -> if k = 0 then load v 0 else (let r = src v t in ins "%s\tR%d, %d(%s)" mov r (w * (k + 1)) m.sp)) args;
    ins "%s\tR%d, ml_vsp(SB)" mov vsp;
    ins "BL\t%s(SB)" f
  in
  (* a op b into d, a (the stack's top) in ra, b in rb: simple's
   * sequences, operand for operand (CMP Rb, Ra is b - a), in three
   * operands so that a and b stay; r1 and r2 the scratch *)
  let op (o : L.op) ra rb d =
    match o with
    | Add -> ins "ADD\tR%d, R%d, R%d" rb ra d; ins "SUB\t$1, R%d" d
    | Sub -> ins "SUB\tR%d, R%d, R%d" rb ra d; ins "ADD\t$1, R%d" d
    | Mul -> ins "SUB\t$1, R%d, R%d" ra r1; ins "%s\t$1, R%d, R%d" (shift Asr) rb r2; ins "MUL\tR%d, R%d, R%d" r2 r1 d; ins "ADD\t$1, R%d" d
    | Div | Mod ->
        ins "%s\t$1, R%d, R%d" (shift Asr) ra r1;
        ins "%s\t$1, R%d, R%d" (shift Asr) rb r2;
        ins "%s\tR%d, R%d, R%d" (match m.arch, o with Arm, Div -> "DIV" | Arm, _ -> "MOD" | _, Div -> "SDIV" | _ -> "REM") r2 r1 d;
        ins "%s\t$1, R%d" (shift Lsl) d;
        ins "ADD\t$1, R%d" d
    | And -> ins "AND\tR%d, R%d, R%d" rb ra d
    | Or -> ins "ORR\tR%d, R%d, R%d" rb ra d
    | Xor -> ins "EOR\tR%d, R%d, R%d" rb ra d; ins "ORR\t$1, R%d" d
    | Lsl -> ins "SUB\t$1, R%d, R%d" ra r1; ins "%s\t$1, R%d, R%d" (shift Asr) rb r2; ins "%s\tR%d, R%d, R%d" (shift Lsl) r2 r1 d; ins "ORR\t$1, R%d" d
    | Lsr | Asr -> ins "%s\t$1, R%d, R%d" (shift Asr) rb r2; ins "%s\tR%d, R%d, R%d" (shift o) r2 ra d; ins "ORR\t$1, R%d" d
    | Cmp r -> ins "CMP\tR%d, R%d" rb ra; set_bool r d
    | Poly _ | Neg | Not | IsInt | Tag | Size -> ()
  in
  let unary (o : L.op) a d =
    match o with
    | Neg -> (match m.arch with Arm -> ins "RSB\t$0, R%d, R%d" a d | Arm64 -> ins "NEG\tR%d, R%d" a d); ins "ADD\t$2, R%d" d
    | Not -> ins "EOR\t$2, R%d, R%d" a d
    | IsInt -> ins "AND\t$1, R%d, R%d" a d; ins "%s\t$1, R%d" (shift Lsl) d; ins "ORR\t$1, R%d" d
    | Tag -> ins "MOVBU\t%d(R%d), R%d" (-w) a d; ins "%s\t$1, R%d" (shift Lsl) d; ins "ORR\t$1, R%d" d
    | Size -> ins "%s\t%d(R%d), R%d" mov (-w) a d; ins "%s\t$10, R%d" (shift Lsr) d; ins "%s\t$1, R%d" (shift Lsl) d; ins "ORR\t$1, R%d" d
    | _ -> ()
  in
  (* block b's i-th field's address into i's register, checked *)
  let index b i =
    ins "%s\t%d(R%d), R%d" mov (-w) b t;
    ins "%s\t$10, R%d" (shift Lsr) t;
    ins "%s\t$1, R%d" (shift Asr) i;
    ins "CMP\tR%d, R%d" t i;
    ins "BLO\t2(PC)";
    ins "BL\tcaml_array_bound_error(SB)";
    ins "%s\t$%d, R%d" (shift Lsl) (if w = 4 then 2 else 3) i;
    ins "ADD\tR%d, R%d" b i
  in
  incr funcs;
  let fid = !funcs in
  let blabel b = sprintf "Q%d_%d" fid b in
  (* a phi's copies at the end of p toward s: through the staging slots,
   * all read before any is written *)
  let copies p s =
    let moves = List.filter_map (fun phi -> match Hashtbl.find fn.defs phi with Phi ops -> Some (phi, List.assoc p ops) | _ -> None) fn.blocks.(s).phis in
    staged := max !staged (List.length moves);
    List.iteri (fun k (_, x) -> let r = src x r1 in put_slot r (stage + k)) moves;
    List.iteri (fun k (dst, _) -> get_slot (stage + k) r1; finish dst r1) moves
  in
  let split = ref [] in
  let edge p s ~alone =
    if fn.blocks.(s).phis = [] then blabel s
    else if alone then (copies p s; blabel s)
    else (let l = glabel () in split := (l, p, s) :: !split; l)
  in
  Array.iter (fun (b : block) ->
    lab (blabel b.id);
    List.iter (fun v ->
      match Hashtbl.find fn.defs v with
      | Zero | Param _ | Phi _ -> ()
      | Const n -> let d = dst v r1 in ins "%s\t$%Ld, R%d" mov (tagged m n) d; finish v d
      | Blk s -> let d = dst v r1 in ins "%s\t$%s+%d(SB), R%d" mov s w d; finish v d
      | Symb s -> let d = dst v r1 in ins "%s\t$%s(SB), R%d" mov s d; finish v d
      | GetG g -> let d = dst v r1 in ins "%s\t%s(SB), R%d" mov g d; finish v d
      | SetG (g, x) -> let r = src x r1 in ins "%s\tR%d, %s(SB)" mov r g
      | Slot i -> let d = dst v r1 in get_slot i d; finish v d
      | SetSlot (i, x) -> let r = src x r1 in put_slot r i
      | Field (k, x) -> let a = src x r1 in let d = dst v r2 in ins "%s\t%d(R%d), R%d" mov (w * k) a d; finish v d
      | SetField (k, blk, x) -> let bb = src blk r1 in let r = src x r2 in ins "%s\tR%d, %d(R%d)" mov r (w * k) bb
      | Index (blk, i) ->
          let bb = src blk r1 in load i r2; index bb r2;
          let d = dst v r3 in ins "%s\t0(R%d), R%d" mov r2 d; finish v d
      | SetIndex (blk, i, x) -> let bb = src blk r1 in load i r2; index bb r2; let r = src x r3 in ins "%s\tR%d, 0(R%d)" mov r r2
      | Alloc (tag, xs) ->
          (* the collector may run: the fields, in memory, read after *)
          cargs := max !cargs 2;
          ins "%s\t$%d, R0" mov (List.length xs);
          ins "%s\t$%d, R%d" mov tag t;
          ins "%s\tR%d, %d(%s)" mov t (2 * w) m.sp;
          ins "%s\tR%d, ml_vsp(SB)" mov vsp;
          ins "BL\tml_alloc(SB)";
          List.iteri (fun k x -> let r = src x t in ins "%s\tR%d, %d(R0)" mov r (w * k)) xs;
          finish v 0
      | Op (Poly r, [ x; y ]) ->
          (* integers compared here, the others by the runtime *)
          let slow = glabel () and ok = glabel () in
          let a = src x r1 in
          let bb = src y r2 in
          let d = dst v r2 in
          ins "AND\tR%d, R%d, R%d" bb a t;
          ins "AND\t$1, R%d" t;
          branch_zero false t slow;
          ins "CMP\tR%d, R%d" bb a;
          set_bool r d;
          ins "B\t%s" ok;
          lab slow;
          call_c (Lower.poly_function r) [ x; y ];
          ins "%s\tR0, R%d" mov d;
          lab ok;
          finish v d
      | Op (o, [ x; y ]) -> let a = src x r1 in let bb = src y r2 in let d = dst v r3 in op o a bb d; finish v d
      | Op (o, [ x ]) -> let a = src x r1 in let d = dst v r2 in unary o a d; finish v d
      | Op _ -> failwith (fn.name ^ ": ssa: an operation's operands")
      | Call (tg, xs) ->
          List.iteri (fun k x -> load x k) xs;
          (match tg with L.Direct f -> ins "BL\t%s(SB)" f | L.Code k -> ins "%s\t%d(R0), R%d" mov (w * k) t; ins "BL\t(R%d)" t);
          finish v 0
      | CallC (f, xs) -> call_c f xs; finish v 0
      | Caught _ -> finish v 0
      | TryExit k -> at k (3 * w) (fun o -> sprintf "%s\t%d(%s), R%d" mov o m.sp t); ins "%s\tR%d, ml_handler(SB)" mov t) b.body;
    match b.term with
    | Jmp s -> let l = edge b.id s ~alone:true in ins "B\t%s" l
    | Br (v, tr, fl) ->
        let lt = edge b.id tr ~alone:false and lf = edge b.id fl ~alone:false in
        let r = src v r1 in ins "CMP\t$1, R%d" r; ins "BEQ\t%s" lf; ins "B\t%s" lt
    | Try (k, body, h) ->
        tries := max !tries (k + 1);
        ins "%s\t%s, R0" mov m.sp;
        at k 0 (sprintf "ADD\t$%d, R0");
        ins "BL\tml_try(SB)";
        branch_zero true 0 (blabel h);
        ins "B\t%s" (edge b.id body ~alone:false)
    | Ret v -> load v 0; epilogue (); ins "%s" (match m.arch with Arm -> "RET" | Arm64 -> "RET\t(R30)")
    | Raise v -> load v 0; ins "B\tml_raise(SB)"
    | Tail (tg, xs) ->
        List.iteri (fun k x -> load x k) xs;
        (match tg with L.Direct f -> epilogue (); ins "B\t%s(SB)" f | L.Code k -> ins "%s\t%d(R0), R%d" mov (w * k) t; epilogue (); ins "B\t(R%d)" t))
    fn.blocks;
  List.iter (fun (l, p, s) -> lab l; copies p s; ins "B\t%s" (blabel s)) (List.rev !split);
  let f = stage + !staged and c = round (max (w * (!cargs + 1)) (link + w)) 16 in
  let msize = record c !tries in
  let pr fmt = Printf.bprintf out fmt in
  pr "\tTEXT\t%s(SB), %s\n" fn.name m.frame;
  pr "\tSUB\t$%d, %s\n\t%s\t%s, %d(%s)\n\tADD\t$%d, R%d\n" msize m.sp mov m.link link m.sp (w * f) vsp;
  let slot_at i = let pre, a = slot_ref f i in pr "%s" pre; a in
  for i = 0 to fn.nparams do let a = slot_at i in pr "\t%s\tR%d, %s\n" mov i a done;
  (* the other slots zeroed: the collector scans them *)
  (match m.arch with
   | Arm64 -> for i = fn.nparams + 1 to f - 1 do let a = slot_at i in pr "\tMOV\tZR, %s\n" a done
   | Arm -> if f > fn.nparams + 1 then pr "\tMOVW\t$0, R%d\n" t; for i = fn.nparams + 1 to f - 1 do pr "\tMOVW\tR%d, %s\n" t (snd (slot_ref f i)) done);
  List.iter (fun l -> Buffer.add_string out (l f msize c)) (List.rev !lines)

let unit_ (arch : Asm.arch) (u : L.unit_) =
  let m = match arch with Arm -> arm | Arm64 -> arm64 in
  let out = Buffer.create 65536 in
  List.iter (fun (lf : L.func) -> func m out (Ssa_build.func lf) lf) u.funcs;
  Buffer.contents out
