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
  nregs : int;              (* the arguments', from R1 *)
  regs : int list;          (* the scratch registers *)
  vregs : int list;         (* the values' (Alloc's) *)
}

(* the values' registers: no value is in one across a call (Alloc's
 * safepoints), so an argument's register holds one between calls, a
 * call's arguments loaded by a parallel move (args); arm's DIV is a
 * call of _div, which keeps R0-R3, R4-R8 untouched
 * old: arm's none, arm64's R20-R25 *)
let arm = { arch = Arm; w = 4; mov = "MOVW"; tmp = 9; vsp = 10; sp = "R13"; link = "R14"; frame = "$-4"; nregs = 8; regs = [ 1; 2; 3 ];
            vregs = [ 4; 5; 6; 7; 8 ] }
let arm64 = { arch = Arm64; w = 8; mov = "MOV"; tmp = 16; vsp = 26; sp = "RSP"; link = "R30"; frame = "$-8"; nregs = 15; regs = [ 1; 2; 3 ];
              vregs = [ 20; 21; 22; 23; 24; 25; 4; 5; 6; 7; 8; 9; 10; 11; 12; 13; 14; 15 ] }
let sprintf = Printf.sprintf

(* a parallel move's: where a value goes (a register, a slot), what it
 * comes from (a place, or a constant made there) *)
type place = In_reg of int | In_slot of int
type source = At of place | Made of value

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
 * records. A value lives where Alloc says, a register, a slot or
 * nowhere (a constant, made where it is read); an instruction reads
 * its operands from there, computes into its result's register, or
 * into a scratch one then its slot *)
