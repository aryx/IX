(* The Linux process a program starts as, and its system calls (the
 * user-mode personality, plan_arm.md, decision 6).
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
 * A system call on arm32: `svc 0`, its number in r7 (EABI), arguments
 * in r0-r5 (a 64-bit one in an even pair), the result in r0, an error
 * as -errno. The guest's structures are laid out as the arm32 ABI has
 * them (struct stat64 104 bytes, its size at 48, times at 72, the
 * 64-bit inode at 96: as goken's os/linux/stat_arm.c reads them).
 *
 * The calls reach the host through Host_calls's record of functions:
 * this module uses no Unix.
 *
 * Signals: the host notes a signal (raise_signal); between two
 * instructions [deliver] saves the registers on the guest's stack and
 * enters the handler with lr at a trampoline page ("mov r7, #119; svc
 * 0": a sigreturn, as the kernel's sigpage does for handlers without a
 * restorer, goken's case), whose sigreturn puts the registers back.
 *
 * A call, whole, from goken's hello (the assembler's CLI.mli has the
 * source): the program sets four registers and traps.
 *
 *     r7 = 4, r0 = 1, r1 = msg's address, r2 = 13;  svc 0
 *       Arm32.execute -> svc -> syscall32
 *         4 is write: the 13 bytes at r1 read from the Memory,
 *         Host_calls's write 1 "Hello, world\n" -> Ok 13
 *       r0 = 13, and the instruction after the svc
 *
 * The program cannot tell this from Linux: what a kernel is, to a
 * program, is those numbers and those layouts (the ABI) and nothing
 * of how they are answered. The whole of this module is that
 * contract for the calls ix's and goken's programs make, a small
 * part of Linux's several hundred.
 *
 * Where it stands: the same seam as the kernels' own system call
 * tables, seen from outside. In mini-9pi the svc is an exception
 * that Arm32.take delivers to the kernel's C; here it is a call to
 * an OCaml function. Plan9 is the other personality, the same
 * record of host functions under another system's calls.
 *
 * others:
 * Answering one system's calls on another is an old trick with many
 * names: QEMU's user mode (the layouts converted between guest and
 * host as here), FreeBSD's Linux emulation in its kernel,
 * Microsoft's first WSL, linuxemu on Plan 9. Wine does it one level
 * up, at the libraries. They all end where the interface
 * stops being calls and layouts: /proc, ioctl, the devices. *)

exception Exit of int

(* execve of a program: the path, argv, envp; the caller loads it *)
exception Exec of string * string list * string list

type proc

(* the ELF's segments mapped, the heap, the stack, the trampoline; the
 * process, the entry and the initial sp *)
val load : Host_calls.t -> Memory.t -> Elf.t -> string -> string list -> string list -> proc * int * int

(* each call logged to standard error, "[pid] nr(a0, a1, a2) = result" (-y) *)
val log_calls : bool ref

(* arm32's svc: the call in r7 *)
val syscall32 : proc -> Arm32_isa.state -> unit

(* arm64's svc: the call in x8, asm-generic's numbers and structures
 * (struct stat 128 bytes, 64-bit timespecs, 8-byte vectors) *)
val syscall64 : proc -> Arm64_isa.state -> unit

(* a signal the host received *)
val raise_signal : int -> unit

(* the signals received and not yet delivered, taken (another
 * personality delivers them its own way: Plan9's notes) *)
val take_signals : unit -> int list
val signal_waiting : bool ref

(* the pending signals delivered at [pc], the next instruction *)
val deliver : proc -> Arm32_isa.state -> pc:int -> unit

val deliver64 : proc -> Arm64_isa.state -> pc:int -> unit
