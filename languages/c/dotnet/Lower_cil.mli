(* mini-cc -dotnet's back end: a C file to a .NET assembly, a class of
 * its name holding its functions as static methods and its globals as
 * static fields, with libc.c read after it (CLI's prelude).
 *
 *     ptr.c                   ptr.dll
 *     int a[10];              class ptr { static int32[] a;
 *     int sum(int *p, int n)    static int32 sum(Ptr<int32>, int32)
 *     void main(int, char**x)   static void main(int32, Ptr<Ptr<int8>>)
 *                               static void Main(string[]): argv, main,
 *                                 exits(nil)
 *                               .cctor: the globals' arrays, <init> }
 *     (libc.c's)                print's _puts..., strlen, exits...
 *
 * A function's variables are found before its code is made: each name
 * of its typed body, and the ones whose address is taken, which get an
 * array of one element; its arrays and structures are made at its
 * start. A global's initializer (Declare's gextern) is an element
 * stored in <init>, which the class's initializer (.cctor) calls after
 * making each global's array; a literal's array is made at its first
 * use. The entry point, Main, makes C's argv of .NET's arguments, the
 * program's name first (./ptr), and calls exits(nil) after main, which
 * writes what is buffered.
 *
 * What is refused (Cil_types.refuse) is the front end's error, at its
 * line. *)

(* an assembly begun, of this name *)
val start : string -> unit

(* Declare's hooks: a function's body, a global's initializer at an
 * offset *)
val func : Tree.sym -> Tree.stmt -> unit
val gextern : Tree.sym -> Tree.expr -> int -> int -> unit

(* the assembly's bytes: every function called is defined *)
val finish : unit -> string
