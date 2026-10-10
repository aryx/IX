(* mini-xv6's memory (xv6's kalloc.c and vm.c): the physical pages, and
 * a process's address space: its bytes [0, sz) through its own
 * translation table (TTBR0), a radix tree whose levels and entries are
 * the board's (Arch: the Pi1's two levels of ARMv6 descriptors, the
 * Pi4's three of ARMv8's). Pages are records (Page.t); only Arch
 * knows the bits.
 *
 * A translation, on the Pi1 (Arch.levels there: [20, 10; 12, 8], a
 * shift and a number of bits for each level). The address 0x00403123
 * is cut in three:
 *
 *     0x00403123 =   4       |    3      |  0x123
 *                 bits 29-20   bits 19-12   bits 11-0
 *
 *     pgdir (TTBR0) ---> +--------+
 *                      0 |        |
 *                      4 | table -+---> +--------+
 *                        |  ...   |   0 |        |
 *                   1023 |        |   3 | page  -+---> +-------+
 *                        +--------+     |  ...   |     |       |
 *                        a page of  255 |        |     | 0x123 | <-
 *                        1024 words     +--------+     +-------+
 *                                                      the page
 *
 * The processor does that walk itself at each access it has no
 * translation for (and keeps the result: the TLB); [walk] in Mmu.ml
 * does it in OCaml, to write the tables and to read what a process
 * points at. An entry that is 0 is no table, or no page: the access
 * faults, and the tree has only the tables its pages need. A
 * process of three pages has here a first table and one second
 * table, 2 pages for 4 GB of possible addresses, where a flat table
 * would be a million entries.
 *
 * The free pages are a list ([kalloc] its head); xv6 threads its
 * list through the free pages themselves, which costs no memory and
 * needs a pointer into any page.
 *
 * A user's address is never dereferenced by the kernel: [read],
 * [copyout] and the others walk the table for each page and refuse
 * what the entry does not give the user. Syscall.mli (mini-xv6's)
 * says what rests on that.
 *
 * cs-history:
 * Paging is the Atlas computer's "one-level store" (Manchester,
 * 1962): pages brought from a drum when touched, so that a program
 * saw one large memory. That it also isolates programs, each with
 * its own table, is what a multi-user system took from it; a table
 * of several levels came when 32 bits of address made a flat one
 * too large.
 *
 * others:
 * Not every processor walks a tree. The MIPS has a TLB only, filled
 * by the kernel at each miss, from any structure it likes; the
 * PowerPC hashed. And not every system isolates by the MMU:
 * mini-singularity runs its processes in one address space and
 * trusts the language, mini-oberon has no processes.
 *
 * modern:
 * A kernel of today maps a file's pages without reading them, copies
 * a page at fork only when one side writes it, takes pages back and
 * writes them to a disk, and uses entries of the upper levels for
 * blocks of 2 MB: all of them tricks on these same entries. xv6
 * leaves them as exercises; mini-9pi does the first (its Fault: a
 * page given at its first touch, a segment shared by several
 * processes), with [map], [unmap] and [mapped] below.
 *
 * References: the xv6 book's "Page tables" (kalloc.c, vm.c; the
 * RISC-V walk is three levels, as the Pi4's). The ARM Architecture
 * Reference Manual, ARMv7-A edition, chapter B3 (the short
 * descriptors, the Pi1's) and the ARMv8-A one, chapter D5 (the
 * Pi4's); chapters from memory. Kilburn, Edwards, Lanigan and
 * Sumner, "One-Level Storage System" (IRE Transactions on
 * Electronic Computers, 1962). *)

val pgsize : int
val pgroundup : int -> int

(* the free physical pages: a zeroed one, or None; one given back; how
 * many *)
val kalloc : unit -> int option
val kfree : int -> unit
val nfree : unit -> int

(* A space is its first-level table's physical address (a pgdir). *)

(* a new one, empty; or None *)
val create : unit -> int option

(* claude: whether a page is mapped at [va] (mini-9pi's page faults);
 * the page there *)
val mapped : int -> int -> bool
val lookup : int -> int -> Page.t option

(* claude: mini-9pi's, whose pages belong to its segments (shared by
 * processes): [map pgdir va pa] a page mapped there (the user's, to
 * write; false: no page for a table), [unmap pgdir va] one unmapped but
 * not freed, [free_tables pgdir] a space's tables freed, not its pages *)
val map : int -> int -> int -> bool
val unmap : int -> int -> unit
val free_tables : int -> unit

(* [alloc pgdir oldsz newsz]: [oldsz, newsz) given fresh zeroed pages
 * (uvmalloc): the new size, or None (past the user's addresses, or no
 * page left: what it added freed) *)
val alloc : int -> int -> int -> int option

(* [dealloc pgdir oldsz newsz]: the pages from newsz up freed
 * (deallocuvm): the new size *)
val dealloc : int -> int -> int -> int

(* the page at [va] made the kernel's: exec's guard page (clearpteu) *)
val guard : int -> int -> unit

(* every page and table of a space, then the space (freevm) *)
val free : int -> unit

(* [copy pgdir sz]: [0, sz) copied into a new space (copyuvm), or None *)
val copy : int -> int -> int option

(* [copy_range pgdir dst lo hi]: the pages of [lo, hi) mapped in pgdir
 * copied into the space dst (false: no page left, dst to be freed) *)
val copy_range : int -> int -> int -> int -> bool

(* a process's bytes, through its table (xv6-riscv's copyin, copyout,
 * copyinstr: the user's pages only, the guard page refused).
 * [read_prefix]: the bytes before the first page out of reach, [n] at
 * most; [read]: all [n] or None; [room]: how many of [n] the user can
 * write; [copyout]: all of [s] (true), or up to the first page out of
 * reach; [read_string]: a string, its NUL within [max] bytes; [write]:
 * any page mapped (exec loading a program) *)
val read_prefix : int -> int -> int -> string
val read : int -> int -> int -> string option
val room : int -> int -> int -> int
val copyout : int -> int -> string -> bool
val read_string : int -> int -> int -> string option
val write : int -> int -> string -> bool