let func m out (fn : func) (lf : L.func) =
  let w = m.w and mov = m.mov and vsp = m.vsp and t = m.tmp in
  let lines = ref [] in
  let line f = lines := f :: !lines in
  let ins fmt = Printf.ksprintf (fun s -> line (fun _ _ _ -> "\t" ^ s ^ "\n")) fmt in
  let lab l = line (fun _ _ _ -> l ^ ":\n") in
  let tries = ref 0 and cargs = ref (if m.arch = Arm then 1 else 0) in
  (* OPTIMIZATION: the stack code's own slots (its variables and
   * temporaries) are values here, in registers or in slots of their
   * own, so the frame has none of them, unless a handler's function
   * reads and writes them in memory (Ssa_build): fib's frame was 9
   * words, 7 of them zeroed at each call, now 3.
   * old: ~base:lf.nslots always *)
  let memory = List.exists (function L.TryEnter _ -> true | _ -> false) lf.code in
  let base = if memory then lf.nslots else fn.nparams + 1 in
  let def v = Hashtbl.find fn.defs v in
  let loc, frame = Alloc.alloc fn ~nregs:(List.length m.vregs) ~base in
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
    | Nil ->
        (match Hashtbl.find fn.defs v with
         | Const n -> ins "%s\t$%Ld, R%d" mov (tagged m n) s
         | Blk b -> ins "%s\t$%s+%d(SB), R%d" mov b w s
         | Symb y -> ins "%s\t$%s(SB), R%d" mov y s
         | _ -> ins "%s\t$0, R%d" mov s);
        s
  in
  (* into register d: v, wherever it is *)
  let load v d = let r = src v d in if r <> d then ins "%s\tR%d, R%d" mov r d in
  (* the register to compute v in; then v put where it lives *)
  let dst v s = match loc v with Alloc.Reg c -> vreg c | _ -> s in
  let finish v r = match loc v with Alloc.Reg c -> if vreg c <> r then ins "%s\tR%d, R%d" mov r (vreg c) | Mem i -> put_slot r i | Nil -> () in
  (* a call's arguments: in R0.., those past the registers in the
   * callee's slots, above the top, and for a tail call copied down
   * into this frame's (simple's Gen, its Call) *)
  (* moves all at once, (where, from), sequenced: first a move whose
   * place no other still reads; a cycle broken by the scratch register
   * (a parallel copy, as a phi's or a call's arguments are) *)
  let r1, r2, r3 = match m.regs with [ a; b; c ] -> a, b, c | _ -> 1, 2, 3 in
  let place v = match loc v with Alloc.Reg c -> Some (In_reg (vreg c)) | Mem i -> Some (In_slot i) | Nil -> None in
  let from v = match place v with Some p -> At p | None -> Made v in
  let read s r = match s with At (In_reg x) -> x | At (In_slot i) -> get_slot i r; r | Made v -> src v r in
  let write d s =
    match d with
    | In_reg x -> let r = read s x in if r <> x then ins "%s\tR%d, R%d" mov r x
    | In_slot i -> let r = read s r1 in put_slot r i
  in
  let pmove (moves : (place * source) list) =
    let pending = ref (List.filter (fun ((d, s) : place * source) -> s <> At d) moves) in
    while !pending <> [] do
      let reads d = List.exists (fun ((d', s) : place * source) -> d' <> d && s = At d) !pending in
      match List.partition (fun ((d, _) : place * source) -> not (reads d)) !pending with
      | (d, s) :: free, busy -> write d s; pending := free @ busy
      | [], (_, s) :: _ ->
          write (In_reg t) s;
          pending := List.map (fun ((d, s') : place * source) -> d, if s' = s then At (In_reg t) else s') !pending
      | [], [] -> ()
    done
  in
  (* a call's arguments: in R0.., those past the registers in the
   * callee's slots, above the top (first: they read registers the
   * others are moved into), and for a tail call copied down into this
   * frame's (simple's Gen, its Call) *)
  let args xs tail =
    let extra = List.filteri (fun k _ -> k > m.nregs) (List.mapi (fun k x -> k, x) xs) in
    List.iter (fun (k, x) -> let r = src x t in ins "%s\tR%d, %d(R%d)" mov r (w * k) vsp) extra;
    pmove (List.filteri (fun k _ -> k <= m.nregs) (List.mapi (fun k x -> In_reg k, from x) xs));
    if tail then List.iter (fun (k, _) -> ins "%s\t%d(R%d), R%d" mov (w * k) vsp t; put_slot t k) extra
  in
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
  (* OPTIMIZATION (Gen.alloc_in_place, its switch): a block taken from
   * the heap here, simple's Gen's way (ml_alloc's two words, the
   * runtime called only when there is no room); so a new float, its
   * arithmetic the processor's, and a string's byte and length read in
   * place: Prim. Without them a call of the runtime each, 3 times
   * simple's instructions on a loop over bytes (tests/bench/pixels.ml) *)
  let in_place = !Gen.alloc_in_place in
  let fmov = match m.arch with Arm -> "MOVD" | Arm64 -> "FMOVD" in
  let float_words = 8 / w and float_tag = 253 in
  (* n words taken, the block in R0; to [slow] when there is no room *)
  let take n tag slow =
    ins "%s\tml_hp(SB), R0" mov;
    ins "%s\tml_limit(SB), R%d" mov t;
    ins "ADD\t$%d, R0" (w * (n + 1));
    ins "CMP\tR%d, R0" t;
    ins "BHI\t%s" slow;
    ins "%s\tR0, ml_hp(SB)" mov;
    ins "%s\t$%d, R%d" mov ((n lsl 10) lor tag) t;
    ins "%s\tR%d, %d(R0)" mov t (- (w * (n + 1)));
    ins "SUB\t$%d, R0" (w * n)
  in
  (* F0 in a new float, v; else [f] of the operands, the runtime's *)
  let float_result v f xs =
    let slow = glabel () and ok = glabel () in
    take float_words float_tag slow;
    ins "%s\tF0, 0(R0)" fmov;
    ins "B\t%s" ok;
    lab slow;
    call_c f xs;
    lab ok;
    finish v 0
  in
  (* the untagged index in t checked against string a's length,
   * computed in R0 and r3 (Gen's byte_bound) *)
  let byte_bound a =
    ins "%s\t%d(R%d), R0" mov (-w) a;
    ins "%s\t$10, R0" (shift Lsr);
    ins "%s\t$%d, R0" (shift Lsl) (if w = 4 then 2 else 3);
    ins "SUB\t$1, R0";
    ins "ADD\tR0, R%d, R%d" a r3;
    ins "MOVBU\t0(R%d), R%d" r3 r3;
    ins "SUB\tR%d, R0" r3;
    ins "CMP\tR0, R%d" t;
    ins "BLO\t2(PC)";
    ins "BL\tcaml_array_bound_error(SB)"
  in
  let prim v (p : L.t) xs =
    match p, xs with
    (* a string's byte: the index untagged and added to its address *)
    | ByteGet checked, [ s; i ] ->
        let a = src s r1 in let b = src i r2 in let d = dst v r3 in
        ins "%s\t$1, R%d, R%d" (shift Asr) b t;
        if checked then byte_bound a;
        ins "ADD\tR%d, R%d" a t;
        ins "MOVBU\t0(R%d), R%d" t d;
        ins "%s\t$1, R%d" (shift Lsl) d;
        ins "ORR\t$1, R%d" d;
        finish v d
    | ByteSet checked, [ s; i; x ] ->
        let a = src s r1 in let b = src i r2 in
        ins "%s\t$1, R%d, R%d" (shift Asr) b t;
        if checked then byte_bound a;
        let c = src x r3 in
        ins "ADD\tR%d, R%d" a t;
        ins "%s\t$1, R%d, R%d" (shift Asr) c r3;
        ins "MOVB\tR%d, 0(R%d)" r3 t
    (* its words' bytes, less one, less what its last byte says *)
    | StrLen, [ s ] ->
        let a = src s r1 in let d = dst v r2 in
        ins "%s\t%d(R%d), R%d" mov (-w) a t;
        ins "%s\t$10, R%d" (shift Lsr) t;
        ins "%s\t$%d, R%d" (shift Lsl) (if w = 4 then 2 else 3) t;
        ins "SUB\t$1, R%d" t;
        ins "ADD\tR%d, R%d, R%d" t a r3;
        ins "MOVBU\t0(R%d), R%d" r3 r3;
        ins "SUB\tR%d, R%d, R%d" r3 t d;
        ins "%s\t$1, R%d" (shift Lsl) d;
        ins "ORR\t$1, R%d" d;
        finish v d
    | Float2 f, [ x; y ] when in_place ->
        let a = src x r1 in let b = src y r2 in
        ins "%s\t0(R%d), F0" fmov a;
        ins "%s\t0(R%d), F1" fmov b;
        ins "%s\tF1, F0"
          (match m.arch, f with
           | Arm, "caml_addfloat" -> "ADDD" | Arm, "caml_subfloat" -> "SUBD" | Arm, "caml_mulfloat" -> "MULD" | Arm, _ -> "DIVD"
           | Arm64, "caml_addfloat" -> "FADDD" | Arm64, "caml_subfloat" -> "FSUBD" | Arm64, "caml_mulfloat" -> "FMULD" | Arm64, _ -> "FDIVD");
        float_result v f xs
    (* the sign's bit of the high word changed, as the runtime does *)
    | Float1 f, [ x ] when in_place && m.arch = Arm ->
        let slow = glabel () and ok = glabel () in
        take float_words float_tag slow;
        let a = src x r1 in
        ins "MOVW\t0(R%d), R%d" a t;
        ins "MOVW\tR%d, 0(R0)" t;
        ins "MOVW\t4(R%d), R%d" a t;
        ins "%s\t$0x80000000, R%d" (if f = "caml_negfloat" then "EOR" else "BIC") t;
        ins "MOVW\tR%d, 4(R0)" t;
        ins "B\t%s" ok;
        lab slow;
        call_c f xs;
        lab ok;
        finish v 0
    | FloatOfInt, [ x ] when in_place ->
        let a = src x r1 in
        ins "%s\t$1, R%d, R%d" (shift Asr) a t;
        ins "%s\tR%d, F0" (match m.arch with Arm -> "MOVWD" | Arm64 -> "SCVTFD") t;
        float_result v "caml_floatofint" xs
    | IntOfFloat, [ x ] when in_place ->
        let a = src x r1 in let d = dst v r2 in
        ins "%s\t0(R%d), F0" fmov a;
        ins "%s\tF0, R%d" (match m.arch with Arm -> "MOVDW" | Arm64 -> "FCVTZSD") d;
        ins "%s\t$1, R%d" (shift Lsl) d;
        ins "ORR\t$1, R%d" d;
        finish v d
    (* old: (and without in_place) the runtime's, as before *)
    | ByteGet _, _ -> call_c "ml_string_get" xs; finish v 0
    | ByteSet _, _ -> call_c "ml_string_set" xs
    | StrLen, _ -> call_c "ml_string_length" xs; finish v 0
    | (Float2 f | Float1 f), _ -> call_c f xs; finish v 0
    | FloatOfInt, _ -> call_c "caml_floatofint" xs; finish v 0
    | IntOfFloat, _ -> call_c "caml_intoffloat" xs; finish v 0
    | _ -> failwith (fn.name ^ ": ssa: a primitive's operands")
  in
  incr funcs;
  let fid = !funcs in
  let blabel b = sprintf "Q%d_%d" fid b in
  (* a phi's copies at the end of p toward s, a parallel move
   * old: through the staging slots, all read before any written
   *   List.iteri (fun k (_, x) -> let r = src x r1 in put_slot r (stage + k)) moves;
   *   List.iteri (fun k (dst, _) -> get_slot (stage + k) r1; finish dst r1) moves *)
  let copies p s =
    let moves = List.filter_map (fun phi -> match Hashtbl.find fn.defs phi with Phi ops -> Some (phi, List.assoc p ops) | _ -> None) fn.blocks.(s).phis in
    pmove (List.filter_map (fun (phi, x) -> Option.map (fun d -> d, from x) (place phi)) moves)
  in
  let split = ref [] in
  let edge p s ~alone =
    if fn.blocks.(s).phis = [] then blabel s
    else if alone then (copies p s; blabel s)
    else (let l = glabel () in split := (l, p, s) :: !split; l)
  in
  (* OPTIMIZATION (fused): a comparison read only by its block's branch,
   * and the block's last, is the branch's: CMP, then B.cond, where its
   * boolean was made then compared with true (7 instructions a loop's
   * test on arm, 3) *)
  let reads = Hashtbl.create 64 in
  let read v = Hashtbl.replace reads v (1 + match Hashtbl.find_opt reads v with Some k -> k | None -> 0) in
  Array.iter (fun (b : block) ->
    List.iter (fun v -> List.iter read (Ssa_build.operands (Hashtbl.find fn.defs v))) (b.phis @ b.body);
    match b.term with Br (v, _, _) | Ret v | Raise v -> read v | Tail (_, vs) -> List.iter read vs | _ -> ()) fn.blocks;
  let fused (b : block) =
    match b.term, List.rev b.body with
    | Br (v, _, _), last :: _ when last = v && Hashtbl.find_opt reads v = Some 1 -> (
        match Hashtbl.find fn.defs v with Op (Cmp r, [ x; y ]) -> Some (r, x, y) | _ -> None)
    | _ -> None
  in
  (* OPTIMIZATION (immediates): a small constant an operand, in the
   * instruction (ocamlopt's Selection): x + 1 an ADD of 2, x < 10 a CMP
   * with 21, x lsr 14 a shift of 14 (both machines encode 0 to 255);
   * the constant as the target's word holds it, not the host's int:
   * 0x80000000 is 0 on arm whether mini-ml runs on 63 bits or 31 (or
   * the fixed point of ix built by ix on arm differs); n < 128, not
   * 2 * n + 1 < 256, which on 31 bits takes 946684800 (2 * n wraps) *)
  let small v =
    match Hashtbl.find fn.defs v with
    | Const n ->
      let n = Int64.to_int (Int64.shift_right (tagged m n) 1) in
      if n >= 0 && n < 128 then Some n else None
    | _ -> None
  in
  let compare_with x y =
    let a = src x r1 in
    match small y with
    | Some n -> ins "CMP\t$%d, R%d" (2 * n + 1) a
    | None -> let bb = src y r2 in ins "CMP\tR%d, R%d" bb a
  in
  let op_imm v (o : L.op) x y =
    match o, small y, small x with
    | (Add | Sub), Some n, _ -> let a = src x r1 in let d = dst v r3 in ins "%s\t$%d, R%d, R%d" (if o = Add then "ADD" else "SUB") (2 * n) a d; finish v d; true
    | Add, None, Some n -> let a = src y r1 in let d = dst v r3 in ins "ADD\t$%d, R%d, R%d" (2 * n) a d; finish v d; true
    | Cmp r, Some _, _ -> let d = dst v r3 in compare_with x y; set_bool r d; finish v d; true
    | (Lsl | Lsr | Asr), Some n, _ when n < 8 * w - 1 ->
        let a = src x r1 in let d = dst v r3 in
        (match o with
         | Lsl -> ins "SUB\t$1, R%d, R%d" a d; ins "%s\t$%d, R%d" (shift Lsl) n d
         | _ -> ins "%s\t$%d, R%d, R%d" (shift o) n a d);
        ins "ORR\t$1, R%d" d; finish v d; true
    | _ -> false
  in
  Array.iter (fun (b : block) ->
    lab (blabel b.id);
    let fuse = fused b in
    List.iter (fun v ->
      if fuse <> None && Some v = (match b.term with Br (c, _, _) -> Some c | _ -> None) then () else
      match Hashtbl.find fn.defs v with
      | Zero | Param _ | Phi _ -> ()
      (* made where they are read (src) *)
      | Const _ | Blk _ | Symb _ -> ()
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
      | Alloc (tag, xs) when in_place && List.length xs <= Gen.alloc_most ->
          let slow = glabel () and ok = glabel () in
          take (List.length xs) tag slow;
          List.iteri (fun k x -> let r = src x t in ins "%s\tR%d, %d(R0)" mov r (w * k)) xs;
          ins "B\t%s" ok;
          lab slow;
          cargs := max !cargs 2;
          ins "%s\t$%d, R0" mov (List.length xs);
          ins "%s\t$%d, R%d" mov tag t;
          ins "%s\tR%d, %d(%s)" mov t (2 * w) m.sp;
          ins "%s\tR%d, ml_vsp(SB)" mov vsp;
          ins "BL\tml_alloc(SB)";
          List.iteri (fun k x -> let r = src x t in ins "%s\tR%d, %d(R0)" mov r (w * k)) xs;
          lab ok;
          finish v 0
      (* OPTIMIZATION (in_place): a big block (Lower.block: more than 4
       * fields, made empty then filled) taken here too, its fields (),
       * as the runtime's obj_block does: mini-ml compiling its Typing.ml
       * spent 4.4% of its instructions in obj_block's calls.
       * old: the call, as below *)
      | CallC ("obj_block", [ x; y ])
        when in_place
             && (match def x, def y with
                 | Const _, Const n -> n > 0 && n <= Gen.alloc_most
                 | _ -> false) ->
          let tag, n =
            match def x, def y with Const t, Const n -> t, n | _ -> assert false
          in
          let slow = glabel () and ok = glabel () in
          take n tag slow;
          ins "%s\t$1, R%d" mov t;
          for k = 0 to n - 1 do ins "%s\tR%d, %d(R0)" mov t (w * k) done;
          ins "B\t%s" ok;
          lab slow;
          call_c "obj_block" [ x; y ];
          lab ok;
          finish v 0
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
      | Op (o, [ x; y ]) when op_imm v o x y -> ()
      | Op (o, [ x; y ]) -> let a = src x r1 in let bb = src y r2 in let d = dst v r3 in op o a bb d; finish v d
      | Op (o, [ x ]) -> let a = src x r1 in let d = dst v r2 in unary o a d; finish v d
      | Op _ -> failwith (fn.name ^ ": ssa: an operation's operands")
      | Call (tg, xs) ->
          args xs false;
          (match tg with L.Direct f -> ins "BL\t%s(SB)" f | L.Code k -> ins "%s\t%d(R0), R%d" mov (w * k) t; ins "BL\t(R%d)" t);
          finish v 0
      | CallC (f, xs) -> call_c f xs; finish v 0
      | Prim (p, xs) -> prim v p xs
      | Caught _ -> finish v 0
      | TryExit k -> at k (3 * w) (fun o -> sprintf "%s\t%d(%s), R%d" mov o m.sp t); ins "%s\tR%d, ml_handler(SB)" mov t) b.body;
    match b.term with
    | Jmp s -> let l = edge b.id s ~alone:true in ins "B\t%s" l
    | Br (v, tr, fl) ->
        let lt = edge b.id tr ~alone:false and lf = edge b.id fl ~alone:false in
        (match fuse with
         | Some (r, x, y) -> compare_with x y; ins "B%s\t%s" (cond r) lt; ins "B\t%s" lf
         | None -> let r = src v r1 in ins "CMP\t$1, R%d" r; ins "BEQ\t%s" lf; ins "B\t%s" lt)
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
        args xs true;
        (match tg with L.Direct f -> epilogue (); ins "B\t%s(SB)" f | L.Code k -> ins "%s\t%d(R0), R%d" mov (w * k) t; epilogue (); ins "B\t(R%d)" t))
    fn.blocks;
  List.iter (fun (l, p, s) -> lab l; copies p s; ins "B\t%s" (blabel s)) (List.rev !split);
  let f = frame and c = round (max (w * (!cargs + 1)) (link + w)) 16 in
  let msize = record c !tries in
  let pr fmt = Printf.bprintf out fmt in
  pr "\tTEXT\t%s(SB), %s\n" fn.name m.frame;
  pr "\tSUB\t$%d, %s\n\t%s\t%s, %d(%s)\n\tADD\t$%d, R%d\n" msize m.sp mov m.link link m.sp (w * f) vsp;
  let slot_at i = let pre, a = slot_ref f i in pr "%s" pre; a in
  for i = 0 to min fn.nparams m.nregs do let a = slot_at i in pr "\t%s\tR%d, %s\n" mov i a done;
  (* the parameters with a register (Alloc), from their slots, in
   * their order (not the table's: the stdlib's hash function's) *)
  let params =
    Hashtbl.fold (fun v ins acc ->
      match ins, loc v with
      | Param i, Alloc.Reg c -> (i, vreg c) :: acc
      | _ -> acc) fn.defs []
  in
  List.iter (fun ((i, r) : int * int) ->
    let a = slot_at i in
    pr "\t%s\t%s, R%d\n" mov a r) (List.sort compare params);
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
