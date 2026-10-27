(* The primitives open-coded: a runtime's function (ml_string_get,
 * caml_addfloat, int32_add, floor_float, exp) written as the
 * processor's instructions where the program uses it, for Emit, which
 * calls prim for each Ir primitive (Ssa.Prim) and dprim for each one
 * on doubles (Ssa.Dprim, Unbox's). Lower decides which primitive is
 * an Ir instruction of its own (Lower.mli: strings_in_place,
 * floats_in_place, ints_in_place); simple's Gen writes the same ones
 * on its stack; this is ssa's.
 *
 * Each has two paths: the processor's instructions, and a call of the
 * runtime's function when there is no room in the heap for the
 * result's block (or, with mini-ml -calls, always):
 *
 *     Int32.add a b, in place (arm)            -calls
 *
 *     MOVW  0(R4), R3     a's bits             MOVW  R4, R0
 *     MOVW  0(R5), R2     b's                  MOVW  R5, 8(R13)
 *     ADD   R2, R3, R3                         BL    int32_add(SB)
 *     (take: ml_hp moved by 8, checked              the C function's
 *      against ml_limit, else BL int32_add)         add, then ml_alloc
 *     MOVW  $1278, ...    the header           (about 170 a call)
 *     MOVW  R3, 0(R0)     the sum, its block
 *
 * 14 instructions on the usual path. On doubles (dprim) there is no
 * block at all: the operands' and the result's registers are the
 * instruction's.
 *
 * terminology:
 * Open coding, not inlining. Inlining copies a function's body into
 * its caller (Lower's, for ML functions); a runtime's function is C,
 * in another object, and its body is not the compiler's to copy. Here
 * the compiler knows what each primitive means, one by one, and
 * writes its own sequence. MacLisp's compiler open-coded car, cdr and
 * the arithmetic in the 1970s; a C compiler's are its intrinsics
 * (gcc writes a memcpy of 8 bytes as two moves, sqrt as an
 * instruction); ocamlopt's Cmmgen open-codes its % primitives.
 *
 * The functions were Emit's own (Emit.func's locals); [ctx] is what
 * of Emit.func they read: the machine's few fields, how an
 * instruction and a label are written, where a value is read from and
 * put (src, dst, finish, and the doubles' fsrc, fdst, ffinish), a
 * block taken from the heap (take), a C call (call_c), and the two
 * things they tell Emit (need_bl: a BL that needs the link saved;
 * need_cargs: room for C's arguments). *)

type ctx = {
  name : string;                (* the function's, for an error *)
  arch : Asm.arch;
  w : int;                      (* a word's bytes *)
  mov : string;                 (* a word's move: MOVW or MOV *)
  t : int;                      (* the scratch register *)
  sp : string;                  (* the machine stack's *)
  fscratch : int;               (* the third scratch double's *)
  r1 : int;
  r2 : int;
  r3 : int;                     (* the scratch registers *)
  in_place : bool;              (* Gen.alloc_in_place: a block taken here *)
  ins : string -> unit;
  lab : string -> unit;
  label : unit -> string;       (* a new label *)
  src : Ssa.value -> int -> int;
  load : Ssa.value -> int -> unit;
  dst : Ssa.value -> int -> int;
  finish : Ssa.value -> int -> unit;
  fsrc : Ssa.value -> int -> int;
  fdst : Ssa.value -> int -> int;
  ffinish : Ssa.value -> int -> unit;
  raw : Ssa.value -> bool;      (* untagged (Untag) *)
  shift : Ir.op -> string;      (* a shift's mnemonic *)
  take : int -> int -> string -> unit;   (* n words, a tag, the slow path's label *)
  call_c : string -> Ssa.value list -> unit;
  need_bl : unit -> unit;
  need_cargs : int -> unit;
}

(* prim v p xs: v, Ir primitive p of xs, its result's block if it has
 * one; dprim the same on doubles *)
val make :
  ctx -> (Ssa.value -> Ir.t -> Ssa.value list -> unit) * (Ssa.value -> Ir.t -> Ssa.value list -> unit)
