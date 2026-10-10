(* Pcode: the instructions of the P-machine, Pascal's portable
   computer.

   In 1973 Wirth's group at ETH published Pascal-P: a compiler from
   Pascal to the code of an imaginary stack computer, the P-machine,
   written in Pascal itself, and the P-machine's interpreter, a few
   pages. To bring Pascal to a new computer, one wrote the interpreter
   in its assembler -- days, not the months of a compiler -- and ran the
   compiler on it. It is how Pascal spread to sixty kinds of machine,
   and how UCSD Pascal (Kenneth Bowles, 1977) ran the same p-code on the
   Apple II and the IBM PC; Java's bytecode (1995) is the same idea.

   The machine has one memory, a stack of words, and a few registers:
   pc the next instruction, sp the top of the stack, mp the frame of
   the procedure running (its "mark"). An expression is computed on the
   top of the stack, as a reverse Polish calculator would:

       x := a + b * 2       lod 0,5  lod 0,6  ldc 2  mpi  adi  str 0,4

   A procedure's frame, from mp up (the mark, then its parameters and
   variables, then the expressions being computed):

       mp+0  the function's result
       mp+1  static link: the frame of the procedure it is declared in
       mp+2  dynamic link: the frame of its caller
       mp+3  return address
       mp+4  the parameters, then the local variables...

   Pascal's procedures nest, and an inner one reaches the variables of
   those around it: a variable is addressed by a *level difference* and
   an offset, lod 1,5 being "5 words into the frame one level out", and
   the machine finds that frame by following the static link once
   (twice for lod 2,...). The static links are the scope written in the
   program, the dynamic links the calls made at run time -- recursion
   makes them differ. A display (an array of the frames of each level,
   Dijkstra's, 1960) makes the lookup one step; an exercise.

   The instructions, Pascal-P's mnemonics (without their type suffixes:
   every word here is an integer, a character or a boolean):

     ldc n        push n
     lod d,o      push the word at offset o of the frame d levels out
     lda d,o      push its address
     str d,o      pop into it
     ind o        pop an address, push the word o after it
     sto          pop a value, pop an address, store
     ldm n        pop an address, push the n words there: an array's
                  or a record's value
     stm n        pop n words, pop an address, store them there: an
                  array assigned
     ixa n        pop an index, pop an address: address + index * n
     inc n        add n to the top
     chk lo,hi    stop unless the top is between lo and hi
     adi sbi mpi dvi mod ngi abi sqi odd   arithmetic, 16 bits
     equ neq les leq grt geq and ior not  comparisons and logic
     ujp l / fjp l    jump; jump if the popped value is false
     mst d        mark the stack for a call: result, static link (the
                  frame d levels out), dynamic link, return address
     cup n,l      call: its n words of parameters are on the stack
     ent n        enter: the frame n words long, variables zeroed
     retp / retf  return from a procedure / a function (its result
                  left on the stack)
     csp name     a standard procedure: wri (an integer, a width), wrc
                  (a character), wrb (a boolean), wrs (a string), wln,
                  rdi rdc (read an integer, a character, into an
                  address), rln (to the next line), rnd (random)
     stp          stop

   design:
   The compiler carries itself. Pascal-P's compiler was a Pascal
   program, and the kit sent out was its P-code with it: on a new
   computer the interpreter, once written, ran the compiler, which
   could compile itself and anything else there. A language whose
   compiler is written in it has to begin somewhere, and a small
   machine to interpret is the cheapest place; the other way is to
   compile on a computer that has the language for one that has not,
   which is how ix's compilers reach mini-9pi.

   terminology:
   P-code is this code, the P for Pascal or portable, and p-code
   became the word for any such; bytecode is the same thing named for
   its encoding, an instruction a byte, from Smalltalk (whose machine
   is in ix too). Virtual machine came to mean the imaginary computer
   that runs one, where it had meant a real computer's copy that an
   operating system gives each user (IBM's VM/370), which is what
   mini-qemu is nearer to.

   others:
   The machines of ix made for a language, each kept because its
   language is known by it. This one: a stack and frames, static
   links for a language of nested procedures. Smalltalk's: a stack
   too, a call a message looked up in the receiver's class. Forth:
   two stacks and no frame, the code a list of addresses and nothing
   to decode. Wam: registers for a call's arguments, and a second
   stack of choices to come back to. Scheme_secd: Landin's, for a
   language whose functions are values.

   modern:
   Java's bytecode (1995) is P-code's direct heir, down to the type
   in the mnemonic (iadd, as Pascal-P's adi, add integers), and
   WebAssembly (2017) is a stack machine again. Neither is
   interpreted for long: the instructions run often are compiled to
   the machine's own as the program runs. Pascal-P's idea was the
   portability; its price in speed is what the later machines bought
   back.

   References: K. V. Nori, U. Ammann, K. Jensen, H. H. Nageli and Ch.
   Jacobi, "The Pascal P Compiler: Implementation Notes" (ETH Zurich;
   from memory); Steven Pemberton and Martin Daniels, "Pascal
   Implementation: The P4 Compiler and Interpreter" (Ellis Horwood,
   1982): the P4 sources, annotated line by line; Niklaus Wirth,
   "Algorithms + Data Structures = Programs" (Prentice-Hall, 1976),
   chapter 5: PL/0, a smaller language compiled the same way to a
   smaller such machine. *)

