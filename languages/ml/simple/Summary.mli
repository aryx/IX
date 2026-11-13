(* A unit's summary, X.inline, which is beside its object. It holds
 * what another unit needs to inline X's small functions
 * (Lower.inline_most), as OCaml's .cmx does for ocamlopt. It is written
 * when X is compiled, and read when a unit that uses X is compiled and
 * its object goes beside X's. That unit is in the same build
 * directory, whose .depend orders them. A unit of another directory (a
 * library's, such as lib_core's) does not read it: no rule makes a
 * program's unit again when a library's source changes, so the copy
 * would be stale.
 *
 * A function's tree is Scope's, with its names resolved. A toplevel
 * function's body names only its parameters, globals and primitives,
 * which mean the same in any unit (Lower.imports). Its types are taken
 * out: Lower reads none, and since they are graphs they would be most
 * of the file. The places in the text that the typing gave answers for
 * (Lower's immediates, string_eqs and float_cmps) come with the tree,
 * and the reader moves them apart from its own places (respan).
 *
 * The digest is of X.ml's text, so a summary of another text is not
 * read. The .depend (made by mkfiles/depend.rc, which mkprog's,
 * mklib's and lib_core's mkfiles use...) says the order. It also says
 * that a unit is made again when a unit it uses is. Without that line,
 * one build could make the unit first and copy nothing, and another
 * build could copy, and the objects would not have the same bytes.
 *
 * others:
 * OCaml's .cmx (ocamlopt, since 1996) holds the approximations of a
 * unit's functions, which include the bodies of the small ones (in
 * Clambda's form; see -inline). It is found in the -I directories, and
 * ocamldep -native's lines make a unit depend on the .cmx of the units
 * it names; -opaque turns this off, for fewer rebuilds. The stdlib's
 * .cmx are read too, because the stdlib is installed, not edited,
 * whereas lib_core is ix's own.
 * flambda's .cmx holds more. ocamlc never inlines across units. *)

type entry = {
  global : string;                (* the symbol of its global, X.f *)
  params : Scope.pattern list;
  body : Scope.expr;
  size : int;                     (* Lower's size, with the copies it makes *)
  forced : bool;                  (* marked [@inline]: inlined at any size *)
}

type t = {
  digest : string;                (* X.ml's text, Digest.to_hex *)
  entries : entry list;
  immediates : Ast.span list;     (* Typing's answers, by place in X.ml *)
  strings : Ast.span list;
  floats : Ast.span list;
  min_max : (string * string) list;
  constants : (string * Scope.expr) list;   (* Fold's: a global's symbol, its constant *)
}

(* the tree without its types: those of the constructors, labels,
 * primitives and constraints *)
val strip : Scope.expr -> Scope.expr
val strip_pattern : Scope.pattern -> Scope.pattern

(* the tree, with its places in the text moved by f *)
val respan : (Ast.span -> Ast.span) -> Scope.expr -> Scope.expr

(* the units whose values (or exceptions) the items name. They are the
 * units whose summaries a unit reads, and so they are the ones in its
 * .depend (mini-ml -depend). *)
val uses : Scope.item list -> string list

val to_string : t -> string
(* None when it is not a summary written by this compiler *)
val of_string : string -> t option
