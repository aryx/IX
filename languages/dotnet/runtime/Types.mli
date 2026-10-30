(* The loader: a class made when it is first named, from its assembly's
 * rows or from the Library's description, and the tokens of a method's
 * IL given their meaning. The runtime's part that ECMA-335 calls the
 * class loader (Partition II, 10 and 22; Partition I, 8.9 and 9).
 *
 * A class, when it is loaded:
 *   - its parent first, then its interfaces;
 *   - its fields laid out (Value: the numbers in the bytes, the
 *     references apart), after its parent's: a subclass's object is
 *     its parent's with more at the end, so a field has one offset in
 *     every subclass;
 *   - its static fields in a store of their own, its static
 *     constructor (.cctor) run when the machine first needs it;
 *   - its virtual methods given their slots: its parent's table
 *     copied, a method that overrides one (same name, same signature,
 *     not `newslot`) takes its slot, the others are added at the end;
 *     a MethodImpl row (C#'s explicit `IFoo.Bar`) says the slot itself.
 *
 *     Shape:  [ ToString | Equals | GetHashCode | Area | Name ]
 *     Square: [ Shape::ToString | ... | Square::Area | Square::Name ]
 *     Rect:   [ Shape::ToString | ... | Rect::Area | Shape::Name ]
 *
 *   so `callvirt Shape::Area` is the slot of Shape::Area looked up in
 *   the object's class's table. An interface's method has no slot in
 *   the class: it is looked for there by its name and signature, once
 *   (the class's imap).
 *
 * {b Generics are kept at run time} (plan_dotnet.md's lesson 5): a
 * generic class is a class only once instantiated, Stack`1[System.Int32]
 * and Stack`1[System.String] two of them, each its own layout (an
 * int32 in the bytes, a string among the references), its own statics,
 * its own Type; a token in a generic method's IL is read in the context
 * of its class's arguments and its own (!0, !!0).
 *
 * A reference to another assembly's member (a TypeRef, a MemberRef) is
 * resolved by its name and its signature's key (Value.typ_key): the
 * library's classes first (System.*: Library), then the assemblies
 * loaded. The assembly a TypeRef names is not read: mini-dotnet has one
 * library, its own.
 *
 * others:
 * The JVM's loader does the same work, a class at a time, with its
 * vtables, but erases the generics: there is one List and its elements
 * are Objects. The CLR shares the code of the instantiations over
 * references (one compiled List<__Canon>) and makes a copy for each
 * value type; here each instantiation has its own records but their IL
 * is the same. *)

open Value

exception Load_error of string

(* an assembly loaded: its classes made when named *)
val load : Image.t -> image

(* what a method's IL is read in: its assembly, its class's type
 * arguments, its own *)
type ctx = { im : image; targs : typ array; margs : typ array }

(* a class by its name (Namespace.Name, Outer+Inner), instantiated *)
val find_class : string -> typ array -> cls
(* the class of a type: System.Int32 for int32, an array's *)
val class_of_typ : typ -> cls
(* the type of a class: int32 for System.Int32, an enum its underlying *)
val typ_of_cls : cls -> typ
val array_class : typ -> cls
val is_value_type : typ -> bool

(* the tokens of a method's IL *)
val typ_of_token : ctx -> int -> typ
val meth_of_token : ctx -> int -> meth
val field_of_token : ctx -> int -> field
(* a MethodDef by its row, for the entry point *)
val meth_of_def : image -> int -> meth

(* a generic method instantiated *)
val instantiate : meth -> typ array -> meth

(* the method a virtual call runs, for an object of this class *)
val virtual_target : cls -> meth -> meth

(* a method's IL, decoded once: its instructions, clauses, locals *)
val code : meth -> code

(* the context a method's tokens are read in *)
val ctx_of : meth -> ctx
