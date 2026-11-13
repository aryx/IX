(* mlpp (plan_ml_bootstrap.md, decision 7) rewrites mlpp's constructs
 * in a file's text into OCaml, and leaves the rest of the text as it
 * is. Where the rewritten text moves the source's lines, a line
 * # n "file" says where the next line comes from, so that a compiler's
 * errors name the source's lines (and its columns, since a copied
 * piece starts at its own column). A file without constructs comes back
 * unchanged.
 *
 * The constructs are:
 * - [%bits "..."], as a clause's whole pattern or as an expression
 *   (Bits);
 * - type t = [%mli] in a .ml, which takes the "= ..." of the .mli, on
 *   the hole's line;
 * - [@@deriving show] after a group of types (Derive);
 * - [@@class] after a record type, which gives its methods (Derive).
 * The classes' dictionaries are written by a second rewrite (classes,
 * below).
 *
 * Here is the second rewrite on three lines (mini-ml -pp, with
 * Prelude's classes, and without its # lines):
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
 * int * int list. So this rewrite runs after Resolve and Typing (in
 * CLI's classes), while the first one needs only the parser.
 * Prelude.mli has the classes' own story, Haskell's.
 *
 * Where it stands: mini-ml runs it on each file that it compiles,
 * between the parser and Resolve, and mini-ml -pp prints its output,
 * which is
 * how dune builds the same sources with OCaml (a preprocess action in
 * a dune file) and how merlin reads them. It is what lets ix be
 * written in one text for two compilers.
 *
 * design:
 * The text is rewritten, not the tree. A construct's node says where
 * it starts and stops in the file (Ast's spans), and its replacement
 * is put there, while the rest is copied byte for byte. So no printer
 * of OCaml is needed (a rewritten tree would have to be printed back
 * for OCaml to read), the comments and the layout stay, and a file
 * with no construct stays the same file. The # lines are a trick of
 * C's preprocessor, and of yacc: the generated text says which line
 * of which file it stands for, so that an error is reported where the
 * programmer wrote it.
 *
 * evolution:
 * OCaml has had two ways to extend its syntax. Camlp4 (Daniel de
 * Rauglaudre), in the distribution until 2014, replaced the parser:
 * an extension was a set of new rules added to OCaml's grammar. This
 * was powerful, but every extension was its own dialect that tools
 * could not read. Since OCaml 4.02 (2014) the grammar is closed and
 * has two holes in it, extension nodes ([%name ...]) and attributes
 * ([@@name ...]). Every tool parses them, and only a rewriter of the
 * tree, a ppx, gives them a meaning. mlpp's constructs are written in
 * those holes, so ocamlformat and merlin take the sources as they are.
 * [%bits] and the classes are mlpp's own, and [@@deriving show] is
 * ppx_deriving's, done again (Derive). *)

(* the line and the message *)
exception Error of int * string

(* the .mli of a .ml: its file name, its text and its type
 * declarations *)
type mli = { mli_file : string; mli_text : string; mli_decls : Ast.type_decl list }

(* the file's text rewritten, given its tree, which has mlpp's
 * constructs where they are (Ast's Pextension, Eextension, Hole,
 * tattrs) *)
val file : file:string -> string -> Ast.source -> mli:(unit -> mli option) -> string

(* The classes (plan_ml_bootstrap.md, "Type classes"): a second
 * rewrite, of the first one's text and tree. It writes the
 * dictionaries that Typing found at their uses (each is given as a
 * name's place in the text and what is to follow it), and makes
 * OCaml's code of [%using: t], whether it is a parameter or its
 * type. *)
val classes : file:string -> string -> Ast.source -> (Ast.span * string) list -> string

(* whether a unit has a construct of the classes of its own: a class,
 * an instance, or a [%using: ...] *)
val has_classes : file:string -> string -> Ast.structure -> bool

(* whether a text has a construct's mark: [%bits, [%list, |!, [%mli],
 * [@@deriving, [%using, [@@class] or [@@instance]. It looks even in a
 * string or a comment. The answer is used for a warning. *)
val has_constructs : string -> bool