type csp =
  | Wri (* pops a width, an integer *)
  | Wrc (* a width, a character *)
  | Wrb (* a width, a boolean *)
  | Wrs of string (* a width *)
  | Wln
  | Rdi (* pops an address *)
  | Rdc
  | Rln
  | Rnd (* pops n, pushes 0 to n - 1 *)
  | Eol (* pushes whether the input line is used up: eoln *)

type instr =
  | Ldc of int
  | Lod of int * int
  | Lda of int * int
  | Str of int * int
  | Ind of int
  | Sto
  | Ldm of int
  | Stm of int
  | Ixa of int
  | Inc of int
  | Chk of int * int
  | Adi | Sbi | Mpi | Dvi | Mod | Ngi | Abi | Sqi | Odd
  | Equ | Neq | Les | Leq | Grt | Geq | And | Ior | Not
  | Ujp of int
  | Fjp of int
  | Mst of int
  | Cup of int * int
  | Ent of int
  | Retp
  | Retf
  | Csp of csp
  | Stp

(* What the compiler leaves for the debugger, besides the code: the
   P-code's DWARF. A debugger sees only a machine running instructions;
   to show a source line and a variable by its name it needs

   - where each statement's code begins, and its line: [statements] (-1
     at the addresses inside a statement), where F7 and F8 stop;
   - each procedure's code, from its entry to its return, and its
     variables: their names, offsets in its frame and types, so that
     "x" read in a paused program is the word at mp + 5, or the one a
     static link away when x belongs to an enclosing procedure. *)

type vtype = Vint | Vbool | Vchar | Varray of int * int * vtype | Vrecord of (string * int * vtype) list

type variable = { vname : string; offset : int; vtype : vtype; by_ref : bool; param : bool }

type procedure = {
  pname : string;
  level : int; (* its body's: the main program's is 0 *)
  parent : int; (* the procedure it is declared in, an index in [procedures]; -1 for the main program *)
  first : int; (* its code: its entry (ent) to its return (retp, retf, stp) *)
  last : int;
  variables : variable list; (* its parameters first *)
}

(* a compiled program: its code, the source line of each instruction
   (for the errors at run time), and the debugger's information; the
   main program is procedures.(0) *)
type program = { code : instr array; lines : int array; statements : int array; procedures : procedure array }

(* the words a frame's mark takes: result, static and dynamic links,
   return address *)
val mark : int

val show : instr -> string

(* the program as a listing: an instruction a line, its address and
   the source line it came from:

       0  ujp 12        ; 1
       1  ent 6         ; 3 ... *)
val listing : program -> string
