(* St_image: the whole object memory as bytes, and back.

   Smalltalk's persistence: you keep the world, not files. Saving
   writes every object -- the classes, their methods, the globals,
   whatever the Workspace made -- and loading gives the same world
   back, the methods accepted since the boot in it. (The Blue Book's
   image was the same idea, its format the object table as the machine
   had it in memory; ours is our own.)

   The format: a line saying what it is, then the objects the virtual
   machine knows by name (St_memory.known), then each object: its index
   in the table, its class, and its body -- fields (as oops), bytes, a
   float's 64 bits, or a method's both. Numbers are written in LEB128
   varints; an oop as its tag and its payload, a SmallInteger's value
   zigzagged, so that the same bytes are read with 63-bit ints and with
   the web's 32. The processes are not saved: a loaded world is at
   rest.

     a number, 300      AC 02     seven bits a byte, the low ones
                                  first, the high bit: more follows
     an oop, one byte when it is small: bit 0 the tag, bits 1 to 6
     the payload's low bits, bit 7: more follows, as a number
       nil (the oop 0)       00
       the SmallInteger 3    0D   tag 1, payload 6: 3 zigzagged
       the SmallInteger -1   03   tag 1, payload 1 (0 -1 1 -2 as 0 1 2 3)
       the SmallInteger 100  91 03
     an object: its index, its class (an oop), then a letter and
     its body. #(3 nil), the entry 40, Array the oop c:
       28 c 'P' 02 0D 00          P fields, B bytes, F a float,
                                  M a method: fields then bytes

   Nothing is said of where an object is: an oop is an index in the
   table (St_memory.mli), so an image is the table written entry by
   entry, and loading needs no pointer changed. That is the object
   table's other gift, with become:.

   Where it stands: mini-smalltalk -o writes one and -i starts from
   it (CLI), Squeak.resume too: on the bare Pi it is the difference
   between the system's 6,500 lines of Smalltalk compiled at each
   start and none.

   cs-history:
   The image is older than Smalltalk: Lisp systems saved their whole
   memory to a file and started from it (Interlisp's sysout; GNU
   Emacs is still built so, its Lisp loaded once and the memory
   dumped into the program people run). Smalltalk made it the only
   way: the system has no other form than its image, and the one of
   today was made by saving the one of the day before, back to the
   1970s. A source file (St_chunk.mli) is a way to send a change, not
   where the program is.

   road-not-taken:
   Keeping the world and not files is what stayed Smalltalk's alone.
   Everything around it went the other way, to text in files: the
   editors, diff, version control, the build. A program that is
   objects in an image cannot be read without the system, compared
   line by line, or merged by tools that know nothing of it, and two
   people's images do not add up. What was kept from the idea is
   narrower: a session's state saved (a notebook, a virtual machine's
   snapshot, a laptop put to sleep), never the program itself.

   others:
   The bytes' two devices have other homes: the varint is LEB128,
   from the DWARF debugging format, and WebAssembly's integers; the
   zigzag for negatives is Protocol Buffers'. *)

val save : St_memory.t -> string

(* raises Failure on bytes that are not an image *)
val load : string -> St_memory.t

(* a running system from an image: the machine and its primitives *)
val load_vm : St_interp.host -> string -> St_interp.vm
