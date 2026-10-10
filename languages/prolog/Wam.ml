(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* Warren's abstract machine (docs/plans/plan_prolog.md, stage 5): its
 * instructions, as Warren's 1983 report and Ait-Kaci's tutorial name
 * them. A clause is compiled to them (Wam_compile) and Wam_machine runs
 * them.
 *
 * A clause's head is get instructions, one an argument: each takes the
 * argument register Ai and unifies it with what the head has there. A
 * goal of its body is put instructions, which load the Ai, then a call.
 * A structure's arguments are unify instructions, in one of two modes:
 * read, when the structure is there to be matched, and write, when a
 * variable was there and the structure is built for it.
 *
 * What differs from the report, and why:
 * - The terms are Prolog's (OCaml's heap), not cells in the machine's
 *   own heap: the built-ins, the reader and the printer are the first
 *   machine's. So a structure in write mode is gathered and made when
 *   its last argument is given; an environment is an OCaml record that
 *   the collector frees, with no trimming; no variable lives in the
 *   stack, so there is no put_unsafe_value and no unify_local_value.
 * - get_list and put_list are get_structure and put_structure of ./2
 *   (the listing says get_list).
 * - A clause's code is compiled once and kept apart; a predicate is the
 *   index over its clauses: try, retry and trust with an address, never
 *   try_me_else. So assert and retract only make the index again, and a
 *   call that is running keeps the index it started with.
 * - The index is on the first argument, by one switch_on_term that has
 *   the constants' and the structures' tables in it.
 * - A disjunction, an if-then-else and a negation are a predicate of
 *   their own ('$aux', made by the compiler), their cut the clause's by
 *   get_level and cut. *)

type reg = X of int | Y of int  (* a temporary (the Ai are the first X), a permanent: in the environment *)

type instr =
  (* the head: against the argument register Ai *)
  | Get_variable of reg * int
  | Get_value of reg * int
  | Get_constant of Prolog.term * int   (* an atom or a number *)
  | Get_structure of string * int * int (* f/n, the register: read mode, or write if a variable is there *)
  (* a goal's arguments: Ai loaded *)
  | Put_variable of reg * int           (* a new variable, in both *)
  | Put_value of reg * int
  | Put_constant of Prolog.term * int
  | Put_structure of string * int * int (* write mode; the register gets it *)
  (* a structure's arguments, by the mode *)
  | Unify_variable of reg
  | Unify_value of reg
  | Unify_constant of Prolog.term
  | Unify_void of int
  (* control *)
  | Allocate of int                     (* an environment of n permanent variables *)
  | Deallocate
  | Call of pred                        (* the continuation is the next instruction *)
  | Execute of pred                     (* the last call: the continuation is kept *)
  | Proceed
  | Builtin of string * int * (Prolog_machine.t -> Prolog.term array -> bool) (* OCaml's, in line: the X are kept *)
  | Fail
  (* the choice points *)
  | Try of addr                         (* a choice point: the arguments, the next instruction *)
  | Retry of addr
  | Trust of addr                       (* the last: the choice point goes *)
  | Switch_on_term of switch
  (* the cut *)
  | Neck_cut                            (* before the first call *)
  | Get_level of reg                    (* the choice points' height at the call, kept *)
  | Cut of reg
  (* catch/3's clause *)
  | Catch_enter of reg * reg            (* the catcher, the recovery: the environment is marked *)
  | Catch_exit
  | Stop                                (* an answer *)

and addr = { code : instr array; pc : int }

(* by the first argument: a variable, or the table of what it is *)
and switch = {
  on_var : addr;
  atoms : (string, addr) Hashtbl.t;
  ints : (int, addr) Hashtbl.t;
  structs : (string, addr) Hashtbl.t;   (* by the name: the arity is get_structure's to check *)
  other : addr;                         (* not in its table: the clauses with a variable there *)
}

and pred = {
  name : string;
  arity : int;
  mutable kind : kind;
  mutable entry : addr;
  mutable linked : Prolog_db.clause list;    (* the clauses [entry] was made of *)
  mutable codes : (int * instr array) list;  (* each one's code, by its id *)
}

and kind =
  | Unknown                             (* not looked for yet *)
  | Det of (Prolog_machine.t -> Prolog.term array -> bool)
  | User of Prolog_db.pred              (* [entry] is made again when its clauses change *)
  | Fixed                               (* the compiler's own: [entry] as it is *)
  | Meta                                (* call/N *)
