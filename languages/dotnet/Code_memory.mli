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
 * The code is then called as mini-ml calls any closure (Gen: the
 * closure in R0, its argument in R1, field 0 its code): a block of
 * two fields, the code's address in both, is a closure.
 *
 * others:
 * The simplest JIT maps memory both writable and executable (mmap's
 * PROT_WRITE|PROT_EXEC), which SELinux and OpenBSD refuse; mprotect
 * between the writing and the running is the usual way; .NET (since 7)
 * maps the same memory twice, one view writable and one executable,
 * by memfd_create too. On Plan 9 the memory of the process runs
 * (no execute bit on arm), and segflush(2) cleans the caches: Inferno's
 * JIT did so, the way mini-9pi will. *)

(* whether code can be run here: mini-ml's build, Linux, arm64 *)
val available : bool

(* the code's bytes made executable: their address *)
val load : string -> int

(* a closure of mini-ml's whose code is at an address *)
val closure : int -> Obj.t

(* the address of a block (a static closure: it does not move) *)
val address : Obj.t -> int

(* raised by divide_by_zero, which the JIT's code calls *)
exception Divide_by_zero
val divide_by_zero : unit -> unit
