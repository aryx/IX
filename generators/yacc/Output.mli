(* Writes a parser in OCaml that runs on Parsing's engine (in
 * lib_core), and its interface. The parser has the header, the type of
 * the tokens, the tables, the rules' actions, a function for each start
 * symbol, and the trailer.
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
 * As in ocamlyacc, the values on the parser's stack have no type
 * (Obj.t), and an action gives them back their types. A token's type
 * is the one given by %token. A non-terminal's type is the one given by
 * %type, or else a type variable named after it, such as 'expr. That
 * variable is the same in every action, since the actions are in one
 * array, so OCaml checks that the rules of expr agree and infers its
 * type.
 *
 * An action's places are menhir's: $sloc is the place of the rule's
 * text, and $loc($n) is the place of its n-th symbol. Each is a pair of
 * Lexing positions, the first and the last, which are asked of Parsing
 * before the action runs, as the values are (let _sloc =
 * Parsing.symbol_start_pos (), Parsing.symbol_end_pos ()). So a grammar
 * says where things are in a way that menhir also reads, and it does
 * not need to call Parsing's functions itself.
 *
 * A parser in another language (C) would be written by another module
 * like this one, from the same automaton. *)

(* file and out are the names of the .mly and of the parser, for the
 * # lines; the result is the parser's text *)
val ocaml : file:string -> out:string -> Yacc.t -> Lalr.t -> string

(* the parser's interface: the tokens and the start symbols' functions *)
val interface : Yacc.t -> string

(* the listing of -v: the rules by number, then each state with its
 * kernel items and its actions, as yacc's y.output shows them *)
val listing : Lalr.t -> string
