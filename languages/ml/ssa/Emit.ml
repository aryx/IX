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
  fregs : int list;         (* the doubles' (Unbox's), floating-point *)
  fscratch : int;           (* a third scratch one, beside F0 and F1 (round) *)
}

(* the values' registers: no value is in one across a call (Alloc's
 * safepoints), so an argument's register holds one between calls, a
 * call's arguments loaded by a parallel move (args); arm's DIV is a
 * call of _div, which keeps R0-R3, R4-R8 untouched
 * old: arm's none, arm64's R20-R25 *)
let arm = { arch = Arm; w = 4; mov = "MOVW"; tmp = 9; vsp = 10; sp = "R13"; link = "R14"; frame = "$-4"; nregs = 8; regs = [ 1; 2; 3 ];
            vregs = [ 4; 5; 6; 7; 8 ]; fregs = List.init 12 (fun i -> i + 2); fscratch = 14 }
let arm64 = { arch = Arm64; w = 8; mov = "MOV"; tmp = 16; vsp = 26; sp = "RSP"; link = "R30"; frame = "$-8"; nregs = 15; regs = [ 1; 2; 3 ];
              vregs = [ 20; 21; 22; 23; 24; 25; 4; 5; 6; 7; 8; 9; 10; 11; 12; 13; 14; 15 ];
              fregs = List.init 14 (fun i -> i + 2); fscratch = 16 }
(* (F0, F1 and fscratch the scratch ones; arm's F15 the linker's, 5l's
 * FREGTMP) *)
let sprintf = Printf.sprintf

(* a parallel move's: where a value goes (a register, a slot), what it
 * comes from (a place, or a constant made there) *)
