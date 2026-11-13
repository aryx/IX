(* mini-xv6's memory (xv6's kalloc.c and vm.c): the physical pages, and
 * a process's address space. A process sees its bytes [0, sz) through
 * its own translation table (TTBR0), a radix tree whose levels and
 * entries are the board's (Arch: the Pi1 has two levels of ARMv6
 * descriptors, the Pi4 three of ARMv8's). Pages are records (Page.t),
 * and only Arch knows their bits.
 *
 * Here is a translation on the Pi1, where Arch.levels is [20, 10; 12,
 * 8], a shift and a number of bits for each level. The address
 * 0x00403123 is cut in three:
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
 * translation for (and keeps the result, in the TLB). [walk] in Mmu.ml
 * does it in OCaml, to write the tables and to read what a process
 * points at. An entry that is 0 means no table, or no page: the access
 * faults, so the tree has only the tables its pages need. A process of
 * three pages has here a first table and one second table: 2 pages for
 * 4 GB of possible addresses, where a flat table would have a million
 * entries.
 *
 * The free pages are a list, and [kalloc] takes its head. xv6 threads
 * its list through the free pages themselves, which costs no memory
 * but needs a pointer into any page.
 *
 * The kernel never dereferences a user's address: [read], [copyout]
 * and the others walk the table for each page, and refuse what the
 * entry does not give the user. mini-xv6's Syscall.mli says what rests
 * on that.
 *
 * cs-history:
 * Paging is the Atlas computer's "one-level store" (Manchester, 1962):
 * pages were brought from a drum when touched, so that a program saw
 * one large memory. That paging also isolates programs, each with its
 * own table, is what multi-user systems took from it. Tables of
 * several levels came when 32 bits of address made a flat table too
 * large.
 *
 * others:
 * Not every processor walks a tree. The MIPS has only a TLB, which the
 * kernel fills at each miss, from any structure it likes, and the
 * PowerPC used a hash table. And not every system isolates by the MMU:
 * mini-singularity runs its processes in one address space and trusts
 * the language, and mini-oberon has no processes.
 *
 * modern:
 * A kernel of today maps a file's pages without reading them, copies a
 * page at fork only when one side writes it, takes pages back and
 * writes them to a disk, and uses entries of the upper levels for
 * blocks of 2 MB. All of them are tricks on these same entries. xv6
 * leaves them as exercises. mini-9pi does the first two, in its Fault
 * (a page is given at its first touch, a segment is shared by several
 * processes, and a page is shared after a fork until it is written),
 * with [map], [map_ro], [unmap] and [mapped] below.
 *
 * References: the xv6 book's "Page tables" (kalloc.c, vm.c; the
 * RISC-V walk has three levels, as the Pi4's has). The ARM
 * Architecture Reference Manual, ARMv7-A edition, chapter B3 (the
 * short descriptors, which the Pi1 uses), and the ARMv8-A edition, "The
 * AArch64 Virtual Memory System Architecture" (for the Pi4). Kilburn,
 * Edwards, Lanigan and Sumner, "One-Level Storage System" (IRE
 * Transactions on Electronic Computers, 1962). *)

val pgsize : int
val pgroundup : int -> int

(* the free physical pages: [kalloc] takes a zeroed one, or returns
 * None; [kfree] gives one back; [nfree] says how many there are *)
val kalloc : unit -> int option
val kfree : int -> unit
val nfree : unit -> int
(* takes [n] pages that follow each other in memory, not zeroed, at
 * once (at the boot, when the free pages are still in order), or
 * returns None *)
val kalloc_run : int -> int option

(* A space is the physical address of its first-level table (a
 * pgdir). *)

(* makes a new, empty space, or returns None *)
val create : unit -> int option

(* [mapped] says whether a page is mapped at [va] (for mini-9pi's page
 * faults), and [lookup] gives the page there *)
val mapped : int -> int -> bool
val lookup : int -> int -> Page.t option

(* for mini-9pi, whose pages belong to its segments (and are shared by
 * processes). [map pgdir va pa] maps a page there, for the user to
 * write; it returns false when there is no page for a table. [unmap
 * pgdir va] unmaps one page but does not free it. [free_tables pgdir]
 * frees a space's tables, but not its pages. *)
val map : int -> int -> int -> bool
(* [map_ro pgdir va pa] is the same, but the user may only read the
 * page (a page shared after a fork until one side writes it) *)
val map_ro : int -> int -> int -> bool
val unmap : int -> int -> unit
val free_tables : int -> unit

(* [alloc pgdir oldsz newsz] gives [oldsz, newsz) fresh zeroed pages
 * (uvmalloc). It returns the new size, or None when the range is past
 * the user's addresses or no page is left (what it added is then
 * freed). *)
val alloc : int -> int -> int -> int option

(* [dealloc pgdir oldsz newsz] frees the pages from newsz up
 * (deallocuvm), and returns the new size *)
val dealloc : int -> int -> int -> int

(* makes the page at [va] the kernel's: exec's guard page (clearpteu) *)
val guard : int -> int -> unit

(* frees every page and table of a space, then the space (freevm) *)
val free : int -> unit

(* [copy pgdir sz] copies [0, sz) into a new space (copyuvm), or
 * returns None *)
val copy : int -> int -> int option

(* [copy_range pgdir dst lo hi] copies the pages of [lo, hi) mapped in
 * pgdir into the space dst. It returns false when no page is left, and
 * dst must then be freed. *)
val copy_range : int -> int -> int -> int -> bool

(* a process's bytes, through its table (xv6-riscv's copyin, copyout
 * and copyinstr: only the user's pages, with the guard page refused).
 * - [read_prefix] reads the bytes before the first page out of reach,
 *   [n] at most;
 * - [read] reads all [n] bytes, or returns None;
 * - [room] says how many of [n] bytes the user can write;
 * - [copyout] writes all of [s] (and returns true), or up to the first
 *   page out of reach;
 * - [read_string] reads a string whose NUL is within [max] bytes;
 * - [write] writes to any page mapped (when exec loads a program). *)
val read_prefix : int -> int -> int -> string
val read : int -> int -> int -> string option
val room : int -> int -> int -> int
val copyout : int -> int -> string -> bool
val read_string : int -> int -> int -> string option
val write : int -> int -> string -> bool
