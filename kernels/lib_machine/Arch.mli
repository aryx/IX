(* The machine's part of mini-xv6: what differs between the boards,
 * with one implementation for each board (pi1/Arch.ml for the Pi1's
 * ARMv6, arm32; pi4/Arch.ml for the Pi4's ARMv8, arm64). The rest of
 * the kernel is written once, against this interface. The C and
 * assembly under it are each board's too (machine.c, start.s and
 * board.h in pi1/ and pi4/, for the boot, the traps and the devices),
 * and what they give OCaml has the same names on both (Machine.mli).
 *
 * What does not differ is not here: xv6's semantics (there is one,
 * xv6-riscv's: plan_kernel.md), the file system's format (the block
 * size is read from the disk: Fs), and the trap frame's first
 * registers (r0/x0 is the result, r1/x1 exec's argv).
 *
 * Here are the two side by side, with the values of the names below:
 *
 *                      pi1 (ARMv6, arm32)      pi4 (ARMv8, arm64)
 *     word             4 bytes                 8
 *     user_limit       1 GB (OCaml's max_int)  2^39
 *     levels           20,10; 12,8             30,9; 21,9; 12,9
 *                      1024 then 256 entries   512, 512, 512
 *     entry_bytes      4                       8
 *     a table's entry  address | 1             address | 3
 *     tf_pc, sp, lr    15, 13, 14              32, 31, 30
 *     tf_syscall       0 (r0)                  7 (x7)
 *     args_on_stack    true                    false
 *     elf_class        1                       2
 *
 * This interface has no implementation of its name beside it. The
 * build links pi1's Arch.ml or pi4's, as a C kernel compiles one
 * directory of its arch/ and not the others. Mmu walks any tree that
 * [levels] describes, and Syscall fetches an argument one way or the
 * other according to [args_on_stack], so neither of them names a
 * board.
 *
 * design:
 * The interface was found, not designed. mini-xv6 was written for the
 * Pi1 and then ported to the Pi4, and what had to change is what is
 * here. It is small because both are ARM boards with the same devices.
 * A port to another family (RISC-V, x86) would move more of Machine's
 * C here, and would not change the kernel above.
 *
 * cs-history:
 * Splitting a kernel into a portable half and a machine-dependent half
 * is also Unix's discovery. Unix, written in C from 1973, was moved to
 * the Interdata 8/32 in 1977-1978 (and to the 7/32 at Wollongong, in
 * 1977). That was among the first times a system outlived its machine,
 * and the work was mostly finding which lines had assumed the PDP-11.
 * xv6 itself runs on one machine at a time (x86, then RISC-V), and its
 * ports are forks; xv6-multiarch gathers them, and this module answers
 * the same need in one kernel.
 *
 * others:
 * Linux's arch/, and Plan 9's directory for each machine (pc, bcm,
 * ...) with a port/ for the rest, make the same cut, far wider: there
 * the devices, the interrupts' controller and the boot belong to the
 * machine too. mini-9pi uses this Arch for its two boards.
 *
 * References: Johnson and Ritchie, "Portability of C Programs and
 * the UNIX System" (Bell System Technical Journal, 1978), on the port
 * to the Interdata and what it found. plan_kernel.md, on the Pi4's
 * port. *)

(* the board's name: "pi1" or "pi4" *)
val name : string

(*****************************************************************************)
(* Memory *)
(*****************************************************************************)

(* the size of a user's word and pointer, 4 or 8 bytes; [get_word]
 * reads a word of the user's memory, little-endian, as an int (on the
 * Pi1, by Machine.get_le32's rule: a word of 1GB and up is max_int) *)
val word : int
val get_word : string -> int -> int
val word_bytes : int -> string

(* a register's value as C's int (its low 32 bits, signed), and a sum
 * as C's uint (32 bits, wrapping). Both are identities on the Pi1,
 * whose words are already OCaml's ints. *)
val c_int : int -> int
val c_uint : int -> int

(* the user's addresses are [0, user_limit) *)
val user_limit : int

(* the physical pages the kernel gives the processes: [lo, hi) *)
val pages : int * int

(* a process's translation table. [levels] lists its levels, the top
 * one first, each as an index's shift and its number of bits; an entry
 * is a word of [entry_bytes]. An entry of an upper level holds a next
 * table (its physical address) or none, and an entry of the last level
 * holds a page or none. *)
val levels : (int * int) list
val entry_bytes : int
val get_entry : int -> int
val set_entry : int -> int -> unit
val encode_table : int option -> int
val decode_table : int -> int option
val encode_page : Page.t option -> int
val decode_page : int -> Page.t option

(*****************************************************************************)
(* The trap frame, the calling convention *)
(*****************************************************************************)

(* the indexes of the trap frame's words (for Machine.tf_get): the pc,
 * the user's sp, the link register (where the running function
 * returns: r14, x30), and the system call's number *)
val tf_pc : int
val tf_sp : int
val tf_lr : int
val tf_syscall : int

(* where a system call's arguments are: on the user's stack on the Pi1
 * (xv6 arm-pi1's usys.S pushes r0-r3, so argument n is at sp + 4n), or
 * in the trap frame's first registers on the Pi4 (x0-x5) *)
val args_on_stack : bool

(* the programs' ELF class: 1 (ELF32) or 2 (ELF64) *)
val elf_class : int
