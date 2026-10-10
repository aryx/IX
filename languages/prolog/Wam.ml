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
 *     app([], L, L).                          mini-prolog -S
 *     app([H|T], L, [H|R]) :- app(T, L, R).   (tests/code.out)
 *
 *     app/3:
 *         switch_on_term A1          by what the first argument is:
 *             a variable: L1|L2        both clauses, a choice point
 *             .(...): L2               a list: the second alone
 *             []: L1                   the first alone
 *             another: fail
 *     L1: get_constant [], A1        A1 is [], or is bound to it
 *         get_variable X4, A2        L
 *         get_value X4, A3           A3 unified with it
 *         proceed                    back to the caller
 *     L2: get_list A1                read if A1 is a list, else write
 *         unify_variable X4          H
 *         unify_variable X5          T
 *         get_variable X6, A2        L
 *         get_list A3                [H|R]
 *         unify_value X4             H again: the same as A1's
 *         unify_variable X7          R
 *         put_value X5, A1           the body's goal: app(T, L, R)
 *         put_value X6, A2
 *         put_value X7, A3
 *         execute app/3              the last call is a jump
 *
 * Called as app([a], [b], Z), the switch goes to L2 with no choice
 * point. get_list A1 finds a list: read mode, X4 = a and X5 = []. A3
 * is the unbound Z: write mode, so Z is bound to a new list cell whose
 * head is X4 and whose tail X7 is a new variable. The result exists
 * before the recursion, with a hole in it, and the call that follows
 * fills the hole: that is why the call can be the last thing done, a
 * jump with the registers loaded, and why app runs in a loop's space
 * where a functional language's append needs a stack. The same eleven
 * instructions, called as app(X, Y, [a]), find A1 unbound and A3 a
 * list: the modes are the other way round, and the list is split.
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
 *   get_level and cut.
 *
 * cs-history:
 * David H. D. Warren wrote the first Prolog compiler, for the DEC-10
 * (Edinburgh, 1977), and in 1983, at SRI, a short report with an
 * instruction set that a Prolog could be compiled to on any machine,
 * run there by an interpreter of it or translated to the machine's
 * own code. The report is terse: it gives the machine whole and few
 * of its reasons. Hassan Ait-Kaci's tutorial (1991) rebuilt it in
 * steps, from a machine that only unifies two terms to all of it,
 * and is the way in.
 *
 * why-win:
 * Nearly every Prolog since compiles to it or to something close.
 * What it got right together: the head's unification compiled away
 * (get_constant is a comparison, not a call of a general unify with
 * a term to walk); arguments in registers, so a clause whose body is
 * one call allocates nothing; the last call a jump; choice points
 * made only when the index leaves more than one clause; and memory
 * given back at once on backtracking, a stack's way. And it is a
 * small thing to implement: an interpreter of it is the size of this
 * directory's Wam_machine.
 *
 * others:
 * In the report a term is cells in the machine's own heap, each a
 * tag and a value (a reference, a structure, a list, a constant),
 * and the environments and the choice points share one stack, so a
 * choice point also protects what is below it. Here they are OCaml's
 * values (above). SWI-Prolog's machine is not the WAM but descends
 * from one of the same year, simpler, with the arguments on the
 * stack (the ZIP of Bowen, Byrd and Clocksin; from memory). The
 * other abstract machines of ix, to compare: Pcode (a stack, static
 * links), Forth's threaded code, Smalltalk's bytecode, Scheme_secd.
 *
 * References: David H. D. Warren, "An Abstract Prolog Instruction
 * Set" (Technical Note 309, SRI International, 1983); Hassan
 * Ait-Kaci, "Warren's Abstract Machine: A Tutorial Reconstruction"
 * (MIT Press, 1991), free on the web since. *)

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
