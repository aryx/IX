(* St_class: a class, as the virtual machine and the tools read it.

   A class is an object like any other; its fields are the ones the
   kernel declares (kernel/Kernel-Classes.st), and the virtual machine
   knows their places:

     Behavior          0 superclass  1 methodDict  2 format
     ClassDescription  3 instanceVariables  4 organization
     Class             5 name  6 category  7 classPool  8 comment
     Metaclass         5 thisClass

   The **format** is a SmallInteger, fields * 8 + kind: how many named
   fields an instance has, and whether it has indexed ones -- pointers,
   bytes, a float, a CompiledMethod's mix (kind 0 to 4).

   The **method dictionary** is two Arrays side by side, selectors and
   methods, searched in order (the interpreter's cache makes the
   search rare: St_interp.mli). The Blue Book hashed it; a hundred
   selectors do not need it.

   The **organization**, what the Browser's third pane lists, is an
   Array of Associations, a category's name with the Array of its
   selectors.

   And each class has its **metaclass**, whose only instance it is: the
   class's own methods ("Point x: 3 y: 4") are the metaclass's. The
   knot at the top (Blue Book, chapter 16):

       Object class superclass == Class
       Metaclass class class == Metaclass

   Drawn for Point, an arrow to the right "is an instance of", a line
   down "has for superclass":

     3 @ 4 -> Point ----> Point class ---.
                |              |          \
              Object ---> Object class ----+-> Metaclass -> Metaclass class
                |              |                   ^               |
               nil           Class                 '---------------'
                               |
                       ClassDescription
                               |
                           Behavior
                               |
                            Object

   The metaclasses' chain follows the classes' (Point class under
   Object class), then goes on into Class: so a message to a class is
   looked up as any other, and "Point new" finds new in Behavior, by
   Point class, Object class, Class and ClassDescription. And "is an
   instance of", from any object, is at Metaclass in three steps and
   then goes round: its class, the class's metaclass, Metaclass,
   Metaclass class, Metaclass.

   The globals, "Smalltalk", are a SystemDictionary whose one field is
   an Array of Associations. A global in a method is its Association,
   a literal of the method: "push literal variable" reads its value, so
   redefining a global is seen by every method at once.

   Where it stands: St_boot and the primitive 143 define classes with
   [define_class]; St_compile asks for the instance variables' names
   and [install]s; St_interp's send calls [lookup] when its cache
   misses. [classes], [categories] and [category_selectors] are a
   Browser's three lists, for a Browser written in OCaml, as the
   playground's first one was; Squeak's, in Smalltalk, reads the same
   fields itself.

   cs-history:
   Smalltalk-76 had classes as objects and one class for all of them,
   Class, so every class answered the same messages: a class could
   not have a new of its own that sets its instances up. Smalltalk-80
   gave each class a class of its own, made with it and never named,
   the metaclass: the price is the picture above.

   others:
   The same knot elsewhere. Python's type is its own class, type(type)
   is type, and a class's class may be changed (a metaclass, the word
   kept); Objective-C has Smalltalk's metaclasses as they are; Ruby
   gives any object, a class too, a hidden class for its own methods;
   Java stops a level sooner: a class's methods are static, found
   when compiled and not sent, and Class is a description to read.
   CLOS made the level a programmer's (Kiczales, des Rivieres and
   Bobrow, "The Art of the Metaobject Protocol", 1991).

   References: the Blue Book, chapter 16, "Protocol for Classes" (the
   figures of the two chains) and chapter 5 for metaclasses told to a
   programmer. kernel/Classes.st, where these are Smalltalk. *)

type oop = St_memory.oop

(* the field numbers above *)
val f_superclass : int
val f_method_dict : int
val f_format : int
val f_inst_vars : int
val f_organization : int
val f_name : int
val f_category : int
val f_class_pool : int
val f_comment : int

(*****************************************************************************)
(* Formats *)
(*****************************************************************************)

type kind = Fixed | Indexable | Byte_indexable | Float_kind | Method_kind

val format : St_memory.t -> oop -> int * kind (* named fields, kind *)
val encode_format : int -> kind -> int

(*****************************************************************************)
(* Classes *)
(*****************************************************************************)

val superclass : St_memory.t -> oop -> oop
val is_meta : St_memory.t -> oop -> bool

(* a metaclass's class, and a class's metaclass *)
val this_class : St_memory.t -> oop -> oop
val metaclass : St_memory.t -> oop -> oop

(* "Point", or "Point class" *)
val name : St_memory.t -> oop -> string

(* all the instance variables' names, inherited ones first *)
val inst_var_names : St_memory.t -> oop -> string list

(* the class's own *)
val own_inst_var_names : St_memory.t -> oop -> string list
val category : St_memory.t -> oop -> string
val comment : St_memory.t -> oop -> string

(* the classes, from the globals, in alphabetical order *)
val classes : St_memory.t -> oop list

(* "Object subclass: #Point instanceVariableNames: 'x y' ..." *)
val definition : St_memory.t -> oop -> string

(*****************************************************************************)
(* Methods *)
(*****************************************************************************)

(* in this class only *)
val local_method : St_memory.t -> oop -> oop -> oop option

(* up the superclass chain *)
val lookup : St_memory.t -> oop -> oop -> oop option

(* add or replace a method, filed under a category *)
val install : St_memory.t -> oop -> oop -> oop -> category:string -> unit
val remove : St_memory.t -> oop -> oop -> unit
val selectors : St_memory.t -> oop -> string list

(* the categories, in order, and the selectors of one *)
val categories : St_memory.t -> oop -> string list
val category_selectors : St_memory.t -> oop -> string -> string list
val category_of : St_memory.t -> oop -> string -> string option

(*****************************************************************************)
(* Globals and class variables *)
(*****************************************************************************)

val new_association : St_memory.t -> oop -> oop -> oop
val global : St_memory.t -> string -> oop option (* the Association *)
val declare_global : St_memory.t -> string -> oop -> oop (* the Association, made or updated *)
val globals : St_memory.t -> (string * oop) list (* name, value *)

(* a class variable's Association, searched up the superclass chain,
 * from a metaclass's class too *)
val class_var : St_memory.t -> oop -> string -> oop option

(* a class's own class variables' names *)
val class_var_names : St_memory.t -> oop -> string list

(*****************************************************************************)
(* Defining a class *)
(*****************************************************************************)

(* the classes whose superclass this one is *)
val subclasses : St_memory.t -> oop -> oop list

(* what "Object subclass: #Point instanceVariableNames: 'x y' ..."
 * does: the class and its metaclass made, or the existing class of
 * that name changed in place (its subclasses' formats following), and
 * the global set. The class, and whether its instance variables
 * changed -- then its methods, and its subclasses', must be compiled
 * again (St_compile.recompile), since they use the variables' indexes.
 * The instances of a changed class are left as they were (the Blue
 * Book mutated them with become:, an exercise). *)
val define_class :
  St_memory.t ->
  superclass:oop ->
  name:string ->
  kind:kind ->
  inst_vars:string list ->
  class_vars:string list ->
  category:string ->
  oop * bool

(* a new, empty MethodDictionary *)
val new_method_dict : St_memory.t -> oop
