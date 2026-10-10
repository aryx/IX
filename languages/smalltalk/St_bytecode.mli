(* St_bytecode: the Blue Book's instruction set, and a CompiledMethod.

   A method runs as bytecodes on a stack machine, one byte each
   (a few take a byte or two more). The set is the Blue Book's, chapter
   28, byte for byte:

     0-15     push receiver variable #iiii
     16-31    push temporary location #iiii
     32-63    push literal constant #iiiii
     64-95    push literal variable #iiiii (an Association's value)
     96-103   pop and store receiver variable #iii
     104-111  pop and store temporary location #iii
     112-119  push self, true, false, nil, -1, 0, 1, 2
     120-123  return self, true, false, nil from the method
     124      return stack top from the method (from its home, in a block)
     125      return stack top from the block, to its caller
     128      push, extended: jjkkkkkk (jj: receiver variable,
              temporary, literal constant, literal variable; k the index)
     129      store, extended (jj: receiver variable, temporary, -, literal variable)
     130      pop and store, extended
     131      send, extended: iiijjjjj (i arguments, selector literal j)
     132      send, double extended: then a byte of arguments, a byte of literal
     133      send to super, extended; 134 double extended
     135      pop stack top
     136      duplicate stack top
     137      push the active context (thisContext)
     144-151  jump forward 1-8
     152-159  pop and jump forward 1-8 on false
     160-167  jump (iii - 4) * 256 + next byte, backwards too
     168-171  pop and jump on true, ii * 256 + next byte
     172-175  pop and jump on false, ii * 256 + next byte
     176-191  send + - < > <= >= = ~= * / \\ @ bitShift: // bitAnd: bitOr:
     192-207  send at: at:put: size next nextPut: atEnd == class
              blockCopy: value value: do: new new: x y
     208-255  send literal selector #iiii with 0, 1 or 2 arguments

   Five more, Squeak's of 2008 for its closures (St_compile.mli), in
   numbers the Blue Book left unused; its own compiler never emits
   them:

     138      push a new Array: jkkkkkkk, of k nils (j = 0) or of the k
              values popped off the stack (j = 1)
     140      push temporary k of the temp vector in temporary j: then
              a byte k, a byte j
     141      store into it; 142 pop and store
     143      push a closure: llllkkkk, l values copied off the stack,
              k arguments, then two bytes, the length of the block's
              body, which follows and is jumped over

   The 32 "special selectors" of 176-207 cost one byte and no literal;
   for the arithmetic ones on SmallIntegers the interpreter does not
   even look the method up (St_interp.mli).

   A CompiledMethod is an object with fields and bytes: its first field
   the **header** (a SmallInteger: the primitive's number, the numbers
   of arguments and temporaries, the frame's size), then the
   **literals** (constants, selectors, Associations for globals), then
   -- ours, not the Blue Book's, which kept them in the sources file --
   a trailer: the selector, the class, the source text, the pc map
   (where each send's bytecode is, and the text it came from) and the
   temporaries' names, for the debugger.

   Worked example, the Blue Book's (chapter 26): Rectangle's

     center
         ^origin + corner / 2

   is 0 1 176 119 185 124: push origin (receiver variable 0), push
   corner (1), send +, push 2, send /, return the top.

   Where it stands: St_compile writes these bytes, St_interp runs
   them, St_debug reads the trailer; nothing else knows the numbers.

   design:
   The table is a compression done by hand. What a method does most
   -- push one of its first instance variables or temporaries, send
   +, send at:, return self -- has a byte to itself, the operand
   inside the byte; the rare cases take the extended forms, two or
   three bytes. Six bytes for center, where the same in a machine's
   own instructions would be several words: the first Altos had 64K
   words of memory, and the bytecodes are as much a way to make
   Smalltalk fit as a way to carry it from a machine to another. It
   is Huffman's idea with the frequencies counted once, by the
   designers (Huffman.mli, where they are counted for each block of
   data).

   others:
   A stack machine with one-byte instructions is the usual form of a
   language's virtual machine: Pascal's p-code (the 1970s), Java's
   (1995), Python's, OCaml's own bytecode. The JVM's iload_0 to
   iload_3 are "push temporary location" again, and its invokevirtual
   the send, the method found by its place in a table that the
   declared type gives, where Smalltalk searches by name. A Forth
   (languages/forth) is a stack machine too, its code a list of
   addresses and not of bytes: threaded code, faster to run and
   larger.

   cs-history:
   The bytecodes are Smalltalk-76's, Dan Ingalls's design, kept by
   Smalltalk-80 with few changes, and by Squeak: the five
   instructions of 2008 above went into numbers free since 1980.

   References: the Blue Book, chapter 26 (the instruction set by
   example, where center is) and chapter 28 (each bytecode's meaning,
   in Smalltalk). Dan Ingalls, "The Smalltalk-76 Programming System:
   Design and Implementation" (POPL 1978): why bytes, a compact
   code for a small machine. *)

type oop = St_memory.oop

val special_selectors : string array (* the 32, in order *)

(*****************************************************************************)
(* The header *)
(*****************************************************************************)

type header = { primitive : int; num_args : int; num_temps : int (* the arguments included *); frame_size : int }

val encode_header : header -> int
val decode_header : int -> header

(* an encoded header's fields, one at a time: the interpreter's sends *)
val primitive_of : int -> int
val num_args_of : int -> int
val num_temps_of : int -> int
val frame_size_of : int -> int

(*****************************************************************************)
(* A CompiledMethod *)
(*****************************************************************************)

val trailer_size : int

(* (the last argument: the source, the pc map, the temporaries' names) *)
val new_method :
  St_memory.t ->
  header:header ->
  literals:oop array ->
  bytecodes:Bytes.t ->
  selector:oop ->
  cls:oop ->
  string * (int * int * int) list * string list ->
  oop

val header : St_memory.t -> oop -> header
val literals : St_memory.t -> oop -> oop array (* a copy *)
val literal : St_memory.t -> oop -> int -> oop
val bytecodes : St_memory.t -> oop -> Bytes.t
val selector : St_memory.t -> oop -> oop
val method_class : St_memory.t -> oop -> oop
val source : St_memory.t -> oop -> string

(* each send: its pc, and where its text starts and stops *)
val pcmap : St_memory.t -> oop -> (int * int * int) list

(* the temporaries' names, by index: the arguments first, then the
 * method's temporaries, then its blocks' (which are the method's too) *)
val temp_names : St_memory.t -> oop -> string list

(*****************************************************************************)
(* Reading them *)
(*****************************************************************************)

(* the instructions from pc, each "pc <bytes> meaning", literals shown
 * by [show_literal] *)
val disassemble : show_literal:(int -> string) -> Bytes.t -> (int * string) list

(* how long the instruction at pc is, in bytes *)
val length_at : Bytes.t -> int -> int

(* whether the instruction at pc is a send, and of how many arguments *)
val is_send : Bytes.t -> int -> bool
