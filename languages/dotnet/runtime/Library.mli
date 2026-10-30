(* .NET's library, ix's own: the classes of `System` that the programs
 * name, each member an OCaml function over the machine's values
 * (plan_dotnet.md, decision 3). Microsoft's cannot be run:
 * System.Private.CoreLib.dll is 2,466 types and 33,768 methods, much
 * of it about the runtime itself (threads, the collector, P/Invoke), and
 * the survey's ten programs ask 47 of its members.
 *
 * A class is described here as data, its members' signatures written
 * as the keys by which a reference names them (Value.typ_key), and
 * loaded by Types as an assembly's class is: laid out, its virtual
 * methods given their slots. So a program's class can derive from
 * Exception, and Console.WriteLine(object) calls a program's ToString.
 *
 *     callvirt instance string System.String::Substring(int32)
 *        Types: the class System.String, its method of key
 *               "Substring(System.Int32)System.String"
 *        here:  inst "Substring" [ int ] string (fun a -> ... String.sub ...)
 *
 * What only the machine can do (a virtual call, an exception thrown, a
 * class instantiated) a member asks by [hooks], which Machine fills.
 *
 * The adapters are lib_core's code under .NET's names: a string is an
 * OCaml string and its methods String's, StringBuilder a Buffer, List
 * a growing array, a Dictionary a Hashtbl to the entries in their
 * order of insertion, Console the standard output by its capability.
 *
 * others:
 * Chris Bacon's DotNetAnywhere (2009, an interpreter in C that the
 * first Blazor ran in the browser) took the same path: its own
 * corlib, in C# with its internal calls in C. Mono and .NET Core run
 * Microsoft's library, written in C#, over a few hundred "FCalls" into
 * the runtime. *)

open Value

type impl =
  | Impl of (value array -> value)     (* the arguments, `this` first *)
  | By_runtime                         (* a delegate's .ctor and Invoke *)
  | Abstract

type smeth = {
  mn : string;
  mstatic : bool;
  mvirt : bool;
  mparams : string list;               (* keys: "System.Int32", "!0", "!!0[]" *)
  mret : string;
  mgeneric : int;
  impl : impl;
}

type spec = {
  sname : string;                      (* System.Collections.Generic.List`1 *)
  sparent : string;                    (* "" for System.Object *)
  skind : kind;
  sgeneric : int;
  sinterfaces : string list;
  sfields : (string * string) list;    (* the instance fields: name, type's key *)
  smethods : smeth list;
}

(* the classes, by name *)
val specs : (string, spec) Hashtbl.t

type hooks = {
  mutable out : string -> unit;                 (* the console's output *)
  mutable read : unit -> int;                   (* a byte of its input, -1 at its end *)
  mutable to_string : value -> string;          (* the virtual ToString, "" for null *)
  mutable equals : value -> value -> bool;      (* the virtual Equals *)
  mutable hash : value -> int;                  (* the virtual GetHashCode *)
  mutable throw : string -> string -> value;    (* a class of the library's, a message: raises Thrown *)
  mutable instance : string -> typ array -> cls;  (* a class, instantiated *)
}
val hooks : hooks

(* Environment.Exit's: the program stops, with this status *)
exception Exit of int

(* a number as .NET writes it: an int32's ToString, a double's shortest
 * form that reads back the same (1.5, 1E+20) *)
val format_double : float -> string
(* a value whose type is a number, as its ToString *)
val format : typ -> value -> string
