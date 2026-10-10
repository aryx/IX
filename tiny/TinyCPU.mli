(* tiny-cpu: TinyLibCPU.ml's CPU run alone, as a user program runs:
 * its memory is memory, and a system call is the host's, three of
 * them; those, its usage and examples: [help], what tiny-cpu -h prints.
 *
 * The instruction set, the assembler, the interpreter and their laws
 * are TinyLibCPU.ml's; TinyMachine.ml runs the same CPU with devices
 * and a kernel, where a system call is a trap.
 *
 * The link is TinyLibCPU's: the .tm files one after the other, their
 * labels one namespace, the first at 0 where the CPU starts. The
 * arguments are where a C program's main finds them (tiny-c -tm's
 * convention, TinyC/libc/start.tm): their strings at the top of
 * memory, and sp on argc, then argv; argv[0] is the image's name, or
 * the last .tm's without its .tm.
 *
 *     2^20, the top       the arguments' strings, a 0 after each
 *     sp + 8              argv[0] ... argv[n-1], their addresses, a 0
 *     sp + 4              argv: sp + 8
 *     sp, 8-aligned       argc: n
 *       ...               the stack, growing down
 *       ...               whatever the program does with the rest
 *     0                   the image: the first .tm's first word,
 *                         where the pc starts
 *
 * No header, no segments, no loader: the image is the memory's first
 * bytes. What an executable's header is for (where to put it, where
 * to start, how much to zero) is here three constants: at 0, from 0,
 * everything. TinyCPUArm, the same program around the other CPU, must
 * read an ELF's header for the same three answers, since Linux's
 * kernel does.
 *
 * Where it stands: the first rung for a program on this machine.
 * tiny-c -tm's programs run here with its libc (start.tm's three
 * calls are these); the same assembly linked after a kernel runs on
 * TinyMachine, where sys traps to that kernel and not to OCaml. *)

(* an image's bytes, loaded and run with its arguments, its system
 * calls done here: to its exit status *)
val interpret : < Cap.stdin; Cap.stdout; Cap.stderr; .. > -> string -> string list -> int

(* the program: its arguments (-h: how) to its exit status *)
val main : < Cap.stdin; Cap.stdout; Cap.stderr; Cap.argv; Cap.open_in; Cap.open_out; .. > -> int
