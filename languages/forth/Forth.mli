(* Forth (Charles Moore; standing alone for the first time in 1971, at
 * the National Radio Astronomy Observatory, to drive a telescope from
 * two minicomputers, the smaller of 16 kilobytes), the
 * language and its machine in one: no syntax but words between spaces,
 * no compiler but a dictionary that the program itself adds to, and two
 * stacks. It is here for its machine, threaded code (James Bell,
 * "Threaded Code", 1973): the smallest way known to run a language, and
 * what Open Firmware and many a board's monitor came of (PostScript
 * is a cousin: a stack and the operator last, not threaded code).
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
 * The memory behind that listing, a cell an address:
 *
 *     1148  the link: the header of the word defined before
 *     1149  6                 the name's length (and the flags)
 *     1150  S Q U A R E       a character a cell
 *     1156  DOCOL             the code field: what kind of word
 *     1157  DUP's code field's address        the parameters:
 *     1158  *'s                               the thread
 *     1159  EXIT's
 *
 * and 7 SQUARE . run, by -trace (each word NEXT runs, the stack
 * before it):
 *
 *     SQUARE       <1> 7          W = 1156, DOCOL: IP kept on the
 *         DUP          <1> 7      return stack, IP = 1157
 *         *            <2> 7 7
 *         EXIT         <1> 49     IP taken back
 *     .            <1> 49         49 is printed
 *
 * A word is looked for along the links, from the last one defined:
 * so a word may be defined again, and the words compiled before still
 * run the old one, whose address they hold. And a control structure,
 * compiled by words that run inside the definition:
 *
 *     : A IF 1 ELSE 2 THEN ;     SEE A
 *       1152  (0BRANCH) 1158     IF put (0BRANCH) and an empty cell,
 *       1154  (LIT) 1            and left the cell's address, 1153,
 *       1156  (BRANCH) 1160      on the stack; ELSE filled it with
 *       1158  (LIT) 2            1158 and left 1157; THEN filled that
 *       1160  EXIT ;             with 1160
 *
 * The data stack at compile time is the compiler's memory of the
 * jumps left open: the backpatching of Pascal_compile's labels, done
 * by four words of a line each, and nesting for free.
 *
 * What is not a Forth of 1978: the two stacks are OCaml's arrays, not
 * in the memory; an address counts cells and a character takes one
 * (C@ is @); the outer interpreter is in OCaml, not QUIT and INTERPRET
 * in Forth; a cell is OCaml's integer (63 bits, 31 by mini-ml on arm);
 * no blocks, no assembler, no vocabularies, no floats. The words are
 * Forth-83's and ANS Forth's core, in part.
 *
 * terminology:
 * Threaded code is a program as a list of addresses of routines,
 * with no instruction between them, and it has four kinds. Subroutine
 * threaded: the list is the machine's call instructions, so it is
 * machine code and needs no NEXT. Direct threaded (Bell's): each cell
 * is the address of machine code, and NEXT jumps there. Indirect
 * threaded (Robert Dewar, 1975; fig-Forth's and this one): each cell
 * is the address of a word's code field, which holds the address of
 * the code; one fetch more, and every word has one shape, a colon
 * word, a variable and a constant differing by their code field
 * alone. Token threaded: a number in place of an address, looked up
 * in a table; smaller, and what a bytecode is (Pcode, Smalltalk's).
 *
 * cs-history:
 * Charles Moore grew the language through the 1960s as a set of
 * tools he carried from job to job, and named it at last on an IBM
 * 1130: a language for the fourth generation of computers, where
 * names had five letters, hence FORTH. With Elizabeth Rather he
 * founded Forth, Inc. in 1973. The Forth Interest Group's fig-Forth
 * (1978) was a listing for each of the first microprocessors, a few
 * kilobytes that gave an interpreter, a compiler, an editor and an
 * assembler: on a machine with no disk and no operating system,
 * Forth was both. The standards are Forth-79, Forth-83 and ANS Forth
 * (1994).
 *
 * others:
 * The operands first and a stack is reverse Polish notation, older
 * than Forth (named for Jan Lukasiewicz, whose notation without
 * parentheses had the operator first; the desk calculators' and
 * dc's have it last, with a stack): mini-dc is the same outer loop
 * with numbers of any size. Open Firmware (Sun's OpenBoot; IEEE
 * 1275, 1994), a machine's first program on Sun's and Apple's
 * PowerPC machines, is a Forth so that a card's driver can be a few
 * words in the card's own memory, for any processor. rc's C is
 * threaded code too (Eval says how mini-rc does without it), and
 * Pmachine is what a stack machine is when a compiler, not a person,
 * writes its code: one stack is enough.
 *
 * why-study:
 * It is the whole of a language system in a few hundred lines with
 * nothing hidden: a dictionary one can draw, an interpreter of three
 * lines, a compiler that is the word comma. Every other language of
 * ix has a parser, a tree and a code generator between the text and
 * the machine; here one sees what is left when all three are taken
 * out, and what is paid for it: no check of any kind, and the
 * programmer's head for the stack.
 *
 * References: Charles Moore and Geoffrey Leach, "FORTH -- A Language
 * for Interactive Computing" (1970); James R. Bell, "Threaded Code"
 * (Communications of the ACM, 1973); Robert B. K. Dewar, "Indirect
 * Threaded Code" (Communications of the ACM, 1975); Elizabeth Rather,
 * Donald Colburn and Charles Moore, "The Evolution of Forth" (History
 * of Programming Languages II, 1993); Leo Brodie, "Starting Forth"
 * (1981): the book to learn it by. *)

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
