(* ix: the run time of mini-lex's lexers (plan_lex_yacc.md), for
 * mini-ml. It has the names and types of OCaml's Lexing, for what ix's
 * lexers and their callers use (the actions of a lexer are one source
 * for both ocamllex and mini-lex, so Lexing.lexeme lexbuf must mean the
 * same in both). It also has the engine, which is written in OCaml
 * here, with no primitive of the runtime. dune's builds take OCaml's
 * Lexing and the lexers of ocamllex.
 *
 * The tables are mini-lex's, not ocamllex's. They hold a DFA that is
 * not compacted: each state is a row of 257 entries (one for each
 * character, and 256 for the end of the input), and each entry is 2
 * bytes of a string.
 *
 * A lexer cuts the text into tokens. Its rules are regular expressions,
 * each with an action. mini-lex turns all the expressions of a rule at
 * once into one automaton, where a state is what has been read so far
 * of any of them. [engine] is the loop that follows the automaton: it
 * reads a character, indexes the row with it, and gets a state. Here
 * are the two clauses "<" (0) and "<=" (1), with the states numbered as
 * drawn:
 *
 *                     '<'           '='
 *     state 0  ------------> 1 ------------> 2
 *                        accepts 0       accepts 1
 *
 *     trans     0 ... '<' '=' ... 255 256       accept
 *     state 0 [ 0      2   0       0   0 ]      [ 0 ]
 *     state 1 [ 0      0   3       0   0 ]      [ 1 ]    (a state or a
 *     state 2 [ 0      0   0       0   0 ]      [ 2 ]     clause, + 1)
 *
 * {b The longest token.} The engine does not stop at the first state
 * that accepts. It goes on while a transition exists, remembering the
 * last accepting state it met and how far it was. On "<=3" it passes
 * state 1, reaches 2, and finds no way out by 3, so the token is clause
 * 1, two characters long. On "<3" it reads the 3 in state 1 and has no
 * way to go, so it comes back to what it remembered: clause 0, one
 * character long, and the 3 starts the next token. That is why "ifx"
 * is one identifier, and not the keyword if followed by x, with no rule
 * saying so. Between two clauses that match the same text, mini-lex
 * gives the state to the first one.
 *
 * Where it stands: mini-lex, in generators/, writes the tables, and for
 * each rule a function that calls [engine]. The lexers of the ML and C
 * compilers, of awk, bc and hoc, and of the database are made this way
 * (the assembler's lexer is written by hand). The parser (Parsing)
 * calls the lexer for one token at a time, and reads the positions kept
 * here for its error messages. Regex is the other way to match an
 * expression: there the pattern comes when the program runs, and is
 * followed as it is. Here the expression is known beforehand, and the
 * work is done once, by the generator.
 *
 * cs-history:
 * Mike Lesk's lex (Bell Labs, 1975) made the pair with yacc: the
 * regular part of a language's grammar goes to a table and a loop, and
 * the rest goes to the parser. The longest-match rule, and the rule
 * that the first one wins among equals, come from lex. ocamllex keeps
 * lex's ways for OCaml, with the actions written in OCaml.
 *
 * modern:
 * A full table has 257 entries for each state, most of them 0. lex and
 * ocamllex compact theirs: rows that are alike share their entries,
 * with a second table to check that an entry belongs to the state. That
 * table is smaller, and slower by one indirection. Here a state costs
 * 514 bytes, and mini-ml's lexer, of some 200 states, costs a hundred
 * kilobytes (see Dfa's header), so the table is left as it is.
 *
 * References: M. E. Lesk, "Lex -- A Lexical Analyzer Generator",
 * Bell Labs Computing Science Technical Report 39 (1975); OCaml's
 * manual, "Lexer and parser generators", for the rules' syntax and
 * for Lexing's functions; plan_lex_yacc.md. *)

(* Where a token is: its file, its line, and the offsets of the line's
 * start and of the token itself, from the start of the input. *)
type position = { pos_fname : string; pos_lnum : int; pos_bol : int; pos_cnum : int }
val dummy_pos : position

(* The input being read. It holds the characters read so far
 * (lex_buffer_len of them, the first one at offset lex_abs_pos of the
 * input), the current token from lex_start_pos to lex_curr_pos, and the
 * token's two positions. The engine keeps their pos_cnum, and the
 * lexer's actions may set the rest (the line, with new_line, and the
 * file). *)
type lexbuf = {
  refill_buff : lexbuf -> unit;
  mutable lex_buffer : bytes;
  mutable lex_buffer_len : int;
  mutable lex_abs_pos : int;
  mutable lex_start_pos : int;
  mutable lex_curr_pos : int;
  mutable lex_eof_reached : bool;
  mutable lex_start_p : position;
  mutable lex_curr_p : position;
}

val from_string : string -> lexbuf
val from_channel : in_channel -> lexbuf
(* The function, called as read buf n, puts up to n characters into buf
 * and returns how many; it returns 0 at the end. *)
val from_function : (bytes -> int -> int) -> lexbuf

(* The current token: its text, its i-th character, and its offsets and
 * positions. *)
val lexeme : lexbuf -> string
val lexeme_char : lexbuf -> int -> char
val lexeme_start : lexbuf -> int
val lexeme_end : lexbuf -> int
val lexeme_start_p : lexbuf -> position
val lexeme_end_p : lexbuf -> position

(* Tells that a newline was read: the current position moves to the
 * next line. *)
val new_line : lexbuf -> unit

(* mini-lex's tables, a DFA. trans holds, at 257 s + c, for state s and
 * character c (256 for the end of the input), the next state plus 1, or
 * 0. accept holds, for state s, the clause it accepts plus 1, or 0.
 * Each entry is a 16-bit number, with the low byte first. *)
type tables = { trans : string; accept : string }

(* Reads the longest token from the current position, starting in that
 * state (the first state of a rule). It returns the number of the
 * token's clause, and the token becomes the current one. It raises
 * Failure "lexing: empty token" when no clause matches. *)
val engine : tables -> int -> lexbuf -> int

(* For r as x in a clause, no automaton says where x is, so the clause's
 * regexp is matched again on the lexeme alone. The regexp, which
 * mini-lex writes, is a set of characters (as 32 bytes of 8 flags), the
 * end of the input, nothing, r1 r2, r1 | r2, r*, or r as the v-th
 * variable. *)
type regexp =
  | Chars of string
  | Eof
  | Eps
  | Seq of regexp * regexp
  | Alt of regexp * regexp
  | Star of regexp
  | Bind of int * regexp

(* The spans in the buffer of the n variables, with (-1, -1) for a
 * variable that is not bound. When there are two ways to match, it
 * takes the first alternative, and the longest repetition. *)
val captures : regexp -> int -> lexbuf -> (int * int) array

(* The text of a variable, or its one character; the _opt functions
 * give None when it is not bound. *)
val sub : lexbuf -> (int * int) array -> int -> string
val sub_opt : lexbuf -> (int * int) array -> int -> string option
val sub_char : lexbuf -> (int * int) array -> int -> char
val sub_char_opt : lexbuf -> (int * int) array -> int -> char option
