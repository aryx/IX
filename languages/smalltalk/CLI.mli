(* mini-smalltalk: Smalltalk-80 from the Blue Book, with Squeak's
 * Morphic (docs/plans/plan_system_squeak.md), on a terminal: the system
 * brought up from its text or from an image, files of Smalltalk filed
 * in, expressions printed, the image saved, the Display written as a
 * picture. No window: Squeak's hosts are programs of their own. Its
 * usage: [help] in CLI.ml, what mini-smalltalk -h prints.
 *
 * Smalltalk-80 (Alan Kay, Dan Ingalls, Adele Goldberg and the Learning
 * Research Group, Xerox PARC, 1972-1980; the Byte issue of August 1981
 * and the Blue Book of 1983) is a language and its whole environment,
 * in two halves, and the line between them is the Blue Book's: a
 * virtual machine, here in OCaml, and a system written in Smalltalk
 * (kernel/, St_kernel), which the machine runs and knows little of:
 * where a class keeps its superclass and its methods (St_class), and
 * some twenty classes by name (St_memory.known).
 *
 *     a method's text                   the modules, a text's way
 *        | St_chunk      a file cut in chunks, at each "!"
 *        | St_lexer      tokens
 *        | St_parse      by recursive descent
 *     St_ast.method_
 *        | St_compile    one pass (two with Squeak's closures)
 *     a CompiledMethod   St_bytecode: a header, literals, bytecodes
 *        | St_class      put in its class's method dictionary
 *        | St_interp     fetch, decode, execute; a send finds the method
 *        |-- St_primitives   what no Smalltalk can do: +, at:, new
 *        |-- St_bitblt, St_colorblt   the one that draws
 *        '-- St_debug    a stopped process, read
 *     St_memory          every object: the table, the collector
 *        | St_image      all of it as bytes, and back
 *
 *     St_boot: the four steps from the system's text to a system that
 *     runs. Squeak: its world's cycle, over a host.
 *
 * Smalltalk's lesson is that the environment is the language's own
 * objects, live: the Browser lists the classes and the methods the
 * running system has, and "accept" compiles a method into it at once;
 * an Inspector shows an object's fields; an error stops a process whose
 * frames are the contexts -- objects -- of the computation, where the
 * method can be fixed, restarted, and the program goes on as if it had
 * always been there (St_debug). Nothing is compiled to a file and
 * started again: there is one world, changed while it runs, and kept
 * (St_image).
 *
 * evolution:
 * Smalltalk, from 1972 to Squeak. Alan Kay's group wanted a computer
 * of one's own that a child could program, the Dynabook, and a
 * language for it with one idea, objects that send each other
 * messages, which Kay had seen in Simula (Dahl and Nygaard, the
 * 1960s) and in Sketchpad's masters and instances (Sutherland, 1963).
 * Dan Ingalls wrote each of them. In Smalltalk-72 an object read the
 * message sent to it token by token, each class with a syntax of its
 * own. Smalltalk-76 is the design still in use: one syntax of unary,
 * binary and keyword messages (St_parse), classes that inherit,
 * methods compiled to bytecodes for a virtual machine (St_bytecode),
 * the Browser. Smalltalk-80 is the one cleaned up for the world
 * outside, with metaclasses (St_class), and published: tapes of the
 * image to Apple, DEC, Hewlett-Packard and Tektronix, who each wrote
 * the virtual machine for a machine of theirs from the specification
 * that became the Blue Book's last part. Squeak (1996) started again
 * from that book (Squeak.mli).
 *
 * why-study:
 * Most of what a programmer's screen has today was first put together
 * in this system: overlapping windows and pop-up menus drawn by one
 * primitive (St_bitblt), the browser of classes, the inspector, a
 * debugger that edits the program it has stopped. And much of how a
 * dynamic language is made fast was found making this one fast: the
 * method cache (St_interp), the inline cache and the translation to
 * machine code as the program runs (Deutsch and Schiffman, 1984), the
 * collector by generations (Ungar, 1984). Self (Ungar and Smith,
 * 1987) took them further, and Self's people wrote Java's HotSpot and
 * JavaScript's V8. A browser's JavaScript engine is, underneath, a
 * Smalltalk machine of the fast kind; this one is of the simple kind,
 * the Blue Book's, where each of those ideas has a place to go.
 *
 * others:
 * The languages that took the messages and left the image:
 * Objective-C (Brad Cox, 1980s) is C with Smalltalk's sends in square
 * brackets, [a at: i put: x], compiled to files as C is; Ruby has its
 * blocks, its classes open while the program runs and its method
 * missing, doesNotUnderstand: by another name; Java took the virtual
 * machine, the bytecodes and the collector, with types declared.
 *
 * References: Adele Goldberg and David Robson, "Smalltalk-80: The
 * Language and its Implementation" (Addison-Wesley, 1983), the Blue
 * Book: parts one and two for the language and the classes, part four
 * for the virtual machine, written in Smalltalk, which the St_
 * modules follow chapter by chapter. Byte, August 1981, the issue on
 * Smalltalk: Ingalls's "Design Principles Behind Smalltalk" to read
 * first, a few pages. Alan Kay, "The Early History of Smalltalk" (HOPL
 * II, 1993). Dan Ingalls, "The Smalltalk-76 Programming System:
 * Design and Implementation" (POPL 1978). Glenn Krasner, editor,
 * "Smalltalk-80: Bits of History, Words of Advice" (Addison-Wesley,
 * 1983), the Green Book: what those who wrote the first virtual
 * machines learnt. L. Peter Deutsch and Allan Schiffman, "Efficient
 * Implementation of the Smalltalk-80 System" (POPL 1984). *)

type caps = < Cap.open_in; Cap.open_out; Cap.stdin; Cap.stdout; Cap.stderr >

val main : < caps; .. > -> string array -> int
