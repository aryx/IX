(* Tiger to .NET: a program's tree (Tiger_tree) as an assembly's bytes
 * (Writer), which Microsoft's dotnet and mini-dotnet both run. The
 * plan's lesson 2: a language put on a machine that was not made for
 * it, Tiger's nested functions on .NET's static methods.
 *
 *     Tiger                      .NET
 *     int, string                int32, System.String
 *     a record type              a class of fields (its name and a number)
 *     an array type              T[]
 *     nil                        null
 *     = on strings               String::op_Equality: their text
 *     = on records, arrays       ceq: the same object
 *     exception e                a class of System.Exception's
 *     raise e                    newobj e; throw
 *     try ... handle e ...       .try, a catch e for each handler
 *     the program                Program::Main, its int value the exit status
 *     a function                 a static method of Program
 *     print, ord, substring...   the class Tiger's, a few instructions on
 *                                Console and String
 *
 * {b Nested functions, which .NET has not.} A function whose variables
 * a function nested in it uses (they escape: Tiger_semant) gets a
 * frame, an object of a class of its own: those variables are its
 * fields, the others stay IL's locals and arguments. A nested function
 * takes its parent's frame as its first argument, the static link, and
 * a frame keeps its parent's in its field `link`:
 *
 *     let var n := 0                       class frame_main { int n_1; }
 *         function add(k: int) =           static void add_3(frame_main link, int k)
 *           let function twice() =           frame_add_3 f = new frame_add_3();
 *                 (n := n + k;                 f.link = link; f.k_4 = k;
 *                  n := n + k)                 twice_6(f);
 *           in twice() end                 static void twice_6(frame_add_3 link)
 *     in add(5); printi(n) end               link.link.n_1 = link.link.n_1 + link.k_4 ...
 *
 * Where a C compiler keeps the frame on the stack and the static link
 * in a register, here they are objects on the heap, collected; a
 * function with no nested function has no frame at all, as Appel's
 * escape analysis lets a C compiler keep its variables in registers.
 *
 * A method's .maxstack is the writer's (Writer computes it); a try is
 * entered with an empty stack, as .NET asks: Tiger's try is a statement
 * in the programs here (inside an expression it would not be). *)

(* the assembly of this name *)
val program : string -> Tiger_tree.program -> string
