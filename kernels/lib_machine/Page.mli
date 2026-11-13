(* A page of a process: its physical address, and who may use it (only
 * the kernel may use the guard page below a stack). Each board's Arch
 * encodes a page in its page table entries, and Mmu makes and walks the
 * tables. *)

type perm = Kernel_rw | User_ro | User_rw

type t = { pa : int; perm : perm }
