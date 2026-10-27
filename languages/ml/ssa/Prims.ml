(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Prims.mli *)

open Ssa
module L = Ir

type ctx = {
  name : string;
  arch : Asm.arch;
  w : int;
  mov : string;
  t : int;
  sp : string;
  fscratch : int;
  r1 : int;
  r2 : int;
  r3 : int;
  in_place : bool;
  ins : string -> unit;
  lab : string -> unit;
  label : unit -> string;
  src : value -> int -> int;
  load : value -> int -> unit;
  dst : value -> int -> int;
  finish : value -> int -> unit;
  fsrc : value -> int -> int;
  fdst : value -> int -> int;
  ffinish : value -> int -> unit;
  raw : value -> bool;
  shift : L.op -> string;
  take : int -> int -> string -> unit;
  call_c : string -> value list -> unit;
  need_bl : unit -> unit;
  need_cargs : int -> unit;
}

let make (m : ctx) =
  let ins fmt = Printf.ksprintf m.ins fmt in
  let lab = m.lab and glabel = m.label and src = m.src and load = m.load and dst = m.dst and finish = m.finish in
  let fsrc = m.fsrc and fdst = m.fdst and ffinish = m.ffinish and raw = m.raw and shift = m.shift in
  let take = m.take and call_c = m.call_c and need_bl = m.need_bl and need_cargs = m.need_cargs in
  let w = m.w and mov = m.mov and t = m.t and r1 = m.r1 and r2 = m.r2 and r3 = m.r3 and in_place = m.in_place in
  let fmov = match m.arch with Arm -> "MOVD" | Arm64 -> "FMOVD" in
  let float_words = 8 / w and float_tag = 253 in
  let itof = match m.arch with Arm -> "MOVWD" | Arm64 -> "SCVTFD" in
  (* float array b's i-th double's address into i's register, checked
   * when [checked] against its length: its words, by two on arm; the
   * offset to add, returned.
   * OPTIMIZATION (arm): from i tagged, 2k+1, b + 8k is b + 4i - 4: one
   * ADD of i shifted, the -4 in the load's offset; and 0 <= k < n is
   * i < 2n unsigned, 2n the header's size shifted by 10 (n doubles are
   * 2n words). A Float.Array's loop, 3 instructions an access less
   * (mini-rebirth's ladder, mini-virtuaracing's rows).
   * old: the arm64 way below, on both *)
  let findex checked b i =
    if m.arch = Arm then begin
      if checked then begin
        ins "MOVW\t-4(R%d), R%d" b t;
        ins "SRL\t$10, R%d" t;
        ins "CMP\tR%d, R%d" t i;
        ins "BLO\t2(PC)";
        ins "BL\tcaml_array_bound_error(SB)"
      end;
      ins "ADD\tR%d<<2, R%d, R%d" i b i;
      -4
    end else begin
    ins "%s\t$1, R%d" (shift Asr) i;
    if checked then begin
      ins "%s\t%d(R%d), R%d" mov (-w) b t;
      ins "%s\t$%d, R%d" (shift Lsr) (if w = 4 then 11 else 10) t;
      ins "CMP\tR%d, R%d" t i;
      ins "BLO\t2(PC)";
      ins "BL\tcaml_array_bound_error(SB)"
    end;
    ins "%s\t$3, R%d" (shift Lsl) i;
    ins "ADD\tR%d, R%d" b i;
    0
    end
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
    (* an untagged byte (Untag): as below, its result not tagged, its index
     * as it is when untagged *)
    | ByteGet checked, [ s; i ] when raw v ->
        let a = src s r1 in let b = src i r2 in let d = dst v r3 in
        if (not checked) && m.arch = Arm then
          ins "MOVBU\tR%d%s(R%d), R%d" b (if raw i then "<<0" else "->1") a d
        else begin
          if raw i then ins "%s\tR%d, R%d" mov b t else ins "%s\t$1, R%d, R%d" (shift Asr) b t;
          if checked then byte_bound a;
          ins "ADD\tR%d, R%d" a t;
          ins "MOVBU\t0(R%d), R%d" t d
        end;
        finish v d
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
    (* (an untagged index or byte, Untag's, as it is: R2<<0(R1), the
     * byte's register stored) *)
    | ByteSet false, [ s; i; x ] when m.arch = Arm ->
        let a = src s r1 in let b = src i r2 in let c = src x r3 in
        let c = if raw x then c else (ins "%s\t$1, R%d, R%d" (shift Asr) c t; t) in
        if raw i then ins "MOVB\tR%d, R%d<<0(R%d)" c b a else ins "MOVB\tR%d, R%d->1(R%d)" c b a
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
        if raw i then ins "%s\tR%d, R%d" mov b t else ins "%s\t$1, R%d, R%d" (shift Asr) b t;
        if checked then byte_bound a;
        let c = src x r3 in
        ins "ADD\tR%d, R%d" a t;
        let c = if raw x then c else (ins "%s\t$1, R%d, R%d" (shift Asr) c r3; r3) in
        ins "MOVB\tR%d, 0(R%d)" c t
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
    (* an int32's operation: its 32 bits loaded from the operands'
     * blocks (arm64's sign-extended, zero-extended for a logical shift
     * right), computed in a word, the low 32 stored in a new block; the
     * runtime's when there is no room (arm64's word holds an int32's
     * wrap: the low 32 bits of a sum or a product are the same) *)
    | Int32 ("int32_to_int", _), [ x ] when in_place ->
        let a = src x r1 in let d = dst v r2 in
        ins "MOVW\t0(R%d), R%d" a d;
        ins "%s\t$1, R%d" (shift Lsl) d;
        ins "ORR\t$1, R%d" d;
        finish v d
    | Int32 (f, _), x :: rest when in_place ->
        let slow = glabel () and ok = glabel () in
        let a = src x r1 in
        let load32 r = ins "%s\t0(R%d), R%d" (if f = "int32_shift_right_unsigned" && m.arch = Arm64 then "MOVWU" else "MOVW") r r3 in
        (match f, rest with
         | "int32_of_int", [] -> ins "%s\t$1, R%d, R%d" (shift Asr) a r3
         | "int32_neg", [] ->
             load32 a;
             (match m.arch with Arm -> ins "RSB\t$0, R%d, R%d" r3 r3 | Arm64 -> ins "NEG\tR%d, R%d" r3 r3)
         | ("int32_shift_left" | "int32_shift_right" | "int32_shift_right_unsigned"), [ y ] ->
             load32 a;
             let b = src y r2 in
             ins "%s\t$1, R%d, R%d" (shift Asr) b r2;
             let o = match f with "int32_shift_left" -> L.Lsl | "int32_shift_right" -> L.Asr | _ -> L.Lsr in
             ins "%s\tR%d, R%d, R%d" (shift o) r2 r3 r3
         | _, [ y ] ->
             load32 a;
             let b = src y r2 in
             ins "MOVW\t0(R%d), R%d" b r2;
             let o = match f with
               | "int32_add" -> "ADD" | "int32_sub" -> "SUB" | "int32_mul" -> "MUL"
               | "int32_and" -> "AND" | "int32_or" -> "ORR" | _ -> "EOR" in
             ins "%s\tR%d, R%d, R%d" o r2 r3 r3
         | _ -> failwith (m.name ^ ": ssa: an int32's operands"));
        take 1 254 slow;
        ins "MOVW\tR%d, 0(R0)" r3;
        ins "B\t%s" ok;
        lab slow;
        call_c f xs;
        lab ok;
        finish v 0
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
    | FloatCall (f, _, _), _ -> call_c f xs; finish v 0
    | Int32 (f, _), _ -> call_c f xs; finish v 0
    | _ -> failwith (m.name ^ ": ssa: a primitive's operands")
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
    (* -x and abs x: arm64's FNEGD and FABSD; arm's 5a has neither, the
     * double's sign bit flipped or cleared in memory, the C arguments'
     * place on the machine stack (a frame: bl).
     * old: a new block, the sign bit of its high word *)
    | Float1 f, [ x ] ->
        let a = fsrc x 0 in let d = fdst v 0 in
        let neg = f = "caml_negfloat" in
        (match m.arch with
         | Arm64 -> ins "%s\tF%d, F%d" (if neg then "FNEGD" else "FABSD") a d
         | Arm ->
             need_bl ();
             need_cargs (2);
             ins "MOVD\tF%d, 4(%s)" a m.sp;
             ins "MOVW\t8(%s), R%d" m.sp t;
             ins "%s\t$0x80000000, R%d" (if neg then "EOR" else "BIC") t;
             ins "MOVW\tR%d, 8(%s)" t m.sp;
             ins "MOVD\t4(%s), F%d" m.sp d);
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
        let bb = src a r1 in load i r2; let k = findex c bb r2 in
        let d = fdst v 0 in ins "%s\t%d(R%d), F%d" fmov k r2 d; ffinish v d
    | FloatSetIndex c, [ a; i; x ] ->
        let bb = src a r1 in load i r2; let k = findex c bb r2 in
        ins "%s\tF%d, %d(R%d)" fmov (fsrc x 0) k r2
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
    (* C's exp on doubles: the arguments at w(SP), w+8(SP) (5c's and
     * 7c's), the result in F0 *)
    | FloatCall (_, f, n), _ ->
        need_cargs ((8 * n / w));
        List.iteri (fun k x ->
          ins "%s\tF%d, %d(%s)" fmov (fsrc x 0) (w + (8 * k)) m.sp) xs;
        ins "BL\t%s(SB)" f;
        ffinish v 0
    | _ -> failwith (m.name ^ ": ssa: a double's operation")
  in
  prim, dprim
