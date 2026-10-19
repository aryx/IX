(* tiny-cpu runs the CPU alone, the way a user program runs: its
 * memory is plain memory, and a system call is handled by the host,
 * which provides three of them. Those calls, the usage and some
 * examples are in [help], which is what tiny-cpu -h prints.
 *
 * The CPU itself is not in this file; this file is only its command
 * line. The instruction set, the interpreter and their invariants are
 * in TinyMachine/TinyMachineCPU.ml, the file to read
 * first (its .mli describes the design). They live there because
 * TinyMachine.ml runs the same CPU with devices and a kernel, where a
 * system call is a trap.
 *
 * The image is tiny-linker's: the objects one after the other, their
 * labels one namespace, the first at address 0, where the CPU starts.
 * The arguments are put where the main of a C program expects them
 * (the convention of tiny-c, in TinyCRuntime/start.tm): the strings go
 * at the top of memory, and sp points to argc, followed by argv.
 * argv[0] is the name of the image.
 *
 *     2^20, the top       the argument strings, each followed by a 0
 *     sp + 8              argv[0] ... argv[n-1], their addresses, a 0
 *     sp + 4              argv: sp + 8
 *     sp, 8-aligned       argc: n
 *       ...               the stack, growing down
 *       ...               whatever the program does with the rest
 *     0                   the image: the first word of the first
 *                         object, where the pc starts
 *
 * There is no header, no segments and no loader: the image is simply
 * the first bytes of memory. The questions that an executable header
 * answers (where to load it, where to start, how much to zero) are
 * answered here by three constants: at 0, from 0, and everything.
 * mini-5i (machine/), the same program built around an ARM, has to
 * read an ELF header to get the same three answers, because that is
 * what the Linux kernel does.
 *
 * Status: this is the first step for running a program on this
 * machine. Programs compiled by tiny-c run here with its libc (the
 * three calls made by start.tm are the three calls provided here).
 * The same assembly, linked after a kernel, runs on TinyMachine, where
 * sys traps to that kernel instead of to OCaml. *)

(* an image's bytes, loaded and run with its arguments, its system
 * calls done here: to its exit status. With a profile, each instruction
 * run is counted into it (-prof). *)
val interpret : < Cap.stdin; Cap.stdout; Cap.stderr; .. > -> TinyMachineCPU.profile option -> string -> string list -> int

(* the program: its arguments (-h: how) to its exit status *)
val main : < Cap.stdin; Cap.stdout; Cap.stderr; Cap.argv; Cap.open_in; Cap.open_out; .. > -> int
