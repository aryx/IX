(* The Linux process that a program starts as, and its system calls
 * (the user-mode personality, plan_arm.md, decision 6).
 *
 * The stack, from sp up, as Linux's execve leaves it:
 *
 *   sp ->  argc
 *          argv[0] .. argv[argc-1], 0
 *          envp[0] .. , 0
 *          auxv: (AT_PAGESZ, 4096), (AT_ENTRY, entry), (AT_RANDOM, p),
 *                (AT_NULL, 0)
 *          ... the strings, 16 random bytes
 *
 * A system call on arm32 is `svc 0`, with its number in r7 (EABI), the
 * arguments in r0-r5 (a 64-bit one in an even pair), and the result in
 * r0; an error is returned as -errno. The guest's structures are laid
 * out as the arm32 ABI has them: struct stat64 is 104 bytes, with the
 * size at 48, the times at 72 and the 64-bit inode at 96, as goken's
 * os/linux/stat_arm.c reads them.
 *
 * The calls reach the host through Host_calls's record of functions,
 * so this module uses no Unix.
 *
 * Signals: the host notes a signal (raise_signal). Between two
 * instructions, [deliver] saves the registers on the guest's stack and
 * enters the handler with lr pointing at a trampoline page. The page
 * holds "mov r7, #119; svc 0", a sigreturn, as the kernel's sigpage
 * does for handlers without a restorer (which is goken's case), and
 * that sigreturn puts the registers back.
 *
 * Here is a whole call, from goken's hello (the assembler's CLI.mli
 * has the source). The program sets four registers and traps.
 *
 *     r7 = 4, r0 = 1, r1 = msg's address, r2 = 13;  svc 0
 *       Arm32.execute -> svc -> syscall32
 *         4 is write: the 13 bytes at r1 are read from the Memory,
 *         and Host_calls's write 1 "Hello, world\n" returns Ok 13
 *       r0 = 13, and the program goes on after the svc
 *
 * The program cannot tell this from Linux. To a program, a kernel is
 * those numbers and those layouts (the ABI), and nothing of how they
 * are answered. This whole module is that contract, for the calls that
 * ix's and goken's programs make, which are a small part of Linux's
 * several hundred.
 *
 * Where it stands: it is the same seam as the kernels' own system
 * call tables, seen from outside. In mini-9pi the svc is an exception
 * that Arm32.take delivers to the kernel's C code; here it is a call
 * to an OCaml function. Plan9 is the other personality: the same
 * record of host functions under another system's calls.
 *
 * others:
 * Answering one system's calls on another is an old trick with many
 * names: QEMU's user mode (which converts the layouts between guest
 * and host, as here), FreeBSD's Linux emulation in its kernel,
 * Microsoft's first WSL, and linuxemu on Plan 9. Wine does it one
 * level up, at the libraries. They all stop where the interface stops
 * being calls and layouts: /proc, ioctl, the devices. *)

exception Exit of int

(* execve of a program, with the path, argv and envp; the caller
 * loads it *)
exception Exec of string * string list * string list

type proc

(* maps the ELF's segments, the heap, the stack and the trampoline,
 * and returns the process, the entry and the initial sp *)
val load : Host_calls.t -> Memory.t -> Elf.t -> string -> string list -> string list -> proc * int * int

(* logs each call to standard error as "[pid] nr(a0, a1, a2) = result"
 * (-y) *)
val log_calls : bool ref

(* arm32's svc, with the call's number in r7 *)
val syscall32 : proc -> Arm32_isa.state -> unit

(* arm64's svc, with the call's number in x8. It uses asm-generic's
 * numbers and structures: struct stat is 128 bytes, timespecs are 64
 * bits, and the stack's vectors (argv, envp, auxv) have 8-byte
 * entries. *)
val syscall64 : proc -> Arm64_isa.state -> unit

(* a signal the host received *)
val raise_signal : int -> unit

(* takes the signals received and not yet delivered, for another
 * personality that delivers them its own way (Plan9's notes) *)
val take_signals : unit -> int list
val signal_waiting : bool ref

(* delivers the pending signals at [pc], the next instruction *)
val deliver : proc -> Arm32_isa.state -> pc:int -> unit

val deliver64 : proc -> Arm64_isa.state -> pc:int -> unit
