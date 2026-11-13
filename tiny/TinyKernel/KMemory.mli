(* Tiny memory: how tiny-kernel gives a process its memory. By default
 * the memory is a partition: one block of the machine's memory, whose
 * size the program chose (its a.out says it; see tiny-ld -a). The
 * block is found first-fit when the program starts, and it never grows.
 * This is the part of the kernel that is about memory, as KFS is the
 * part about the disk (plan_tiny_memory.md).
 *
 * The machine does the rest with two numbers, its window. In user
 * mode, every address is added to the block's start (base) and must
 * stay below its size (bound), or the process faults. So a program is
 * linked at 0, runs anywhere, and reaches nothing but its own block:
 *
 *     0x2000000                                              0xfff0000
 *     | sh, 1 MB | rc, 1 MB | ml, 32 MB    |  free  | ld, 48 MB | free |
 *                ^ base                                (first fit: the
 *     rc's address 0x100 is 0x2100000 + 0x100          first gap big
 *     in the machine; 0x100000 and above fault          enough, starting
 *                                                       from the bottom)
 *
 * fork asks for a block of the parent's size and copies the parent's
 * whole block into it ([mem_copy]). exec asks for a block of the new
 * program's size (keeping the same block when the size is the same),
 * writes the program's image at its address 0, and the arguments at
 * its top. spawn does what exec does, in a new process. A block is
 * released ([mem_release]) as soon as its process ends; the parent's
 * wait needs only a small record of the status (KProcs.ended).
 *
 * Segments are chosen at boot, when /boot/memory says segments (the
 * Makefile's MEMORY=segments). They split a process in two, its text
 * and its data, at the address where tiny-ld -n put the data (a page
 * after the text). The machine's second window (tbase, tbound) maps
 * the text and faults on a store there; the data is a block as above:
 *
 *     a process's addresses         the machine's memory
 *     0       text  (read only) --> ml's text: one block shared by
 *     tsize                         all running ml's (see texts, users)
 *             data, heap, stack --> this ml's own block, of size
 *     memory                        memory - tsize
 *
 * When a text from the same unchanged file is already running (the
 * file is identified by a key and a stamp, which the kernel computes),
 * exec shares it and writes only the data. fork shares the text and
 * copies the data. When a file is written, its texts are forgotten
 * ([mem_forget]), so the next exec loads it again. If the kernel writes
 * a word in a text (a tracer's breakpoint), the process gets its own
 * copy of the text. A process without a text (with partitions) runs
 * with the first window alone: kentry.s sets up the machine's split
 * only when tbound is not 0. The split's arithmetic costs 2% of the
 * host's instructions in tiny-kernel's toolchain session, and cost 7%
 * when every process paid for it.
 *
 * Pages (when /boot/memory says pages; MEMORY=pages) are stage 4 of
 * plan_tiny_memory.md, off by default. A process's memory is made of
 * 4 KB pages, each in any frame of the machine's memory, found through
 * the process's page tables (in Sv32, a root table, then a table for
 * each 4 MB, with an entry for each page):
 *
 *     a process's addresses     its tables          the frames
 *     0      text (R X)  -----> root -> table ---> anywhere above 32 MB;
 *            data (R W X)                          the free ones are
 *            ... untouched: no entry, no frame     linked in a list (as
 *            stack, arguments                      xv6's kalloc), and each
 *     memory                                       has a byte of users
 *
 * exec gives the process a root table and the pages that the image
 * and the arguments are written to. Any other page is given, zeroed,
 * at its first touch: [mem_fault] answers the fault and the
 * instruction runs again. fork shares every page, and the writable
 * ones become read-only and copy-on-write in both processes: the first
 * one to write gets a copy, or gets the page back writable if it is
 * the last user. The kernel writes a process's page only after making
 * the page the process's own ([mem_writable], and [mem_store] for a
 * breakpoint). It reaches a buffer one page at a time ([mem_pieces],
 * and KCalls's bounce buffer for read and write).
 *
 * The machine translates only user-mode addresses (satp's user-only
 * bit); the kernel's addresses stay physical. Translations are cached,
 * and the cache is emptied at each run (k_window writes satp). A
 * process's tables are changed by one core while the process is not
 * running, so no other core has them cached, and no TLB shootdown is
 * needed.
 *
 * Not done with pages:
 * - texts shared between execs (segments have them; pages would need a
 *   cache of a file's pages);
 * - a guard page under the stack (where a program's stack ends is up
 *   to its runtime, mlsys.c);
 * - swapping.
 *
 * kept:
 * The limits of partitions:
 * - A partition's size is a guess made when the program is linked
 *   (ld's 32 MB was too small to link bin/ml, so it is 48 MB now).
 * - The block is not zeroed: exec writes only the image, because
 *   zeroing ml's 32 MB cost 35 million instructions per exec.
 * - There is no swapping, so a fork or an exec with no room waits
 *   (KCalls's with_room).
 *
 * context:
 * The kernel calls this module for every access to a process's
 * memory: KProcs's [user] uses [mem_address] for a word or a byte of a
 * system call, its [user_iter] uses [mem_pieces] for a buffer, and
 * [mem_writable] is checked before a write. kentry.s sets core 0's window,
 * through [mem_window]; a core given a process
 * receives the window in its mailbox ([mem_post],
 * plan_tiny_multicore.md). The other kernel on the same machine, t6
 * (steps/), uses fixed partitions of 1 MB.
 *
 * cs-history:
 * Partitions are how IBM's OS/360 (1966) shared a machine between
 * jobs. Its MFT cut memory into a fixed number of partitions, set by
 * the operator; its MVT cut a region of the size each job asked for,
 * as this kernel does with an a.out's size, and met external
 * fragmentation: the free memory is in holes too small for the next
 * job. The 360 had no relocation at run time (the loader relocated a
 * program once, as it loaded it) and protected memory by keys, one
 * for each 2 KB. A base and a bound register, which make up
 * tiny-machine's window, are the CDC 6600's RA and FL (1964): every
 * address is added to RA and checked against FL. Knuth's first volume
 * (1968) weighs first fit against best fit, with the fifty-percent
 * rule: in a steady state there are about half as many holes as blocks
 * in use. Denning's
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
 * Segments came in between: they cut memory along the program's parts
 * rather than by process. The Burroughs B5000 (1961) gave each array
 * and procedure a descriptor. The PDP-11's memory management (the
 * 11/40's and 11/45's) mapped a program's 64 KB in eight segments
 * that DEC called pages; the 11/45 had a second set for instructions,
 * and Unix's a.out said which a program wanted. 0407 asked for one
 * block, 0410 for a text that is read-only and shared by all its runs,
 * and 0411 for instructions and data in two spaces. Intel's 8086
 * (1978) had four segment registers (code, data, stack, extra) and no
 * protection: an address was the segment times 16 plus the offset.
 * The 80286 (1982) made a segment a descriptor (base, limit, rights)
 * in a table. The 80386 (1985) put pages under the segments, and Unix,
 * then Windows NT, set every segment to base 0 and limit 4 GB (the
 * flat model), so that pages alone did the work. AMD64 (2003) kept
 * only the bases of FS and GS, for each thread's data. Multics (1969)
 * had both: a file was a segment, mapped into memory, and its segments
 * were paged.
 *
 * terminology:
 * A partition (OS/360's) is set in advance; MVT called its variable
 * ones regions. A segment is a part of an address space with its own
 * base and limit (code, data, stack); ELF's segments are only the
 * parts of a file to load, and its .text is a section. A page is a
 * piece of fixed size of the address space (4 KB in Sv32), and a frame
 * is the memory under it. Virtual memory is the whole idea (the
 * addresses a program uses are not the memory's); paging is one way to
 * do it, and swapping is another (whole processes go to the disk, as
 * in Unix V7). And
 * core was memory before it was a processor: magnetic cores, hence a
 * core dump.
 *
 * references:
 *  - P. Denning, "Virtual Memory" (Computing Surveys 1970): partitions,
 *    relocation, then pages
 *  - D. Knuth, The Art of Computer Programming, vol. 1 (1968), 2.5:
 *    first fit, best fit, the fifty-percent rule
 *  - T. Kilburn et al., "One-Level Storage System" (IRE Transactions
 *    on Electronic Computers, 1962): Atlas's pages
 *)

(* The processes' memory goes from mem_low to mem_high. A partition's
 * size is a multiple of [part] (a megabyte). *)
val part : int
val mem_low : int
val mem_high : int

(* A space holds nothing at first ([mem_empty]), then a block, plus a
 * text with segments. *)
type space

(* [mem_address] returns -1 for no address rather than an option,
 * because it is called at each read and write, and so allocates
 * nothing. *)
type vaddr = int
type kaddr = int

(* No block of the size asked for is free now. *)
exception No_room

val mem_empty : unit -> space
val mem_release : space -> unit

(* Segments or pages instead of partitions; set once, at boot. *)
val segments : bool ref
val pages : bool ref

(* Text_shared means that, with segments, a running copy of the program
 * already has the text. *)
type text_state = Text_new | Text_shared

(* [mem_load sp key stamp tsize isize size] replaces sp's memory with
 * size bytes for a program whose image is isize bytes, of which the
 * first tsize are the text (0 for none; tsize is ignored with
 * partitions). With segments, a running text of the same key and stamp
 * is shared, and only the data from tsize on is written. On No_room, sp
 * is unchanged. *)
val mem_load : space -> string -> string -> int -> int -> int -> text_state

(* [mem_forget key] says that the file is being written, so the next
 * exec of it must not share its running texts. *)
val mem_forget : string -> unit

(* [mem_copy dst src], for fork, copies src's data and shares its text.
 * With pages, every page is shared, copy-on-write. *)
val mem_copy : space -> space -> unit

(* [mem_fault sp va] gives a zeroed page if va's page is untouched, or
 * copies a page shared by a fork, and returns true. It returns false
 * when the process must die (always, without pages). *)
val mem_fault : space -> vaddr -> bool

(* [mem_address sp va n] is the kernel's address of the n bytes at va.
 * It is -1 if they are not all the process's, or (with pages) not in
 * one piece. A byte or an aligned word is always in one piece. *)
val mem_address : space -> vaddr -> int -> kaddr

(* [mem_pieces sp va n] gives the pieces (address, length) that hold the
 * n bytes at va, in order, or None if they are not all the process's.
 * There is one piece with partitions, two with segments when the bytes
 * cross from text to data, and one per page with pages. KProcs's
 * user_iter goes through them. *)
val mem_pieces : space -> vaddr -> int -> (kaddr * int) list option

(* [mem_writable sp va n] says whether the bytes are outside the
 * text. *)
val mem_writable : space -> vaddr -> int -> bool

(* The caller has checked va with [mem_address]. A word or a byte
 * stored in the text gives sp its own copy of it (may raise No_room).
 * mem_write and mem_blit are used by the loader, and they write in the
 * text too. *)
val mem_fetch : space -> vaddr -> int
val mem_store : space -> vaddr -> int -> unit
val mem_store_byte : space -> vaddr -> int -> unit
val mem_write : space -> vaddr -> string -> unit
val mem_blit : space -> vaddr -> kaddr -> int -> unit

(* [mem_window sp] sets core 0's windows (data and text) to run sp.
 * [mem_post sp m] sets another core's, through its mailbox at m (m and
 * m + 4 for the data, m + 20 and m + 24 for the text). *)
val mem_window : space -> unit
val mem_post : space -> kaddr -> unit
