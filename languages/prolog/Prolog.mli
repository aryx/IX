(* Prolog's terms (docs/plans/plan_prolog.md): what a program and its
 * data are both made of, the operators a text is read and written by,
 * and a term written.
 *
 * A variable is a cell, empty or bound to a term; binding it is the
 * machine's (Prolog_machine keeps the trail that undoes it). A list is
 * '.'(Head, Tail) ended by the atom []; a text between double quotes
 * is the list of its characters' codes. There are no floats. *)

type term =
  | Atom of string
  | Int of int                    (* OCaml's: 63 bits, 31 by mini-ml on arm *)
  | Var of var
  | Struct of string * term list  (* the functor's name, its arguments (one at least) *)
  | Local of int                  (* in a stored clause only: its k-th variable *)
and var = { id : int; mutable value : term option }

(* a new variable, unbound *)
val fresh : unit -> term

(* the last variable made: its number (they grow) *)
val newest : unit -> int

(* the term a bound variable stands for, through any chain of them *)
val deref : term -> term

val nil : term
val cons : term -> term -> term
val of_list : term list -> term

(* None: not a list, or its end not known yet *)
val to_list : term -> term list option

(* a text as the list of its codes *)
val of_string : string -> term

(* an atom's or a number's text, or a list of codes' or of characters' *)
val text_of : term -> string option

(* The operators: f is the operator, x an argument of a lower priority,
 * y of the same or lower. No postfix one is kept (xf, yf: ignored). *)
type fixity = Xfx | Xfy | Yfx | Fy | Fx | Xf | Yf

type ops = { prefix : (string, int * fixity) Hashtbl.t; infix : (string, int * fixity) Hashtbl.t }

(* the standard's table *)
val default_ops : unit -> ops

(* op/3: a priority of 0 removes it *)
val add_op : ops -> int -> fixity -> string -> unit

val fixity_of_string : string -> fixity option
val string_of_fixity : fixity -> string

(* write's text, or writeq's (quoted: an atom as it must be to be read
 * back). Operators and lists as they are written in a program; an
 * unbound variable is _G and its number; Local k and '$VAR'(k) are a
 * letter (A, B...). *)
val to_string : ops -> quoted:bool -> term -> string

val atom_text : bool -> string -> string

(* the standard order: variables, numbers, atoms, compound terms (by
 * arity, name, arguments) *)
val compare : term -> term -> int

(* its unbound variables, each once, in the order met *)
val variables : term -> term list

(* the same term with new variables for its unbound ones *)
val copy : term -> term

val is_lower : char -> bool
val is_upper : char -> bool
val is_digit : char -> bool
val is_alnum : char -> bool
val is_symbol : char -> bool
