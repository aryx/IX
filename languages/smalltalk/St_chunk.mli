(* St_chunk: the format Smalltalk-80 filed code in and out with.

   A file is chunks of text, each ended by "!" (a "!" inside one
   doubled, "!!"). A chunk is an expression to evaluate -- a class
   defined, a global set -- unless it follows an empty chunk: then it
   is an expression answering a reader, "Point methodsFor: 'arithmetic'",
   and the chunks after it are that category's methods, until an
   empty one.

     Object subclass: #Point
       instanceVariableNames: 'x y'
       classVariableNames: ''
       poolDictionaries: ''
       category: 'Graphics-Primitives'!

     !Point methodsFor: 'accessing'!
     x
         ^x!
     y
         ^y! !

   It is how the kernel is written here (kernel/*.st), bootstrapped by
   St_boot, and what the Browser's "file out" writes: the Blue Book's
   world travelled between machines as this text, the sources file of
   every image in it too.

   What [read] makes of the text above: the first "!" ends the
   definition, and the one before Point ends a chunk with nothing in
   it, which is what announces a reader:

     Doit (the five lines of the definition, 0)
     Methods { class_name = "Point"; meta = false;
               category = "accessing";
               methods = the texts of x and of y, each with its place }

   reframe:
   A file of chunks is not a program's source in the way a C file is:
   it is a script, run chunk after chunk in a system that is already
   there, and each chunk changes that system. "Filing in" a class is
   evaluating the expression that makes it. So a file may do anything
   an expression may, and the order of the chunks matters: a
   database's dump of SQL statements is the nearest thing elsewhere.
   Here St_boot goes over all the kernel's files for their class
   definitions before it compiles a method, for that reason: a method
   may name a class defined after it.

   modern:
   The format is still the one Squeak and Pharo file out, and the
   reason given against it is the one against the image: a file for
   a whole category of classes, written by the system and not by
   hand, is hard to compare and to merge. Pharo's newer format, a
   file a class (Tonel), was made for git. *)

type item =
  (* an expression, and where it starts in the file *)
  | Doit of string * int
  (* "Point methodsFor: 'accessing'" (or "Point class methodsFor:"),
   * then the methods' texts and where each starts *)
  | Methods of { class_name : string; meta : bool; category : string; methods : (string * int) list }

exception Error of int * string

val read : string -> item list

(* a chunk written: its "!"s doubled, a "!" after *)
val chunk : string -> string

(* a category of methods written as the reader wants them *)
val methods_chunk : class_name:string -> meta:bool -> category:string -> string list -> string
