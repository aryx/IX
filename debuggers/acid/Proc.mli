(* What acid looks at: the program (its a.out, with its symbol and line
 * tables, read by lib_executable's Symbols) and the process run from
 * it, through Plan 9's /proc/$pid files (principia's acid: proc.c,
 * util.c's varsym and varreg, libmach's map.c), as on Plan 9 and under
 * mini-5i (plan_debugger.md, decision 12).
 *
 * The maps are libmach's. An address of the process, as * reads it, is
 * in its registers when it is below the size of a Ureg (in
 * /proc/$pid/regs, where the variables R0, PC, SP... hold their
 * offsets), or in its text and its data up to the top of its stack (in
 * /proc/$pid/mem). Without a process, and for @, an address is in the
 * program's file (its text and data, as the a.out has them). Each
 * symbol is an acid variable, whose value is its address in the X
 * format; the variable symbols is the list of them, as {name, type,
 * address}.
 *
 * A process is started by newproc, hung at its exec (with ctl's hang),
 * and waited for. A stop (stop, startstop, waitstop) reads the
 * process's notes (notes) and calls the acid function stopped(pid),
 * which the library defines (port.acid's prints where the process
 * stopped and why).
 *
 * On Linux (when Ptrace.available, in dune's mini-acid), the same is
 * done with ptrace (Ptrace.mli has the table). The program is an ELF
 * (gcc's, for arm64), and its symbols are moved to where a PIE is put.
 * The memory is /proc/$pid/mem. The registers are arm64's user_pt_regs,
 * followed by TYPE, which holds the signal of the stop. ctl's messages
 * become calls to ptrace, and a note is the signal's name. A frame's
 * parameters and locals (for strace and f:v) are found by libmach's
 * walk on arm and by Frame64's on arm64, from the table's entries (7c's,
 * or mini-ld -g's .plan9.syms) or, in a program built by gcc, from
 * DWARF. *)

type caps = < Cap.open_in; Cap.open_out; Cap.fork; Cap.exec; Cap.kill; Cap.env >

(* reads the program (the a.out's path), makes its variables and the
 * registers' variables, and prints its line ("prog:arm plan 9
 * executable") *)
val program : < caps; .. > -> string -> unit

(* makes the symbols into variables (acid's varsym, after the
 * libraries) *)
val symbols : unit -> unit

(* the program's declarations of its types, as acid text: the data
 * symbol .acid, which mini-ld -g writes for the programs of mini-cc -g
 * (and of mini-ml), or, for a gcc ELF without .acid, its DWARF types
 * (Acid_dwarf) *)
val declarations : unit -> string option

(* makes the registers' variables and bpinst, the default set when
 * there is no program (varreg) *)
val registers : unit -> unit

(* attaches the process (setproc) *)
val attach : < caps; .. > -> int -> unit

(* the attached processes, the last one first (acid's proclist, which
 * acid uses at its end to say how to kill them) *)
val attached : unit -> int list

(* puts the builtins of the program and the process in Eval.builtins,
 * and the maps in Eval's load, store and symbol *)
val init : < caps; .. > -> unit
