(* Tiny memory: how tiny-kernel gives a process its memory, a
 * partition: one block of the machine's memory, its size the program's
 * (its a.out says it: tiny-linker -a), found first-fit when the program
 * starts, never grown. TinyKernel.ml's part that is about memory, as
 * TinyKernelFS.ml is its part about the disk (plan_tiny_memory.md).
 *
 * The machine does the rest with two numbers, its window: in user mode
 * every address is added to the block's start (base) and must stay
 * below its size (bound), or the process faults. So a program is
 * linked at 0 and runs anywhere, and reaches nothing but its block:
 *
 *     0x2000000                                              0xfff0000
 *     | sh, 1 MB | rc, 1 MB | ml, 32 MB    |  free  | ld, 48 MB | free |
 *                ^ base                                (first fit: the
 *     rc's address 0x100 is 0x2100000 + 0x100          first gap big
 *     in the machine; 0x100000 and above fault          enough, from the
 *                                                       bottom)
 *
 * fork asks a block of the parent's size and copies the parent's into
 * it, whole ([mem_copy]); exec asks one of the new program's size (the
 * same block when the size is the same) and writes the program's
 * image at its 0 and the arguments at its top; spawn does exec's in a
 * new process. A block is let go when the kernel lets the process go
 * ([mem_release]): a zombie keeps its block until its parent's wait.
 *
 * Where it stands: TinyKernel.ml calls it for every process's memory
 * (its [user] for a word or a byte of a system call's, [mem_address];
 * its [user_iter] for a buffer, [mem_pieces]); entry.tm
 * sets core 0's window ([mem_window]), and a core given a process gets
 * its window in its mailbox ([mem_post]: plan_tiny_multicore.md). The
 * other kernels on the same machine: t6 (steps/), fixed partitions of
 * 1 MB; v6, removed, pages (tiny-machine's Sv32, which no kernel uses
 * now).
 *
 * What is ours: the block's size is a guess made when the program is
 * linked (ld's 32 MB was too small for bin/ml's link: 48 now); the
 * block is not zeroed (exec writes the image only: zeroing ml's 32 MB
 * cost 35 million instructions an exec); there is no swapping, so a
 * fork or an exec with no room waits (TinyKernel.ml's with_room).
 * Segments and pages, the two answers to those costs, are this
 * module's next sections (plan_tiny_memory.md's stages 3 and 4), each
 * behind the same few functions.
 *
 * cs-history:
 * Partitions are how IBM's OS/360 (1966) shared a machine between
 * jobs. Its MFT cut memory into a fixed number of partitions, set by
 * the operator; its MVT cut a region of the size each job asked for,
 * as this kernel does with an a.out's size, and met external
 * fragmentation: the free memory in holes too small for the next job.
 * The 360 had no relocation at run time (the loader relocated a
 * program once, as it loaded it) and protected memory by keys, one
 * for each 2 KB. A base and a bound register, tiny-machine's window,
 * are the CDC 6600's RA and FL (1964): every address added to RA and
 * checked against FL. Knuth's first volume (1968) weighs first fit
 * against best fit, with the fifty-percent rule: in a steady state
 * there are about half as many holes as blocks in use. Denning's
 * survey "Virtual Memory" (1970) presents partitions and relocation
 * as the step before pages, the order in which this kernel takes them.
 *
 * cs-history:
 * Pages are in fact older: Manchester's Atlas (1962) had a "one-level
 * store", pages of 512 words that the supervisor moved between core
 * and drum, unseen by the program. IBM's 360 Model 67 (1967)
 * translated addresses for TSS/360 and CP-67, and the 370 brought
 * virtual storage to all its systems (1972). Unix got demand paging
 * on the VAX, in Berkeley's 3BSD (1979, Babaoglu and Joy). Pages
 * answer the three troubles of partitions that this kernel shows: no
 * fragmentation (any free frame will do), memory given when touched
 * rather than reserved, and a fork that copies a page only when one
 * side writes it (copy-on-write).
 *
 * evolution:
 * Segments came in between: memory cut along the program's parts
 * rather than by process. The Burroughs B5000 (1961) gave each array
 * and procedure a descriptor. The PDP-11's memory management (the
 * 11/40's and 11/45's) mapped a program's 64 KB in eight segments
 * that DEC called pages; the 11/45 had a second set for instructions,
 * and Unix's a.out said which a program wanted: 0407 one block, 0410
 * its text read-only and shared by all its runs, 0411 instructions
 * and data in two spaces. Intel's 8086 (1978) had four segment
 * registers (code, data, stack, extra) and no protection: an address
 * was the segment times 16 plus the offset. The 80286 (1982) made a
 * segment a descriptor (base, limit, rights) in a table; the 80386
 * (1985) put pages under the segments, and Unix, then Windows NT, set
 * every segment to base 0 and limit 4 GB (the flat model), pages
 * alone doing the work; AMD64 (2003) kept only FS's and GS's bases,
 * for each thread's data. Multics (1969) had both: a file was a
 * segment, mapped, and its segments were paged.
 *
 * terminology:
 * A partition (OS/360's) is set in advance; MVT called its variable
 * ones regions. A segment is a part of an address space with its own
 * base and limit (code, data, stack); ELF's segments are only the
 * parts of a file to load, and its .text a section. A page is a piece
 * of fixed size of the address space (4 KB in Sv32), the frame the
 * memory under it. Virtual memory is the whole idea (the addresses a
 * program uses are not the memory's), paging one way to do it,
 * swapping another (whole processes to the disk, as Unix V7 did). And
 * core was memory before it was a processor: magnetic cores, hence a
 * core dump.
 *
 * References:
 *  - P. Denning, "Virtual Memory" (Computing Surveys 1970): partitions,
 *    relocation, then pages
 *  - D. Knuth, The Art of Computer Programming, vol. 1 (1968), 2.5:
 *    first fit, best fit, the fifty-percent rule
 *  - T. Kilburn et al., "One-Level Storage System" (IRE Transactions
 *    on Electronic Computers, 1962): Atlas's pages
 *)

(* the processes' memory, from mem_low to mem_high; a partition's size
 * is a multiple of [part] (a megabyte) *)
val part : int
val mem_low : int
val mem_high : int

(* a process's memory: none at first ([mem_empty]), then a block *)
type space = { sid : int; mutable sbase : int; mutable ssize : int }

(* no block of the size asked for is free now *)
exception No_room

val mem_empty : unit -> space
val mem_size : space -> int

(* [mem_place sp size]: sp given a block of size bytes, its old one let
 * go (kept when it has that size already); No_room, sp as it was *)
val mem_place : space -> int -> unit
val mem_release : space -> unit

(* [mem_copy dst src]: dst a block of src's size, src's bytes (fork) *)
val mem_copy : space -> space -> unit

(* [mem_address sp va n]: the kernel's address of the n bytes at the
 * process's va, -1 if they are not all the process's, or (with pages)
 * not in one piece; a word or a byte is (an aligned word is in one
 * page) *)
val mem_address : space -> int -> int -> int

(* [mem_pieces sp va n]: the n bytes at va as the pieces of the
 * machine's memory that hold them, in order, (the kernel's address, the
 * length) each; None if they are not all the process's. One piece for
 * a partition; with pages, a piece a page (the frames are anywhere):
 * for a buffer, the kernel goes by them (TinyKernel.ml's user_iter) *)
val mem_pieces : space -> int -> int -> (int * int) list option

(* a word read at va; a word, a byte, a string written at va; [mem_blit
 * sp va a n] the kernel's n bytes at a written at va. va is checked by
 * the caller ([mem_address]) *)
val mem_fetch : space -> int -> int
val mem_store : space -> int -> int -> unit
val mem_store_byte : space -> int -> int -> unit
val mem_write : space -> int -> string -> unit
val mem_blit : space -> int -> int -> int -> unit

(* the machine set to run a process in sp: core 0's window
 * ([mem_window]), or another core's, two words of its mailbox at m
 * ([mem_post sp m]) *)
val mem_window : space -> unit
val mem_post : space -> int -> unit
