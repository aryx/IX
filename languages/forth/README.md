# languages/forth: mini-forth

Forth, written here for its machine (the author, of ix's other
machines, Pascal's P-code, Smalltalk's bytecode, Prolog's WAM: "dunno
if we miss a famous one we could add"; then "let's add
languages/forth/ then if it's interesting from an historical
perspective"). No file copied.

| module | what |
|---|---|
| `Forth` | the memory and the dictionary in it, the two stacks, the inner interpreter (NEXT, DOCOL, EXIT), the outer one, the primitives, `SEE` |
| `Forth_prelude` | what is written in Forth: `IF`, `THEN`, `BEGIN`, `UNTIL`, `DO`, `LOOP`, `VARIABLE`, `CONSTANT`, `2DUP`, `MAX`... |
| `CLI`, `Main` | the command: files, `-e text`, a prompt, `-trace` |

`mini-forth -h` says how, by examples.

## Why it is here

Charles Moore wrote Forth around 1970 at the National Radio Astronomy
Observatory, to point a telescope with a computer of a few thousand
words of memory, and it stayed the language of machines too small for
any other: the first microcomputers' (fig-Forth, 1978, a listing a
hobbyist typed in), instruments and spacecraft, and a board's first
program still (Open Firmware, the monitor of Sun's and Apple's
machines, is a Forth). PostScript is its cousin: a stack, a
dictionary, words between spaces.

What it has that no other language of ix has:

- **Threaded code** (James Bell, 1973). A word defined by a colon is
  compiled to the addresses of the words it is made of, and nothing
  else. The interpreter of that is three lines: take the address IP
  points at, move IP, run what the word's code field says. `SEE`
  shows it:

      $ mini-forth -e ': SQUARE DUP * ;  SEE SQUARE'
      : SQUARE
        1157  DUP
        1158  *
        1159  EXIT ;

  It is the least there can be between a text and a machine: mini-pascal
  compiles to P-code and mini-prolog to the WAM's instructions, each
  with a compiler of hundreds of lines; Forth's compiler is `,`, which
  puts a cell at the dictionary's end.
- **The compiler is the program's.** `IF` is not syntax: it is a word
  marked `IMMEDIATE`, so it runs while a definition is compiled, and
  what it does is compile a jump and leave on the stack the address
  to fill; `THEN` fills it. Both are two lines of Forth
  (`Forth_prelude`), and a program can write its own (`tests/classics.fs`
  has `UNLESS`):

      $ mini-forth -e 'SEE IF'
      : IF
        546  (') (0BRANCH)
        548  ,
        549  HERE
        550  (LIT) 0
        552  ,
        553  EXIT ; IMMEDIATE

- **Words that define words.** `CREATE` makes a word with data after
  it, `DOES>` says what the words made by the one being defined will
  do with that data: `CONSTANT` and an array are a line each.
- **No syntax and two stacks.** The text is words between spaces, read
  once, left to right; the operands are on a stack, the returns on
  another, and a program may use both.

## What is not a Forth of 1978

The two stacks are OCaml's arrays, not in the memory. An address
counts cells and a character takes one (`C@` is `@`, `CELLS` does
nothing): the memory is an array of integers. The outer interpreter
is OCaml, where a Forth has `QUIT` and `INTERPRET` in Forth. A
primitive is an OCaml function, not machine code, so there is no
assembler and `SEE DUP` says only that it is one. A cell is OCaml's
integer: 63 bits, 31 by mini-ml on arm. `/` rounds toward zero.

Not there: floats and double numbers, blocks and files' words
(`INCLUDE`), `KEY` and `ACCEPT`, vocabularies, `U<` and the unsigned
words, `CASE`, `EVALUATE`, exceptions (`CATCH`, `THROW`). The words
that are there are Forth-83's and ANS Forth's core, in part; `WORDS`
lists them.

## Tests

`tests/run.sh`, by text, on dune's build and on mini-ml's: the words
a group a line (`core.fs`), the classical programs (`classics.fs`:
Euclid's, Fibonacci's, BYTE's sieve, Hanoi, a word that defines
words, a control structure of the program's own), `SEE`'s threaded
code (`see.fs`), the tracer, the prompt, a file with a mistake. No
other Forth is on the author's machine: the `.out` files were read,
not made by one.

## Its speed

BYTE's benchmark of September 1981, the sieve of Eratosthenes ten
times (`tests/sieve.fs`; 4,966,268 words run): 0.10 s by OCaml's
build, 0.42 s by mini-ml's (arm64, 2026-10-10).
