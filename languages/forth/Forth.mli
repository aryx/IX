(* Forth (Charles Moore, 1970, at the National Radio Astronomy
 * Observatory, to drive a telescope from a computer of 8K words), the
 * language and its machine in one: no syntax but words between spaces,
 * no compiler but a dictionary that the program itself adds to, and two
 * stacks. It is here for its machine, threaded code (James Bell,
 * "Threaded Code", 1973): the smallest way known to run a language, and
 * what Open Firmware, PostScript's interpreter and many a board's
 * monitor came of.
 *
 * - The memory is cells, and the dictionary is in it: a word is a
 *   header (a link to the word before it, its name), a code field, and
 *   its parameters. A word defined by a colon has for parameters the
 *   addresses of the words it is made of: nothing else is compiled.
 * - The inner interpreter is three lines, NEXT: take the cell IP points
 *   at (a word's address, W), move IP, and run what W's code field
 *   says. For a primitive that is its code (here a function in OCaml);
 *   for a colon word it is DOCOL, which keeps IP on the return stack
 *   and sets it to W's parameters; EXIT takes it back. This is
 *   indirect threaded code, fig-Forth's.
 * - The outer interpreter reads a word of the text: found in the
 *   dictionary, it is run, or (inside a definition: STATE) its address
 *   is put at HERE; not found, it is a number, pushed or compiled as a
 *   literal. A word marked IMMEDIATE is run even inside a definition:
 *   IF, THEN, BEGIN, UNTIL and DO are such words, written in Forth
 *   (Forth_prelude) over two primitives that jump, so the compiler is
 *   extended by the language it compiles. CREATE and DOES> make the
 *   words that define words.
 *
 *     : SQUARE DUP * ;   SEE SQUARE
 *     : SQUARE
 *       1157  DUP
 *       1158  *
 *       1159  EXIT ;
 *
 * What is not a Forth of 1978: the two stacks are OCaml's arrays, not
 * in the memory; an address counts cells and a character takes one
 * (C@ is @); the outer interpreter is in OCaml, not QUIT and INTERPRET
 * in Forth; a cell is OCaml's integer (63 bits, 31 by mini-ml on arm);
 * no blocks, no assembler, no vocabularies, no floats. The words are
 * Forth-83's and ANS Forth's core, in part. *)

type t

(* a line's (or a text's) mistake: the word at fault and what is wrong *)
exception Error of string

(* the primitives and the prelude; [print] is where EMIT and . write *)
val create : (string -> unit) -> t

(* a line of text interpreted, each word in turn. Error: the stacks are
 * emptied and a definition being made is left; BYE: [finished] *)
val interpret : t -> string -> unit

(* BYE was said *)
val finished : t -> bool

(* inside a colon definition (the prompt says so) *)
val compiling : t -> bool

(* the words NEXT has run *)
val steps : t -> int

(* each word NEXT runs is printed with the stack before it, indented by
 * the return stack's depth *)
val set_trace : t -> bool -> unit
