(* ix: the run time of mini-lex's lexers (plan_lex_yacc.md), for
 * mini-ml: OCaml's Lexing by its names and types, for what ix's lexers
 * and their callers use (a lexer's actions are one source for ocamllex
 * and for mini-lex, so Lexing.lexeme lexbuf must mean the same), and
 * the engine, which is OCaml here: no primitive of the runtime's.
 * dune's builds take OCaml's Lexing and ocamllex's lexers.
 *
 * The tables are mini-lex's, not ocamllex's: a DFA not compacted, a
 * state a row of 257 entries (a character, or 256 for the end of the
 * input), each 2 bytes of a string. *)

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
