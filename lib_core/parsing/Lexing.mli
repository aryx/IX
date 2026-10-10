(* ix: the run time of mini-lex's lexers (plan_lex_yacc.md), for
 * mini-ml: OCaml's Lexing by its names and types, for what ix's lexers
 * and their callers use (a lexer's actions are one source for ocamllex
 * and for mini-lex, so Lexing.lexeme lexbuf must mean the same), and
 * the engine, which is OCaml here: no primitive of the runtime's.
 * dune's builds take OCaml's Lexing and ocamllex's lexers.
 *
 * The tables are mini-lex's, not ocamllex's: a DFA not compacted, a
 * state a row of 257 entries (a character, or 256 for the end of the
 * input), each 2 bytes of a string.
 *
 * A lexer cuts the text into tokens. Its rules are regular
 * expressions with an action each; mini-lex turns a rule's
 * expressions, all at once, into one automaton, where a state is
 * what has been read so far of any of them, and [engine] is the
 * loop that follows it: a character read, a row indexed, a state.
 * For the two clauses "<" (0) and "<=" (1), the states numbered as
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
 * that accepts: it goes on while a transition exists, remembering
 * the last accepting state it met and how far it was. On "<=3" it
 * passes state 1, reaches 2, finds no way out by 3: clause 1, two
 * characters. On "<3" it reads the 3 in state 1 and has no way: it
 * comes back to what it remembered, clause 0, one character, and the
 * 3 is the next token's. That is why "ifx" is one identifier and not
 * the keyword if then x, with no rule saying so; between two clauses
 * that match the same text, mini-lex gives the state the first one.
 *
 * Where it stands: generators' mini-lex writes the tables and a
 * function a rule that calls [engine]; the lexers of the ML and C
 * compilers, of awk, bc and hoc, of the database are made so (the
 * assembler's is written by hand). The parser
 * calls the lexer for a token at a time (Parsing) and reads the
 * positions kept here for its errors. Regex is the other way to
 * match an expression: there the pattern comes when the program
 * runs, and is followed as it is; here it is known beforehand, and
 * the work is done once, by the generator.
 *
 * cs-history:
 * Mike Lesk's lex (Bell Labs, 1975) made the pair with yacc: the
 * regular part of a language's grammar given to a table and a loop,
 * the rest to the parser. The longest-match rule, and the first
 * rule among equals, are lex's. ocamllex keeps its ways for OCaml,
 * the actions being OCaml's.
 *
 * modern:
 * A full table is 257 entries a state, most of them 0. lex and
 * ocamllex compact theirs: rows that are alike share their entries,
 * with a second table to check that an entry is the state's own.
 * It is smaller and an indirection slower; here a state costs 514
 * bytes, mini-ml's lexer of some 200 states a hundred kilobytes
 * (Dfa's header), and the table is left as it is.
 *
 * References: M. E. Lesk, "Lex -- A Lexical Analyzer Generator",
 * Bell Labs Computing Science Technical Report 39 (1975); OCaml's
 * manual, "Lexer and parser generators", for the rules' syntax and
 * for Lexing's functions; plan_lex_yacc.md. *)

(* where a token is: its file, its line, the offset of the line's start
 * and its own, from the start of the input *)
type position = { pos_fname : string; pos_lnum : int; pos_bol : int; pos_cnum : int }
val dummy_pos : position

(* The input being read: its characters so far (lex_buffer_len of them,
 * the first one at lex_abs_pos of the input), the current token from
 * lex_start_pos to lex_curr_pos, and its two positions, which the
 * engine keeps (pos_cnum) and the lexer's actions may set (the line:
 * new_line; the file) *)
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
(* read buf n: up to n characters into buf, how many; 0 at the end *)
val from_function : (bytes -> int -> int) -> lexbuf

(* the current token: its text, its i-th character, its offsets and
 * positions *)
val lexeme : lexbuf -> string
val lexeme_char : lexbuf -> int -> char
val lexeme_start : lexbuf -> int
val lexeme_end : lexbuf -> int
val lexeme_start_p : lexbuf -> position
val lexeme_end_p : lexbuf -> position

(* a newline was read: the current position is on the next line *)
val new_line : lexbuf -> unit

(* mini-lex's: a DFA. trans: for state s and character c (256: the end
 * of the input), at 257 s + c, the next state plus 1, or 0. accept:
 * for state s, the clause it accepts plus 1, or 0. Each a 16-bit
 * number, the low byte first. *)
type tables = { trans : string; accept : string }

(* the longest token from the current position, from that state (a
 * rule's first): its clause's number, the token then the current one;
 * Failure "lexing: empty token" when no clause matches *)
val engine : tables -> int -> lexbuf -> int

(* r as x in a clause: where no automaton says where x is, the clause's
 * regexp is matched again on the lexeme alone. The regexp (mini-lex
 * writes it): a set of characters as 32 bytes of 8 flags, the end of
 * the input, nothing, r1 r2, r1 | r2, r*, and r as the v-th variable. *)
type regexp =
  | Chars of string
  | Eof
  | Eps
  | Seq of regexp * regexp
  | Alt of regexp * regexp
  | Star of regexp
  | Bind of int * regexp

(* the n variables' spans in the buffer, (-1, -1) for one not bound; of
 * two ways to match, the first alternative's, and the longest
 * repetition's *)
val captures : regexp -> int -> lexbuf -> (int * int) array

(* a variable's text; its one character; None when it is not bound *)
val sub : lexbuf -> (int * int) array -> int -> string
val sub_opt : lexbuf -> (int * int) array -> int -> string option
val sub_char : lexbuf -> (int * int) array -> int -> char
val sub_char_opt : lexbuf -> (int * int) array -> int -> char option
