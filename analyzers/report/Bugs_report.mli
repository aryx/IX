(* mini-analyze -bugs' report for an ML program: each analysis of
 * docs/plans/plan_bug_analyses.md written so far, over its rules'
 * answers, a line a bug that may be, named by its analysis, the file as
 * mini-analyze was given it:
 *
 *   bug? Before.ml:6: physeq: in Before.loop, != of a Some made there: always true
 *   bug? Devmnt.ml:85: stack: wait calls itself in a try's handler: no tail call by mini-ml
 *   bug? Process.ml:46: swallowed: in fork, Sys_error silenced, a constant answered
 *   bug? Main.ml:67: crash: in Main.guard, Fault.Error caught by all, the handler raising Failure
 *   bug? Sha1.ml:6: int31: in Sha1's toplevel, 0xffffffff: not on the Pi 1's 31 bits
 *   bug? Unbox.ml:129: order: in Unbox.func, a table's order reaches the output at Asm.ml:214
 *   bug? Link.ml:181: sharing: in Link.write_library, Marshal without No_sharing: its bytes the compiler's
 *   bug? Poly1305.ml: init: Poly1305's start reads Bignum.modulus (in
 *        Poly1305's toplevel), Bignum starting after it
 *   bug? Collide.ml: link: two units Collide, Collide.ml and
 *        physics/Collide.ml: which one is linked the build's
 *   bug? TinyMachine.ml:66: race: console_type, run by a signal's
 *        handler (TinyMachine.ml:52), writes a console's next and queue,
 *        as console_poll does
 *   bug? Event.ml:70: wait: in Event.basic_sync, Condition.wait not in a
 *        while: woken for another, it goes on
 *   bug? CLI.ml:31: leak: in CLI.read_file, taken here, given back at
 *        CLI.ml:33, not when CLI.ml:32 raises End_of_file
 *
 * physeq (analyzers/datalog/bugs/physeq.dl): == or != with a side made in
 * the comparison itself, or comparing a value kept with one changed in
 * place, its type not the function's to know (282b689b's model). stack (bugs/stack.dl): a recursion the stack may
 * not hold, a loop through a try, or a frame for each element of a
 * list. swallowed (bugs/swallowed.dl): an error of the system that may
 * arrive at a try whose case answers a constant, saying nothing. crash
 * (exceptions.dl's ends_in): a program's own exception that may reach a
 * try catching all whose handler raises another (the kernel's guard and
 * its panic: 4436f60d's page refused). int31 (bugs/intwidth.dl): a
 * literal or a shift an int of the Pi 1, 31 bits, does not hold, in a
 * unit meant for it too, a line a function (Sha1's mask, e92ae1ec).
 * order (bugs/order.dl): a walk of a Hashtbl whose order reaches an
 * output, a line a walk with the outputs (d22c56e4's Unbox); sharing: a
 * Marshal without No_sharing (ca664887's Asm.save). init
 * (bugs/init.dl): a unit's start reading a global of a unit that starts
 * after it (70b6b2bf's Poly1305); link: two files of one unit's name,
 * each named by units of its directory (6264d271's Collide). race
 * (bugs/races.dl): a field written by what a signal's handler runs and
 * by the program, of an object the program made, a line a function of
 * the handler and an object (threads not yet)
 * (11c5d5f0's ^C); wait: a Condition.wait not in a while (ddb60eef's
 * Event.sync). leak (bugs/pairs.dl): a resource a function takes and
 * gives back, held on a path to a call that may raise (f7b1aef0's
 * read_file), a line a call taking it. unused (bugs/unused.dl): a local
 * variable never read, not named _x: OCaml's warnings 26 and 27 by
 * rules, a line its function's. layout (bugs/layout.dl): a statement in
 * the column of an if's branch above, not in it (b9fea684's else). Only
 * the program's own units, and code that is reached. *)

(* the report, on the facts and the rules' answers *)
val bugs_report : < Cap.stdout; .. > -> Datalog.t -> unit

(* -bugs given C files and ML ones, the runtime's and the library's: an
 * external's [@@raise E] against what its C raises (bugs/raises.dl)
 *
 *   bug? Sys.ml: raises: Sys.getenv's C (sys_getenv) may raise Not_found, not said ([@@raise Not_found])
 *)
val raises_report : < Cap.stdout; .. > -> Datalog.t -> unit
