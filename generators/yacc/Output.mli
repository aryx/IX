(* A parser written in OCaml, on Parsing's engine (lib_core's): the
 * header, the tokens' type, the tables, the rules' actions, a function
 * for each start symbol, the trailer; and its interface.
 *
 *     type token = INT of (int) | PLUS | ...
 *     let __tables : Parsing.tables = { ...;
 *       reduce = [| (fun () ->
 *         let _1 = (Obj.obj (Parsing.value 1) : 'expr) in
 *         let _3 = (Obj.obj (Parsing.value 3) : 'expr) in
 *         Obj.repr ((
 *     # 31 "Parser.mly"
 *                          _1 + _3 ) : 'expr)); ... |] }
 *     let main lexer lexbuf : int = Obj.obj (Parsing.run __tables 0 ... lexer lexbuf)
 *
 * The values on the parser's stack have no type (Obj.t), as
 * ocamlyacc's. An action gives them theirs back: a token's is
 * %token's, a non-terminal's %type's, or a type variable of its name,
 * 'expr, the same in every action since they are one array: so OCaml
 * checks that the rules of expr agree, and infers its type.
 *
 * Another language's parser (C's) would be another module as this one,
 * on the same automaton. *)

(* the .mly's name and the parser's, for the # lines; the parser's text *)
val ocaml : file:string -> out:string -> Yacc.t -> Lalr.t -> string

(* the parser's interface: the tokens, the start symbols' functions *)
val interface : Yacc.t -> string

(* -v's: the rules by number, then each state with its kernel items and
 * its actions, as yacc's y.output says them *)
val listing : Lalr.t -> string
