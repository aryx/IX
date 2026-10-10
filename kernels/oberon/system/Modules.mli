(* The commands (Oberon's Modules, less its loader): a command is a
 * procedure with no parameter that any text can call by its name,
 * M.P, clicked with the middle key; it reads what follows its name
 * (Oberon.par).
 *
 * In Oberon a module is loaded from its object file the first time
 * one of its commands is called, and the command found in it. Here
 * every module is linked in the kernel's image, and when it starts it
 * says its commands, by name, to this table (plan_system_oberon.md,
 * decision 2): no module comes later, none is freed.
 *
 * road-not-taken:
 * What is lost with the loader is half of Oberon's idea. There, a
 * program is not started and ended: its module is loaded once, its
 * global variables live on between two commands, and other modules
 * loaded later call its procedures and extend its types directly.
 * Nothing is linked ahead of time, there are no processes and no
 * files of state to pass between them: the modules are the system,
 * and the compiler's check of an interface (a key in each object
 * file, compared at loading) is what keeps them consistent. Unix's
 * shared libraries and plug-ins came to the dynamic half of it;
 * Java's classes loaded by name are the closest that prevailed. *)

(* [command "System.Open" p]: said by a module, when it starts *)
val command : string -> (unit -> unit) -> unit
val this_command : string -> (unit -> unit) option
(* the modules that have commands, in the order they started; a module's commands *)
val modules : unit -> string list
val commands : string -> string list