type place = In_reg of int | In_slot of int
type source = At of place | Made of value
(* a double's: a floating-point register, a slot of the machine stack *)
type fplace = In_freg of int | In_dslot of int

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
  (* OPTIMIZATION (the link register): on arm, R14 a value's register
   * too (a sixth), in a function where nothing calls with BL but a
   * call (after which no value is in a register): no division (arm's
   * DIV and MOD are BL _div), no store through ml_modify, no handler
   * (ml_try). Saved at the entry, the link is reloaded at the return.
   * A loop's invariants were reloaded at each turn (mini-doom's span:
   * its screen, flat, colormap, bound and steps).
   * old: m.vregs always *)
  let calls_bl =
    memory
    || Hashtbl.fold (fun _ ins acc ->
         acc
         || match ins with
            | Op ((L.Div | L.Mod), _) -> true
            | SetField (_, _, x, false) | SetIndex (_, _, x, false) ->
                (match def x with Const _ | Blk _ | Symb _ | Zero -> false | _ -> true)
            | _ -> false) fn.defs false
  in
  let vregs = if m.arch = Arm && not calls_bl then m.vregs @ [ 14 ] else m.vregs in
  let loc, frame, dframe = Alloc.alloc fn ~nregs:(List.length vregs) ~nfregs:(List.length m.fregs) ~base in
  let slot_ref f i =
    let off = w * (i - f) in
    if m.arch = Arm64 && off < -256 then sprintf "\tSUB\t$%d, R%d, R19\n" (-off) vsp, "0(R19)" else "", sprintf "%d(R%d)" off vsp
  in
  let get_slot i r = line (fun f _ _ -> let pre, a = slot_ref f i in sprintf "%s\t%s\t%s, R%d\n" pre mov a r) in
  let put_slot r i = line (fun f _ _ -> let pre, a = slot_ref f i in sprintf "%s\t%s\tR%d, %s\n" pre mov r a) in
  let vreg c = List.nth vregs c in
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
    | Dmem _ -> failwith (fn.name ^ ": ssa: a word in a double's slot")
  in
  (* into register d: v, wherever it is *)
  let load v d = let r = src v d in if r <> d then ins "%s\tR%d, R%d" mov r d in
  (* the register to compute v in; then v put where it lives *)
  let dst v s = match loc v with Alloc.Reg c -> vreg c | _ -> s in
  let finish v r = match loc v with Alloc.Reg c -> if vreg c <> r then ins "%s\tR%d, R%d" mov r (vreg c) | Mem i -> put_slot r i | Nil -> ()
    | Dmem _ -> failwith (fn.name ^ ": ssa: a word in a double's slot") in
  (* a call's arguments: in R0.., those past the registers in the
   * callee's slots, above the top, and for a tail call copied down
   * into this frame's (simple's Gen, its Call) *)
  (* moves all at once, (where, from), sequenced: first a move whose
   * place no other still reads; a cycle broken by the scratch register
   * (a parallel copy, as a phi's or a call's arguments are) *)
  let r1, r2, r3 = match m.regs with [ a; b; c ] -> a, b, c | _ -> 1, 2, 3 in
  let place v =
    match loc v with
    | Alloc.Reg c -> Some (In_reg (vreg c))
    | Mem i -> Some (In_slot i)
    | Nil -> None
    | Dmem _ -> failwith (fn.name ^ ": ssa: a word in a double's slot")
  in
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
  (* float array b's i-th double's address into i's register, checked
   * when [checked] against its length: its words, by two on arm *)
  let findex checked b i =
    ins "%s\t$1, R%d" (shift Asr) i;
    if checked then begin
      ins "%s\t%d(R%d), R%d" mov (-w) b t;
      ins "%s\t$%d, R%d" (shift Lsr) (if w = 4 then 11 else 10) t;
      ins "CMP\tR%d, R%d" t i;
      ins "BLO\t2(PC)";
      ins "BL\tcaml_array_bound_error(SB)"
    end;
    ins "%s\t$3, R%d" (shift Lsl) i;
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
  (* the doubles (Unbox): in a floating-point register, or in a slot of
   * the machine stack past the handlers' records (the collector scans
   * the value stack, not this one), as the words' src, dst, finish *)
  let freg c = List.nth m.fregs c in
  let fget k r = line (fun _ _ c -> sprintf "\t%s\t%d(%s), F%d\n" fmov (record c !tries + (8 * k)) m.sp r) in
  let fput r k = line (fun _ _ c -> sprintf "\t%s\tF%d, %d(%s)\n" fmov r (record c !tries + (8 * k)) m.sp) in
  let fsrc v s =
    match loc v with
    | Alloc.Reg c -> freg c
    | Dmem k -> fget k s; s
    | _ -> failwith (fn.name ^ ": ssa: a double nowhere")
  in
  let fdst v s = match loc v with Alloc.Reg c -> freg c | _ -> s in
  let ffinish v r = match loc v with Alloc.Reg c -> if freg c <> r then ins "%s\tF%d, F%d" fmov r (freg c) | Dmem k -> fput r k | _ -> () in
  let itof = match m.arch with Arm -> "MOVWD" | Arm64 -> "SCVTFD" in
  (* a parallel move of doubles (a phi's), as pmove's; F0 and F1 the
   * scratch *)
  let fread s r = match s with In_freg x -> x | In_dslot k -> fget k r; r in
  let fwrite d s =
    match d with
    | In_freg x -> let r = fread s x in if r <> x then ins "%s\tF%d, F%d" fmov r x
    | In_dslot k -> let r = fread s 0 in fput r k
  in
  let fpmove (moves : (fplace * fplace) list) =
    let pending = ref (List.filter (fun ((d, s) : fplace * fplace) -> s <> d) moves) in
    while !pending <> [] do
      let reads d = List.exists (fun ((d', s) : fplace * fplace) -> d' <> d && s = d) !pending in
      match List.partition (fun ((d, _) : fplace * fplace) -> not (reads d)) !pending with
      | (d, s) :: free, busy -> fwrite d s; pending := free @ busy
      | [], (_, s) :: _ ->
          fwrite (In_freg 1) s;
          pending := List.map (fun ((d, s') : fplace * fplace) -> d, if s' = s then In_freg 1 else s') !pending
      | [], [] -> ()
    done
  in
  let fplace v = match loc v with Alloc.Reg c -> Some (In_freg (freg c)) | Dmem k -> Some (In_dslot k) | _ -> None in
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
  (* the write barrier (Gen's modify): x, in r, stored at the address
   * [field] puts in t; nothing for a constant (never young), nor in a
   * small block made since the last safepoint, young (fresh: a
   * closure's environment, a big record's fields, set after obj_block;
   * the runtime's young generation is at least 256 words) *)
  let fresh = ref [] in
  let modify blk x r field =
    match def x with
    | Const _ | Blk _ | Symb _ | Zero -> ()
    | _ when List.mem blk !fresh -> ()
    | _ ->
        let skip = glabel () in
        ins "AND\t$1, R%d, R0" r;
        branch_zero true 0 skip;
        ins "%s\tR%d, R0" mov r;
        field ();
        ins "BL\tml_modify(SB)";
        lab skip
  in
  let prim v (p : L.t) xs =
    match p, xs with
    (* a string's byte: the index untagged and added to its address *)
    (* OPTIMIZATION: on arm, an unchecked byte's address is the
     * instruction's, the index untagged by the shift of its register
     * offset (5a's R2->1(R1)): one instruction for three (mini-doom's
     * spans, three bytes a pixel) *)
    | ByteGet false, [ s; i ] when m.arch = Arm ->
        let a = src s r1 in let b = src i r2 in let d = dst v r3 in
        ins "MOVBU\tR%d->1(R%d), R%d" b a d;
        ins "%s\t$1, R%d" (shift Lsl) d;
        ins "ORR\t$1, R%d" d;
        finish v d
    | ByteSet false, [ s; i; x ] when m.arch = Arm ->
        let a = src s r1 in let b = src i r2 in let c = src x r3 in
        ins "%s\t$1, R%d, R%d" (shift Asr) c t;
        ins "MOVB\tR%d, R%d->1(R%d)" t b a
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
    (* two floats compared (Gen's FloatCmp) *)
    | FloatCmp r, [ x; y ] ->
        let a = src x r1 in let b = src y r2 in let d = dst v r3 in
        ins "%s\t0(R%d), F0" fmov a;
        ins "%s\t0(R%d), F1" fmov b;
        ins "%s\tF1, F0" (match m.arch with Arm -> "CMPD" | Arm64 -> "FCMPD");
        let c =
          match r with L.Eq -> "EQ" | Ne -> "NE" | Lt -> "MI" | Le -> "LS" | Gt -> "GT" | Ge -> "GE" in
        (match m.arch with
         | Arm -> ins "MOVW\t$1, R%d" d; ins "MOVW.%s\t$3, R%d" c d
         | Arm64 -> ins "MOV\t$3, R%d" d; ins "B%s\t2(PC)" c; ins "MOV\t$1, R%d" d);
        finish v d
    (* old: (and without in_place) the runtime's, as before *)
    | ByteGet _, _ -> call_c "ml_string_get" xs; finish v 0
    | ByteSet _, _ -> call_c "ml_string_set" xs
    | StrLen, _ -> call_c "ml_string_length" xs; finish v 0
    | (Float2 f | Float1 f), _ -> call_c f xs; finish v 0
    | FloatOfInt, _ -> call_c "caml_floatofint" xs; finish v 0
    | IntOfFloat, _ -> call_c "caml_intoffloat" xs; finish v 0
    | FloatIndex c, _ -> call_c (if c then "ml_floatarray_get" else "ml_floatarray_unsafe_get") xs; finish v 0
    | FloatSetIndex c, _ -> call_c (if c then "ml_floatarray_set" else "ml_floatarray_unsafe_set") xs
    | FloatRound c, _ -> call_c (if c then "ceil_float" else "floor_float") xs; finish v 0
    | _ -> failwith (fn.name ^ ": ssa: a primitive's operands")
  in
  (* the same on doubles (Unbox), the operands' and the result's
   * registers the instruction's: no block loaded, none made *)
  let dprim v (p : L.t) xs =
    match p, xs with
    | Float2 f, [ x; y ] ->
        let a = fsrc x 0 in let b = fsrc y 1 in let d = fdst v 0 in
        ins "%s\tF%d, F%d, F%d"
          (match m.arch, f with
           | Arm, "caml_addfloat" -> "ADDD" | Arm, "caml_subfloat" -> "SUBD" | Arm, "caml_mulfloat" -> "MULD" | Arm, _ -> "DIVD"
           | Arm64, "caml_addfloat" -> "FADDD" | Arm64, "caml_subfloat" -> "FSUBD" | Arm64, "caml_mulfloat" -> "FMULD" | Arm64, _ -> "FDIVD")
          b a d;
        ffinish v d
    | FloatOfInt, [ x ] ->
        let a = src x r1 in let d = fdst v 0 in
        ins "%s\t$1, R%d, R%d" (shift Asr) a t;
        ins "%s\tR%d, F%d" itof t d;
        ffinish v d
    | IntOfFloat, [ x ] ->
        let a = fsrc x 0 in let d = dst v r2 in
        ins "%s\tF%d, R%d" (match m.arch with Arm -> "MOVDW" | Arm64 -> "FCVTZSD") a d;
        ins "%s\t$1, R%d" (shift Lsl) d;
        ins "ORR\t$1, R%d" d;
        finish v d
    | FloatCmp r, [ x; y ] ->
        let a = fsrc x 0 in let b = fsrc y 1 in let d = dst v r3 in
        ins "%s\tF%d, F%d" (match m.arch with Arm -> "CMPD" | Arm64 -> "FCMPD") b a;
        let c =
          match r with L.Eq -> "EQ" | Ne -> "NE" | Lt -> "MI" | Le -> "LS" | Gt -> "GT" | Ge -> "GE" in
        (match m.arch with
         | Arm -> ins "MOVW\t$1, R%d" d; ins "MOVW.%s\t$3, R%d" c d
         | Arm64 -> ins "MOV\t$3, R%d" d; ins "B%s\t2(PC)" c; ins "MOV\t$1, R%d" d);
        finish v d
    (* a Float.Array's double, loaded and stored: no new float, and no
     * write barrier (no pointer stored) *)
    | FloatIndex c, [ a; i ] ->
        let bb = src a r1 in load i r2; findex c bb r2;
        let d = fdst v 0 in ins "%s\t0(R%d), F%d" fmov r2 d; ffinish v d
    | FloatSetIndex c, [ a; i; x ] ->
        let bb = src a r1 in load i r2; findex c bb r2;
        ins "%s\tF%d, 0(R%d)" fmov (fsrc x 0) r2
    (* floor (or ceil) without a call: a double of 2^52 or more is whole
     * already (and an infinity, and nan: x itself); below, x + 2^52 -
     * 2^52 (x - 2^52 + 2^52 for a negative x) is x rounded to a whole
     * number, then one step down (up) if it went past x; a zero result
     * x times 0.0, the zero of x's sign (the runtime's signed_zero).
     * The constants the runtime's ml_round: 2^52, -2^52, 1.0, 0.0 *)
    | FloatRound up, [ x ] ->
        let xr = fsrc x m.fscratch in
        let big = glabel () and neg = glabel () and round = glabel () and ok = glabel () and fin = glabel () in
        let k off = ins "%s\t%d(R%d), F1" fmov off t in
        let cmp a b = ins "%s\tF%d, F%d" (match m.arch with Arm -> "CMPD" | Arm64 -> "FCMPD") a b in
        let op name a b d =
          ins "%s\tF%d, F%d, F%d" (match m.arch with Arm -> name | Arm64 -> "F" ^ name) a b d in
        ins "%s\t$ml_round(SB), R%d" mov t;
        k 0; cmp 1 xr; ins "BPL\t%s" big;
        k 8; cmp 1 xr; ins "BLE\t%s" big;
        k 0;
        ins "%s\t24(R%d), F0" fmov t;
        cmp 0 xr; ins "BLT\t%s" neg;
        op "ADDD" 1 xr 0; op "SUBD" 1 0 0; ins "B\t%s" round;
        lab neg;
        op "SUBD" 1 xr 0; op "ADDD" 1 0 0;
        lab round;
        k 16;
        cmp xr 0;
        if up then (ins "BGE\t%s" ok; op "ADDD" 1 0 0) else (ins "BLE\t%s" ok; op "SUBD" 1 0 0);
        lab ok;
        k 24; cmp 1 0; ins "BNE\t%s" fin;
        op "MULD" 1 xr 0; ins "B\t%s" fin;
        lab big;
        ins "%s\tF%d, F0" fmov xr;
        lab fin;
        ffinish v 0
    | _ -> failwith (fn.name ^ ": ssa: a double's operation")
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
    let doubles, words = List.partition (fun (phi, _) -> Hashtbl.mem fn.doubles phi) moves in
    pmove (List.filter_map (fun (phi, x) -> Option.map (fun d -> d, from x) (place phi)) words);
    fpmove (List.filter_map (fun (phi, x) ->
      match fplace phi, fplace x with Some d, Some s -> Some (d, s) | _ -> None) doubles)
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
    (* OPTIMIZATION: x / 2^k and x mod 2^k by shifts, the quotient
     * toward 0 as OCaml's (a negative x biased by 2^k - 1 first), not a
     * division: arm's is _div's loop, 32 turns (mini-doom's
     * fineangles / 4 at each of its sines) *)
    | (Div | Mod), Some n, _ when n > 1 && n land (n - 1) = 0 ->
        let k = let rec log i = if 1 lsl i = n then i else log (i + 1) in log 1 in
        let bits = 8 * w in
        let a = src x r1 in let d = dst v r3 in
        ins "%s\t$1, R%d, R%d" (shift Asr) a r2;
        ins "%s\t$%d, R%d, R%d" (shift Asr) (bits - 1) r2 t;
        ins "%s\t$%d, R%d" (shift Lsr) (bits - k) t;
        ins "ADD\tR%d, R%d" r2 t;
        ins "%s\t$%d, R%d" (shift Asr) k t;
        (if o = Div then ins "%s\t$1, R%d, R%d" (shift Lsl) t d
         else begin
           ins "%s\t$%d, R%d" (shift Lsl) k t;
           ins "SUB\tR%d, R%d, R%d" t r2 d;
           ins "%s\t$1, R%d" (shift Lsl) d
         end);
        ins "ORR\t$1, R%d" d;
        finish v d; true
    (* tagged: 2a+1 and 2n+1 is 2(a land n)+1, the same for or; 2a+1 xor
     * 2n keeps the tag (mini-doom's x land 63, a span's pixel) *)
    | (And | Or | Xor), Some n, _ | (And | Or | Xor), None, Some n ->
        let a = src (if small y <> None then x else y) r1 in let d = dst v r3 in
        let c = if o = Xor then 2 * n else (2 * n) + 1 in
        ins "%s\t$%d, R%d, R%d" (match o with And -> "AND" | Or -> "ORR" | _ -> "EOR") c a d;
        finish v d; true
    | (Lsl | Lsr | Asr), Some n, _ when n < 8 * w - 1 ->
        let a = src x r1 in let d = dst v r3 in
        (match o with
         | Lsl -> ins "SUB\t$1, R%d, R%d" a d; ins "%s\t$%d, R%d" (shift Lsl) n d
         | _ -> ins "%s\t$%d, R%d, R%d" (shift o) n a d);
        ins "ORR\t$1, R%d" d; finish v d; true
    | _ -> false
  in
  Array.iteri (fun i (b : block) ->
    lab (blabel b.id);
    let fuse = fused b in
    fresh := [];
    List.iter (fun v ->
      (match def v with
       | Alloc (_, xs) when List.length xs <= Gen.alloc_most -> fresh := [ v ]
       | CallC ("obj_block", [ _; n ])
         when (match def n with Const n -> n <= Gen.alloc_most | _ -> false) ->
           fresh := [ v ]
       | i when Alloc.safepoint i -> fresh := []
       | _ -> ());
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
      | SetField (k, blk, x, imm) ->
          let bb = src blk r1 in
          let r = src x r2 in
          ins "%s\tR%d, %d(R%d)" mov r (w * k) bb;
          if not imm then modify blk x r (fun () -> ins "ADD\t$%d, R%d, R%d" (w * k) bb t)
      | Index (blk, i) ->
          let bb = src blk r1 in load i r2; index bb r2;
          let d = dst v r3 in ins "%s\t0(R%d), R%d" mov r2 d; finish v d
      | SetIndex (blk, i, x, imm) ->
          let bb = src blk r1 in
          load i r2;
          index bb r2;
          let r = src x r3 in
          ins "%s\tR%d, 0(R%d)" mov r r2;
          if not imm then modify blk x r (fun () -> ins "%s\tR%d, R%d" mov r2 t)
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
      | Dprim (p, xs) -> dprim v p xs
      (* a block's double; the 0 of a slot never written, a phi's operand
       * on a path where its variable was not bound (never read) *)
      | Unbox x ->
          let d = fdst v 0 in
          (match def x with
           | Zero -> ins "%s\t$0, R%d" mov t; ins "%s\tR%d, F%d" itof t d
           | _ -> let a = src x r1 in ins "%s\t0(R%d), F%d" fmov a d);
          ffinish v d
      (* a double's block, taken as Alloc's (ml_alloc when there is no
       * room, which leaves the floating-point registers) *)
      | Box x ->
          let slow = glabel () and ok = glabel () in
          take float_words float_tag slow;
          ins "%s\tF%d, 0(R0)" fmov (fsrc x 0);
          ins "B\t%s" ok;
          lab slow;
          cargs := max !cargs 2;
          ins "%s\t$%d, R0" mov float_words;
          ins "%s\t$%d, R%d" mov float_tag t;
          ins "%s\tR%d, %d(%s)" mov t (2 * w) m.sp;
          ins "%s\tR%d, ml_vsp(SB)" mov vsp;
          ins "BL\tml_alloc(SB)";
          ins "%s\tF%d, 0(R0)" fmov (fsrc x 0);
          lab ok;
          finish v 0
      | Caught _ -> finish v 0
      | TryExit k -> at k (3 * w) (fun o -> sprintf "%s\t%d(%s), R%d" mov o m.sp t); ins "%s\tR%d, ml_handler(SB)" mov t) b.body;
    (* OPTIMIZATION: no jump to the block written next, and a branch to
     * it the other way round (the condition negated): a jump a loop's
     * turn in mini-doom's spans, which mini-ld leaves.
     * old: ins "B\t%s" l always *)
    let next =
      if i + 1 < Array.length fn.blocks then blabel fn.blocks.(i + 1).id else "" in
    let jump l = if l <> next then ins "B\t%s" l in
    let negate = function L.Eq -> L.Ne | Ne -> Eq | Lt -> Ge | Ge -> Lt | Le -> Gt | Gt -> Le in
    match b.term with
    | Jmp s -> let l = edge b.id s ~alone:true in jump l
    | Br (v, tr, fl) ->
        let lt = edge b.id tr ~alone:false and lf = edge b.id fl ~alone:false in
        (match fuse with
         | Some (r, x, y) ->
             compare_with x y;
             if lt = next then ins "B%s\t%s" (cond (negate r)) lf
             else (ins "B%s\t%s" (cond r) lt; jump lf)
         | None ->
             let r = src v r1 in
             ins "CMP\t$1, R%d" r;
             if lt = next then ins "BEQ\t%s" lf else (ins "BNE\t%s" lt; jump lf))
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
  (* (the doubles' slots after the records, the whole kept a multiple of
   * 16, as arm64's SP must be) *)
  let msize = round (record c !tries + (8 * dframe)) 16 in
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
  List.iter (fun (lf : L.func) ->
    let fn = Unbox.func (Ssa_build.func lf) in
    Ssa_build.check fn;
    func m out fn lf) u.funcs;
  Buffer.contents out
