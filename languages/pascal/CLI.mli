(* mini-pascal: Pascal compiled to P-code and run on a P-machine
 * (docs/plans/plan_pascal.md), on a terminal: a program compiled and
 * run, its readln answered by the lines typed; or its P-code listed.
 * TinyTurboPascal is the same compiler and machine in an IDE.
 * Its usage: [help] in CLI.ml, what mini-pascal -h prints.
 *
 *     sq.pas
 *        | Pascal_lexer      tokens, each with its line and column
 *        | Pascal_compile    one pass: parses, checks the types and
 *        |                   emits, with no tree between
 *     Pcode.program  ------- Pcode.listing: -S
 *        | Pmachine          fetch, decode, execute on one stack; a
 *        |                   Talk program: readln waits for a line
 *     what it writes         Pdebug: the same machine paused and read
 *                            as Pascal, for the IDE's debugger
 *
 *     program Sq;                 mini-pascal -S sq.pas
 *     var i : integer;              2  ldc 1         i := 1
 *     begin                         3  str 0,4
 *       for i := 1 to 3 do          4  ldc 3         the limit, kept
 *         writeln(i * i)            5  str 0,5       beside i
 *     end.                          6  lod 0,4       i <= the limit?
 *                                   7  lod 0,5
 *     it writes 1, 4, 9             8  leq
 *     in 52 instructions            9  fjp 20        no: out
 *     (-s)                         10  lod 0,4       i * i
 *                                  11  lod 0,4
 *                                  12  mpi
 *                                  13  ldc 0         no width asked
 *                                  14  csp wri       written
 *                                  15  csp wln
 *                                  16  lod 0,4       i := i + 1
 *                                  17  inc 1
 *                                  18  str 0,4
 *                                  19  ujp 6         again
 *                                  20  stp
 *
 * (Before them, 0 ujp 1 and 1 ent 6: over the procedures, of which
 * there are none, and the main program's frame.) Each line of code
 * was written as the compiler passed the text it stands beside, in
 * that order, and nothing was gone back to but the 20 of fjp.
 *
 * Next to ix's two compilers for a real machine it is the other end
 * of the scale. mini-cc and mini-ml build a tree, go over it several
 * times, choose registers, and leave an object file to the linker;
 * here the text goes in and a program runs, by a compiler of under a
 * thousand lines and a machine of under three hundred (Pmachine).
 * That is what made Pascal travel, and what the IDE
 * (mini-turbopascal, Tui_turbo) needs to compile at a key's press.
 *
 * evolution:
 * Niklaus Wirth designed Pascal at ETH Zurich in 1970, after the
 * committee for Algol's successor had preferred the large Algol 68
 * to his small proposal: a language to teach programming with, that
 * a compiler could read once, named for Blaise Pascal. Pascal-P
 * (1973; Pcode) carried it to every kind of computer. Kenneth
 * Bowles's UCSD Pascal (1977) made the P-machine a whole system for
 * microcomputers, editor, files and compiler, the same on each: one
 * of the three systems IBM sold for its PC in 1981, and Apple's
 * Pascal. Anders Hejlsberg's Turbo Pascal (Borland, 1983) kept the
 * one pass and dropped the P-machine: machine code written straight
 * into memory, an editor in the same program, a compilation in
 * seconds on a floppy-disk machine, for 49.95 dollars. For a decade
 * Pascal was what programming was taught in and what much of the
 * Macintosh's and the PC's software was written in.
 *
 * others:
 * Brian Kernighan's "Why Pascal Is Not My Favorite Programming
 * Language" (1981) lists what the Report's Pascal could not do for
 * real programs: an array's length is part of its type, so no
 * procedure can take a string of any length; no separate
 * compilation; no way round the types. Every dialect mended it its
 * own way (UCSD's units, Turbo's strings), no two alike, and C took
 * the systems. Wirth's own answers were new languages: Modula-2,
 * with modules, then Oberon. Hejlsberg went on to Delphi, C# and
 * TypeScript.
 *
 * References: Niklaus Wirth, "The Programming Language Pascal" (Acta
 * Informatica, 1971) and "Recollections about the Development of
 * Pascal" (History of Programming Languages II, 1993); Kathleen
 * Jensen and Niklaus Wirth, "Pascal User Manual and Report"
 * (Springer, 1974); K. V. Nori, U. Ammann, K. Jensen, H. H. Nageli
 * and Ch. Jacobi, "The Pascal P Compiler: Implementation Notes" (ETH
 * Zurich; from memory); Brian W. Kernighan, "Why Pascal Is Not My
 * Favorite Programming Language" (Bell Laboratories, 1981). *)

type caps = < Cap.open_in; Cap.stdin; Cap.stdout; Cap.stderr >

val main : < caps; .. > -> string array -> int
