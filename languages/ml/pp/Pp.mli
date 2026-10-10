(* mlpp (plan_ml_bootstrap.md, decision 7): a file's text with mlpp's
 * constructs rewritten into OCaml, the rest of the text as it is. Where
 * the rewritten text moves the source's lines, a line # n "file" says
 * where the next line comes from, so that a compiler's errors name the
 * source's lines (and its columns: a copy starts at its column). A file
 * without constructs comes back unchanged.
 *
 * The constructs: [%bits "..."], a clause's whole pattern
 * or an expression (Bits); type t = [%mli] in a .ml, which takes the .mli's
 * "= ...", on the hole's line; [@@deriving show] after a group of types
 * (Derive); [@@class] after a record type, its methods (Derive). The
 * classes' dictionaries are a second rewrite's (classes, below).
 *
 * The second rewrite, on three lines (mini-ml -pp, with Prelude's
 * classes; its # lines left out):
 *
 *     let s = Prelude.show (1, [ 2; 3 ])
 *     let print [%using: 'a Prelude.show] (x : 'a) =
 *       print_string (Prelude.show x)
 *     let () = print [ 1; 2 ]
 *
 *     let s = Prelude.show (Prelude.show_pair Prelude.show_int
 *                             (Prelude.show_list Prelude.show_int))
 *               (1, [ 2; 3 ])
 *     let print (_u53 : 'a Prelude.show) (x : 'a) =
 *       print_string (Prelude.show _u53 x)
 *     let () = print (Prelude.show_list Prelude.show_int) [ 1; 2 ]
 *
 * What to write after show is known only from the argument's type,
 * int * int list: so this rewrite runs after Resolve and Typing
 * (CLI's classes), where the first needs the parser alone.
 * Prelude.mli has the classes' own story, Haskell's.
 *
 * Where it stands: mini-ml runs it on each file it compiles, between
 * the parser and Resolve, and mini-ml -pp prints its output, which is
 * how dune builds the same sources with OCaml (a preprocess action in
 * a dune file) and how merlin reads them. It is what lets ix be
 * written in one text for two compilers.
 *
 * design:
 * The text is rewritten, not the tree. A construct's node says where
 * it starts and stops in the file (Ast's spans), and its replacement
 * is put there, the rest copied byte for byte: no printer of OCaml
 * is needed (the tree would have to be printed back for OCaml to
 * read), the comments and the layout stay, and a file with no
 * construct is the same file. The # lines are C's preprocessor's
 * trick, and yacc's: generated text that says which line of which
 * file it stands for, so that an error is reported where the
 * programmer wrote.
 *
 * evolution:
 * OCaml has had two ways to extend its syntax. Camlp4 (Daniel de
 * Rauglaudre), in the distribution until 2014, replaced the
 * parser: an extension was new rules added to OCaml's grammar,
 * powerful, and every extension its own dialect that tools could
 * not read. Since OCaml 4.02 (2014) the grammar is closed and has
 * two holes in it, extension nodes ([%name ...]) and attributes
 * ([@@name ...]), which every tool parses and only a rewriter of
 * the tree, a ppx, gives a meaning to. mlpp's constructs are
 * written in those holes, so ocamlformat and merlin take the
 * sources as they are; [%bits] and the classes are mlpp's own, and
 * [@@deriving show] is ppx_deriving's, done again (Derive). *)

(* the line, the message *)
exception Error of int * string

(* the .mli of a .ml: its file name, its text, its type declarations *)
type mli = { mli_file : string; mli_text : string; mli_decls : Ast.type_decl list }

(* the file's text, given its tree, which has mlpp's constructs where
 * they are (Ast's Pextension, Eextension, Hole, tattrs) *)
val file : file:string -> string -> Ast.source -> mli:(unit -> mli option) -> string

(* The classes (plan_ml_bootstrap.md, "Type classes"), a second rewrite, of
 * the first's text and tree: the dictionaries Typing found (a name's
 * place in the text, what is to follow it) written at their uses, and
 * [%using: t], a parameter or its type, made OCaml's *)
val classes : file:string -> string -> Ast.source -> (Ast.span * string) list -> string

(* whether a unit has a class's construct of its own: a class, an
 * instance, a [%using: ...] *)
val has_classes : file:string -> string -> Ast.structure -> bool

(* a construct's mark in a text, [%bits, [@@deriving, [%using, a line
 * type ... = _, even in a string or a comment: for a warning *)
val has_constructs : string -> bool
