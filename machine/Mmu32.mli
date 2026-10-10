(* ARM's 32-bit MMU, the short descriptors (plan_pi.md, decision 5): a
 * first-level table of 4096 entries (a fault, a 1MB section, a 16MB
 * supersection, or a coarse second-level table: the legacy fine tables
 * and their 1KB tiny pages, obsolete in ARMv6, are left out) and
 * second levels of large (64KB), small (4KB) and extended small pages; both ARMv6 formats, the legacy one with a permission per
 * quarter page (SCTLR.XP clear: the Pi1's xv6) and the ARMv6/v7 one
 * (XP set: APX, XN); TTBCR's split between TTBR0 and TTBR1; the
 * domains (DACR: no access, client, manager); faults with the FSR's
 * codes. A TLB of 1024 pages in front of the walk, flushed by the
 * CP15 operations that change a translation.
 *
 * With the MMU on, no address a program uses is a place in memory:
 * each is looked up, at every fetch, load and store, in a table the
 * kernel wrote, and the place is what the table says, or a fault.
 * The walk, for a 4 KB page:
 *
 *     the virtual address
 *     31          20 19      12 11         0
 *     |  first: 12  | second: 8 | offset: 12 |
 *            |            |           |
 *     TTBR0  v            |           |
 *      '-> first level    |           |        4096 entries, 16 KB:
 *          [ ...      ]   |           |        one for each MB
 *          [ coarse --]---|--.        |
 *          [ ...      ]   v  v        |
 *          [ section  ]  second level |        256 entries, 1 KB:
 *                        [ ...      ] |        one for each 4 KB
 *                        [ page   --]-|--.
 *                        [ ...      ] v  v
 *                                    the physical address:
 *                                    the page's 20 bits, the offset
 *
 * An entry's two low bits say what it is. In the first level: 0, a
 * fault (nothing is mapped: the kernel is called, and may map
 * something and come back); 1, the address of a second-level table;
 * 2, a section, a whole megabyte mapped by this one entry, the low
 * 20 bits of the address being the offset. A kernel maps itself
 * with sections, a few entries, and its programs with pages.
 *
 * Why two levels: one table of 4 KB pages for 4 GB is a million
 * entries, 4 MB for each process, nearly all for addresses it never
 * uses. With two, a small process has its 16 KB and a 1 KB table
 * for each megabyte it touches. (TTBCR goes further: the addresses
 * above a limit use TTBR1, the kernel's table, the same for all, and
 * a process's own table under TTBR0 can then be smaller than 16 KB.)
 *
 * The rest of an entry is rights: who may read or write the page,
 * the kernel only or programs too (AP), a domain (a number from 0
 * to 15, whose two bits in DACR can switch its pages off, or all
 * their checks off, at once), not executable (XN). [translate]
 * checks them for the access it is given and raises Arm32.Abort,
 * which the board turns into the processor's exception: the
 * kernel's page fault handler, which reads the address and the
 * cause where they are left (FAR and FSR).
 *
 * {b The TLB.} A walk is two loads from memory for each access to
 * memory, so a processor remembers the last translations in a small
 * associative memory, the translation lookaside buffer, and walks
 * only on a miss. Here too: [tags], [pages] and [rights], 1024
 * entries by the low bits of the page's number. The price is the
 * same as on the hardware: the kernel must say when it changes a
 * table (a CP15 write: [flush]), or the old translation stays. A
 * kernel bug of that kind shows here as it would on a Pi, which is
 * what an emulator is for.
 *
 * Where it stands: Board sets Arm32's translate to [translate], so
 * the core's every access comes here once the kernel has set SCTLR's
 * bit 0; Memory, below, knows physical addresses only. The tables
 * walked are the ones the kernels' own code builds (mini-9pi's mmu,
 * xv6's vm), and Mmu64 is the same idea with four levels.
 *
 * cs-history:
 * Virtual memory is Manchester's: the Atlas computer (1962) made a
 * small core memory and a large drum look like one large memory,
 * with pages, a table of them and a fault that fetched a page from
 * the drum, so that a program need not know how much real memory
 * there was. Protection and a separate address space for each
 * process came with the time-sharing systems of the 1960s. ARM had
 * no MMU on its first chips; the tables above are those of the
 * ARMs of the 1990s, kept compatible up to ARMv7 (from memory).
 *
 * others:
 * The 386 cuts 32 bits as 10, 10 and 12: both levels are tables of
 * 1024 entries, 4 KB, a page each, so the tables are allocated as
 * any page is. ARM's 12 and 8 give a 16 KB table and 1 KB ones,
 * which no page allocator hands out as they are: a kernel packs
 * several second-level tables in a page. The MIPS R2000 had no
 * walk in hardware at all: a TLB miss is an exception, and the
 * kernel fills the TLB from tables of whatever shape it likes.
 *
 * References: ARM Architecture Reference Manual (ARM DDI 0100I, ARMv6;
 * ARM DDI 0406, ARMv7-A; from memory), chapter B4 / "Virtual memory
 * system architecture"; ARM1176JZF-S TRM (from memory). *)

type t = {
  mutable sctlr : int;
  mutable ttbr0 : int;
  mutable ttbr1 : int;
  mutable ttbcr : int;
  mutable dacr : int;
  mem : Memory.t;
  tags : int array;
  pages : int array;
  rights : int array;
}

val create : Memory.t -> t

(* the TLB emptied: a TLB invalidation, or a table's register written *)
val flush : t -> unit

val enabled : t -> bool

(* a virtual address to a physical one for an access (bit 0 a write,
 * bit 1 as user; [user]: the CPU in usr mode), or Arm32.Abort (the
 * address, the FSR: the domain in bits 7-4, bit 11 a write) *)
val translate : t -> user:bool -> int -> int -> int
