(* St_primitives: what the virtual machine does itself.

   A method may name a primitive, "<primitive: 60>"; when it is sent,
   the primitive runs first, and the method's Smalltalk code only if
   the primitive fails -- an index out of bounds, an argument of the
   wrong class. So "at:" is a primitive whose failure is handled in
   Smalltalk ("self error: 'index out of bounds'"), and SmallInteger's
   "+" one whose failure (an overflow) falls back on the kernel's
   LargePositiveInteger, written in Smalltalk.

   The numbers are the Blue Book's (chapter 29), where it has one:

     1-17     SmallInteger: + - < > <= >= = ~= * / \\ // quo: bitAnd:
              bitOr: bitXor: bitShift:
     18       @, a Point
     40       SmallInteger asFloat
     41-50    Float: + - < > <= >= = ~= * /
     51       Float truncated; 55 sqrt, 56 sin, 57 arcTan, 58 ln, 59 exp
     60-62    at:  at:put:  size (fields, or bytes as SmallIntegers)
     63-64    a String's at: at:put:, Characters
     68-69    a CompiledMethod's objectAt: objectAt:put:
     70-71    new  new:
     72       become:
     73-74    instVarAt:  instVarAt:put:
     75       identityHash (asOop)
     80       blockCopy:
     81       value, value:, value:value:... (the arity checked)
     82       valueWithArguments:
     83       perform:, perform:with:...
     84       perform:withArguments:
     90       Sensor mousePoint; 91 the buttons (4 red, 2 yellow, 1 blue)
     92       Sensor keyboard: the next character typed, or nil (ours:
              the Blue Book's Sensor read a queue filled by the
              machine's interrupts)
     96       BitBlt copyBits (St_bitblt.mli, St_colorblt.mli)
     105      replaceFrom:to:with:startingAt:
     110      ==
     111      class

   and ours, from 120 (the Blue Book did these in Smalltalk, over the
   display and the files it had):

     120      Character value:, the unique Character of a code
     122      String asSymbol
     123      String = String, 124 String < String, 125 String hash
     130      Float printString
     140      the Transcript shows a String
     141      suspend the process, with a label: error:, halt, the
              debugger's notifier (St_debug.mli)
     142      Behavior compile:classified:, the Browser's accept
     143      Class subclass:instanceVariableNames:classVariableNames:
              poolDictionaries:category:, a class defined
     144      the millisecond clock
     145      Behavior allInstances
     146      Smalltalk garbageCollect: entries freed
     147      Behavior canUnderstand:, 148 includesSelector:
     149      Behavior selectors, an Array of Symbols
     150      String asNumber (the lexer's numbers)
     151-152  variableSubclass:..., variableByteSubclass:...
     153      shallowCopy
     154      SmallInteger asLargeInteger, 155 LargeInteger normalize
     156      CompiledMethod selector, 157 methodClass
     158      inspect, an Inspector opened by the host
     159      CompiledMethod getSource, its text

   Where it stands: [install] fills St_interp's table once, at the
   boot or when an image is loaded; St_interp calls an entry when a
   method's header names it. The primitives reach the rest of the
   machine from here: St_memory (new, become:, the collector),
   St_bitblt and St_colorblt (96), St_compile and St_class (142,
   143), the host (90 to 92, 140, 144, 158).

   reframe:
   The primitives are the virtual machine's system calls: a table of
   numbers, the only door from the language to what is under it,
   arguments checked at the door, and a failure the caller must deal
   with. A kernel's table is the same thing a level down (mini-9pi's
   system calls, by number too), and the host record of St_interp is
   what this machine in turn asks of its own kernel. The difference
   is the failure: a system call gives an error back, a primitive
   that fails runs the Smalltalk written under it in the same method,
   which may do the whole thing slowly and rightly.

   design:
   The fast case in the machine, every other case in the language.
   SmallInteger's + adds two tagged words and gives up on anything
   else -- an overflow, a Float, a Fraction -- and the Smalltalk
   after it sorts the cases out with ordinary sends. So the machine
   stays small and wrong in no case, and the system's meaning is all
   in Smalltalk, where it can be read and changed. A processor that
   traps on an instruction it does not have, for the kernel to do it
   in software, is the same split.

   others:
   Squeak kept the numbers for the old primitives and named the new
   ones: a method says the name and the module it is in, and the
   machine finds it at the first call, so a primitive can be added
   without a number being agreed on. Its BitBlt and its sound are
   such modules, written in Smalltalk and translated to C.

   References: the Blue Book, chapter 29, "Formal Specification of
   the Primitive Methods": each one in Smalltalk, with what makes it
   fail. Ingalls and others, "Back to the Future" (OOPSLA 1997), for
   the primitives written in Smalltalk. *)

val install : St_interp.vm -> unit
