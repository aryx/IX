(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* The stack machine Lower compiles a function to, as types. Its values
 * are integers of 1, 2, 4 or 8 bytes, signed or not, and floats of 4
 * or 8 ([ty]); a structure's value, a union's (and on arm a vlong's, a
 * structure to 5c) is its address, and a copy moves its bytes. Every
 * operation takes its operands from the top of the stack and pushes
 * its result, the first operand the deeper. Opti and Peep rewrite this
 * code, Gen writes its assembly.
 *
 * A function, as mini-cc -simple -dir prints it (int for I (4, true)):
 *
 *     int f(int x, int y) { return x + y * 2; }
 *
 *     Lea y+4(FP); Load int       y                     the stack: y
 *     Int 2; Op (Mul, int)        y * 2                 y*2
 *     Lea x+0(FP); Load int       x                     y*2 x
 *     Swap                        the operands in order x y*2
 *     Op (Add, int)                                     x+y*2
 *     Ret (Some int)
 *
 * and with -O, after Opti's passes, their forms at the end of [t]:
 *
 *     LoadAt (y+4(FP), int); OpImm (Ashl, int, 1)
 *     LoadAt (x+0(FP), int); Op (Add, int); Ret (Some int)
 *
 * design:
 * The machine is mini-ml's Ir with what C adds. A variable has an
 * address, which a program may take: so there is no Get of a slot
 * but the address pushed (Lea), then a Load or a Store through it,
 * and it takes a pass (Opti's places) to see that most addresses
 * are used once and at once. And a value has a size and a sign,
 * where every ML value is a word: each operation says its type,
 * since the same bits add, compare and extend differently as a
 * char, an unsigned or a double. The trees have no types left when
 * they reach here but these: [ty] is what a machine needs to know
 * of C's types. *)

(* -dir's printer (show) is derived (dune: ppx_deriving; mini-ml: mlpp);
 * this is what a compiler without deriving is left with, as xix does *)
let show _ = "NO DERIVING"
[@@warning "-32"]

type ty = I of int * bool | F of int      (* bytes, signed; bytes *) [@@deriving show]

(* a place: the assembler's; its printer (for the derived ones) Show_asm's *)
type mem = Asm.mem
let pp_mem = Show_asm.pp_mem

type target = Direct of mem | Indirect [@@deriving show]

type t =
  | Int of int64 * ty                 (* a constant *)
  | Flt of float * ty
  | Lea of mem             (* a global's, an auto's, a parameter's address *)
  | Load of ty                        (* the address on top by its value *)
  | Store of ty                       (* address value: the value stored, and left *)
  | Copy of int                       (* dst src: n bytes copied, dst left *)
  | Op of Tree.binop * ty             (* a b: a op b, of the operands' type; a relation 1 or 0 *)
  | Neg of ty                         (* arm64's; 5c's front end makes them 0-x and -1^x *)
  | Com of ty
  | Cvt of ty * ty                    (* the top from a type to another *)
  | Dup | Drop | Swap | Over          (* a: a a; a: ; a b: b a; a b: a b a *)
  | Arg of int * ty                   (* the top stored at the outgoing offset *)
  | ArgBlock of int * int             (* the block on top copied there, n bytes *)
  | Call of target * ty option * ty option
                                      (* the name, or the address on top; the first
                                         argument's type if in R0; the result's *)
  | Label of int | Jmp of int
  | Jz of int | Jnz of int            (* an integer popped *)
  | Ret of ty option                  (* the value on top, returned *)
  (* the forms opti's passes make of the ones above (Opti.mli) *)
  | LoadAt of mem * ty     (* lea m; load t *)
  | StoreAt of mem * ty    (* the top stored at m, left *)
  | Put of ty                         (* store t; drop *)
  | PutAt of mem * ty      (* storeat m t; drop *)
  | OpImm of Tree.binop * ty * int64  (* int c t; op o t: c an immediate *)
  | Br of Tree.binop * ty * int64 option * bool * int
                                      (* op o t (a relation), then jnz l (true) or jz l
                                         (false): a o b, or a o c *)
  | GetReg of int * ty                (* a variable kept in the k-th register of its kind *)
  | SetReg of int * ty                (* the top into it *)
  | KeepReg of int * ty               (* the top into it, left *)
[@@deriving show]

(* locals: the autos' and the temporaries' bytes; args: the outgoing
 * area's; r0: where the function stores R0 at its entry *)
type func = {
  name : Tree.sym;
  locals : int;
  args : int;
  r0 : (mem * ty) option;
  code : t list;
}
