(* A program of the reduced C# to an assembly: its classes declared
 * first (their TypeDefs' rows known before they are made, so a class
 * may name one declared after it), their parents, fields, methods,
 * constructors (a default one where none is written), a static
 * constructor for the static fields' initial values; a method an
 * interface asks made virtual (C#'s "virtual final", as .NET's dispatch
 * through an interface wants); then each body (Csc_emit). *)

val program : string -> Csc_ast.program -> string
