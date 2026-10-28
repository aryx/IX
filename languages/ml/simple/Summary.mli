(* A unit's summary, X.inline beside its object: what another unit needs
 * to inline X's small functions (Lower.inline_most), as OCaml's .cmx
 * gives ocamlopt. Written when X is compiled, read when a unit that
 * uses X is and its object goes beside X's: a unit of the same build
 * directory, which its .depend orders. Not another directory's (a
 * library's, lib_core's): no rule makes a program's unit again when a
 * library's source changes, and the copy would be stale.
 *
 * A function's tree is Scope's, its names resolved: a toplevel
 * function's body names only its parameters, globals and primitives,
 * which mean the same in any unit (Lower.imports). Its types are taken
 * out (Lower reads none: they are graphs, and would be most of the
 * file); the places in the text the typing answered for (Lower's
 * immediates, string_eqs, float_cmps) come with it, which the reader
 * moves apart from its own (respan).
 *
 * The digest is of X.ml's text: a summary of another text is not
 * read. The .depend (mkfiles/depend.rc: mkprog's, mklib's, lib_core's
 * mkfile...) says the order, and that a unit is made again when one it
 * uses is: without its line a build could make the unit first, copy
 * nothing, and another build copy (the objects not the same bytes).
 *
 * others:
 * OCaml's .cmx (ocamlopt, since 1996) holds a unit's functions'
 * approximations, the bodies of the small ones among them (Clambda's,
 * -inline), found in the -I directories, and ocamldep -native's lines
 * make a unit depend on the .cmx of those it names; -opaque turns it
 * off, for fewer rebuilds. The stdlib's .cmx are read too: it is
 * installed, not edited, where lib_core is ix's own.
 * flambda's .cmx holds more. ocamlc never inlines across units. *)

type entry = {
  global : string;                (* its global's symbol, X.f *)
  params : Scope.pattern list;
  body : Scope.expr;
  size : int;                     (* Lower's size, the copies it makes counted *)
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

(* the tree without its types: a constructor's, a label's, a
 * primitive's, a constraint's *)
val strip : Scope.expr -> Scope.expr
val strip_pattern : Scope.pattern -> Scope.pattern

(* the tree's places in the text moved by f *)
val respan : (Ast.span -> Ast.span) -> Scope.expr -> Scope.expr

(* the units whose values (or exceptions) the items name: those whose
 * summaries a unit reads, and so its .depend's (mini-ml -depend) *)
val uses : Scope.item list -> string list

val to_string : t -> string
(* None: not a summary of this compiler's *)
val of_string : string -> t option
