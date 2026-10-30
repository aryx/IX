(* What acid looks at: the program (its a.out, its symbol and line
 * tables: lib_executable's Symbols) and the process run from it,
 * through Plan 9's /proc/$pid files (principia's acid: proc.c,
 * util.c's varsym and varreg, libmach's map.c), as on Plan 9 and under
 * mini-5i (plan_debugger.md, decision 12).
 *
 * The maps, libmach's: an address of the process, as * reads it, is in its
 * registers below the Ureg's size (/proc/$pid/regs: the variables R0,
 * PC, SP... hold their offsets there), in its text and its data up to
 * its stack's top (/proc/$pid/mem); without a process, and for @, in
 * the program's file (its text and data, as the a.out has them). The
 * symbols are acid's variables, each its address in X; symbols is the
 * list of them, {name, type, address}.
 *
 * A process: started by newproc, hung at its exec (ctl's hang) and
 * waited for; a stop (stop, startstop, waitstop) reads its notes
 * (notes) and calls the acid function stopped(pid), the library's
 * (port.acid prints where and why).
 *
 * On Linux (Ptrace.available: dune's mini-acid), the same by ptrace
 * (Ptrace.mli has the table): an ELF's program (gcc's, arm64), its
 * symbols moved where a PIE is put, /proc/$pid/mem, the registers
 * arm64's user_pt_regs and TYPE, the stop's signal; ctl's messages
 * are ptrace's calls, a note the signal's name. *)

type caps = < Cap.open_in; Cap.open_out; Cap.fork; Cap.exec; Cap.kill >

(* the program read (the a.out's path): its variables made, the
 * registers' too; its line ("prog:arm plan 9 executable") printed *)
val program : < caps; .. > -> string -> unit

(* the symbols as variables (acid's varsym, after the libraries) *)
val symbols : unit -> unit

(* the program's declarations of its types, acid's text: the data
 * .acid, mini-ld -g's of mini-cc -g's (and mini-ml's) *)
val declarations : unit -> string option

(* the registers' variables and bpinst, the default set without a
 * program (varreg) *)
val registers : unit -> unit

(* the process attached (setproc) *)
val attach : < caps; .. > -> int -> unit

(* the processes attached, the last first (acid's proclist: at its end
 * it says how to kill them) *)
val attached : unit -> int list

(* the builtins of the program and the process put in Eval.builtins, the
 * maps put in Eval's load, store and symbol *)
val init : < caps; .. > -> unit
