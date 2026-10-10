(* mini-xv6's exec (xv6-riscv's exec.c, xv6 arm64-pi4's): a program
 * file, an ELF linked at 0 (ELF32 on the Pi1, ELF64 on the Pi4: the
 * board's class, Arch.elf_class), made the process's memory:
 *
 *     0           the program's segments (page-aligned)
 *     sz - 8K     the guard page: mapped, the kernel's (a stack
 *                 overflowing faults, and the kernel's copies refuse it)
 *     sz - 4K     the stack, one page: from its top, the argument
 *                 strings, each 16-byte aligned, then argv[0] ...
 *                 argv[argc-1], 0 (the board's words), 16-byte aligned,
 *                 sp at it; what does not fit the page fails the exec
 *     sz
 *
 * and main(argc, argv) entered: pc the ELF's entry, the first register
 * argc (exec's result), the second argv; the process named after the
 * path's last element.
 *
 * The new memory is made whole in a table of its own, beside the one
 * the process runs in, and only then put in its place and the old
 * one freed: a file that is no program, a segment that does not fit,
 * arguments too long, and exec returns -1 to a process that lost
 * nothing. The strings of argv are read from the old memory by
 * Syscall before this module is called, since they are gone with it.
 *
 * Of the ELF file only the program headers are read, and of them
 * those of type 1 (PT_LOAD): where in the file, where in memory (a
 * page's start), how many bytes of the file (filesz) and of memory
 * (memsz, the rest zeros: the bss). ix's own linker (mini-ld) writes
 * such files, and its loader for Plan 9's a.out is mini-9pi's Exec.
 *
 * design:
 * exec does not make a process, and fork does not run a program:
 * Unix's two calls where other systems have one that takes the
 * program and a description of the child. Between the two, the
 * child, still the shell's code, arranges its own files (a
 * redirection, a pipe's end made descriptor 1: Process.mli in the
 * shell) and the program then started finds them so, with no call
 * that knows about redirections. exec keeps the open files, the
 * directory and the pid, and changes the memory only.
 *
 * cs-history:
 * The pair is from the first Unix (1969-1970): fork was a few lines
 * added to what the PDP-7 system already had, exec was at first done
 * by the shell itself, reading the program over its own code (Dennis
 * Ritchie's account). fork's cost, a whole memory copied to be
 * thrown away at the exec, was answered by vfork at Berkeley (1979)
 * and then by copying pages only when written; here, as in xv6, it
 * is copied (Mmu.copy).
 *
 * others:
 * The guard page is an unmapped (here: kernel's) page under the
 * stack, so that a stack grown too far faults at once. A Unix of
 * today also puts the stack, the heap and the libraries at random
 * addresses, and loads nothing here at all: it maps the file, and a
 * page is read at its first fault. mini-9pi's exec, Plan 9's, does
 * the latter: only the header is read, the rest comes at its first
 * touch (its Exec.mli has the layout, drawn as the one above).
 *
 * References: the xv6 book's "Code: exec", and its exercises on the
 * stack's layout; xv6-riscv's exec.c. Dennis Ritchie, "The Evolution
 * of the Unix Time-sharing System" (1979), "Process control": how
 * fork and exec came apart. The System V ABI's chapter on object
 * files, for the ELF header's and the program headers' fields. *)

(* [exec path argv]: argc, the running process running the program; or
 * -1, the process as it was *)
val exec : string -> string list -> int
