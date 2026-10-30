(* The JIT's memory: code written, then run (plan_dotnet.md, decision
 * 12). Two files of the same interface: this directory's, for dune's
 * build (ocamlopt's conventions are not mini-ml's: no JIT, the
 * interpreter alone), and mini-ml/'s, which the mkfile compiles.
 *
 * On Linux, mini-ml's on arm64, by three system calls and no C: the
 * code written to a file of memory (memfd_create, write), the file
 * mapped readable and executable (mmap). So no page is ever both
 * writable and executable (W^X), and the kernel makes the instruction
 * cache see the bytes as it maps them, which is the step a JIT on arm
 * must not forget:
 *
 *     the code's bytes --write--> memfd --mmap(PROT_READ|PROT_EXEC)--> run
 *
 * On Plan 9 (mini-9pi; mini-5i's Plan 9), mini-ml's on arm: a segment
 * attached (segattach, class "memory": zeros), the bytes put there by
 * a read from a pipe they were written to (ML writes no memory but its
 * values'; the kernel writes where a read is asked to), then segflush,
 * the bytes in memory and the instructions' cache emptied of what was
 * there. The memory of a Plan 9 process runs, arm having no right to
 * run apart from reading; the cells, a segment too, through the pipe.
 *
 *     the code's bytes --pwrite--> pipe --pread--> segment --segflush--> run
 *
 * The code is then called as mini-ml calls any closure (Gen: the
 * closure in R0, its argument in R1, field 0 its code): a block of
 * two fields, the code's address in both, is a closure.
 *
 * others:
 * The simplest JIT maps memory both writable and executable (mmap's
 * PROT_WRITE|PROT_EXEC), which SELinux and OpenBSD refuse; mprotect
 * between the writing and the running is the usual way; .NET (since 7)
 * maps the same memory twice, one view writable and one executable,
 * by memfd_create too. Inferno's JIT, on Plan 9, wrote its code in its
 * heap and called segflush, as here. *)

(* whether code can be run here: mini-ml's build, Linux on arm64 or
 * Plan 9 *)
val available : bool

(* the code's bytes made executable: their address *)
val load : string -> int

(* words the code reads and ML writes (the methods' cells): their
 * first values, their address, and a word's writer (its index, its
 * value). Mapped readable only, as the code: a word is written through
 * the file (pwrite), not the memory *)
val cells : int array -> int * (int -> int -> unit)

(* a closure of mini-ml's whose code is at an address *)
val closure : int -> Obj.t

(* the address of a block (a static closure: it does not move) *)
val address : Obj.t -> int
