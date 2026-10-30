(* A call's frame, the frames running, and an exception's first pass:
 * what the machine (Machine) and its arithmetic (Arith) share.
 *
 *     frames (the innermost first)
 *       Exceptions::Check   at IL_0009 (a div): DivideByZeroException
 *       Exceptions::Try     at IL_0002 (the call), in a try whose
 *                           catch takes DivideByZeroException
 *       Exceptions::Main    ...
 *
 * {b The first pass} (ECMA-335, Partition I, 12.4.2.5): a frame after
 * the other, its clauses whose try holds the instruction running are
 * asked, a catch by its class, a filter by running its code there and
 * then; nothing is unwound. If none takes it, the program stops
 * ("Unhandled exception"), its finally blocks not run, as .NET does,
 * so that a debugger sees the program where the exception was thrown.
 * Else the exception is raised (Value.Thrown) and the frames are left
 * one by one, their finally blocks run (Machine.run: the second
 * pass), to the clause chosen.
 *
 * others:
 * C++'s exceptions on Itanium's ABI and Windows's SEH have the same two
 * phases, "search" and "cleanup"; OCaml's have one, its handlers a
 * chain on the stack, a raise a jump to the nearest. *)

open Value

(* a mistake of the program's or a feature mini-dotnet has not, with
 * where: not a .NET exception *)
exception Error of string
val error : string -> 'a

(* an exception no frame catches: its class's name and its message *)
exception Unhandled of string * string

(* a recursion too deep (10,000 frames): as .NET, the program stops,
 * no catch can take it *)
exception Stack_overflow

(* each instruction said as it runs (-trace), and the count of them (-s) *)
val trace : (string -> unit) option ref
val steps : int ref

type frame = {
  meth : meth;
  code : code;
  args : value array;
  locals : value array;
  stack : value array;
  mutable sp : int;
  mutable pc : int;              (* the next instruction *)
  mutable at : int;              (* the one running *)
  mutable caught : store option; (* the exception of the catch running: rethrow's *)
}

(* the frames running, the innermost first, and how many *)
val frames : frame list ref
val depth : int ref
val max_depth : int

(* how a run of a method's instructions ends: its return, a finally's
 * end, a filter's answer *)
type outcome = Returned of value | End_finally | Filtered of bool

(* Class::Method *)
val name_of : meth -> string

(* the first pass's choice (the frame and its clause), for the second;
 * a filter's code run (Machine's) *)
val chosen : (frame * int) option ref
val filter_hook : (frame -> clause -> store -> bool) ref
val handled : store -> bool

(* an exception thrown: Thrown if a catch will take it, else Unhandled *)
val throw : store -> 'a
(* one of the library's, made by the machine, with its message *)
val throw_new : string -> string -> 'a
val null_ref : unit -> 'a
val out_of_range : unit -> 'a
val overflow : unit -> 'a
val invalid_cast : cls -> cls -> 'a
