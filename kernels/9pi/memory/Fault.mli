(* Segments and page faults (principia's segment.c and fault.c, as far
 * as mini-9pi needs them). A segment's pages are its own (it keeps a
 * table of them), and they are given at their first touch. For text
 * and data they come from the program's file (read through its
 * channel: devmnt's Tread, or devroot's bytes); for bss and stack they
 * are zeros. A process's table maps a segment's pages as the process
 * touches them, so that a segment may be shared (text always, data and
 * bss with rfork's RFMEM): a fault maps the page another sharer made.
 * The system calls fault a user's buffer in before using it
 * (validaddr).
 *
 * There are three tables, each the cache of the one before:
 *
 *     the program's file     where a text or data page's bytes are
 *            |  read once, at the page's first touch
 *     segment.pages          address -> physical page: what the
 *            |               segment has, for all who share it
 *            |  mapped as each process touches it
 *     the process's table    address -> physical page: what the MMU
 *     (pgdir: Mmu)           looks at, at each access of the program
 *
 * Here is a program's first instruction, after an exec that read 32
 * bytes:
 *
 *     the pc is 0x1020; the MMU finds nothing there: a trap
 *     Main.fault -> Fault.fault p 0x1020
 *       the segment holding it: Text, [0x1000, t)
 *       its page is 0x1000; the segment has none yet:
 *         a free page of memory (Mmu.kalloc)
 *         4096 bytes of the file, from offset 0, written in it
 *         noted in the segment; mapped in the process's table
 *     back to the program: the same instruction, again, and it runs
 *
 * The same trap for an address in no segment is the program's error,
 * and its end: the note "sys: trap: fault read va=0x35" is a null
 * pointer's (nothing is mapped below 0x1000, for that reason). And for
 * the bss or the stack there is no file: the page is zeros, so a stack
 * of 8 MB costs only the pages a program reaches, and brk only moves a
 * number (Sysproc.sysbrk).
 *
 * The file's read may sleep (a server's file is read with a 9P
 * message: Devmnt), and meanwhile another process sharing the segment
 * may fault on the same page. So the page is looked for again after
 * the read, and the process that lost maps the winner's page.
 *
 * cs-history:
 * A page brought in when it is touched, without the program knowing,
 * is the Atlas computer's "one-level store" (Manchester, 1962). It was
 * made to let a program believe in more memory than the machine had,
 * the rest being on a drum. Segments, where a program's memory is a few
 * named ranges each with its own rule, come from Multics. Unix had
 * neither at first (a process was swapped whole); Berkeley's 3BSD
 * (1979, for the VAX) gave it demand paging.
 *
 * wib:
 * No page ever leaves: there is no swap, and no reclaiming of a text
 * page that could be read again. When memory runs out, the process
 * that asked is ended with a note saying so (Main.fault), and the rest
 * go on. A text page can be written by its program, because it is
 * mapped for writing. The plan for a swap is plan_kernel_swap.md.
 *
 * others:
 * xv6 has one table, the process's: exec reads the whole program in,
 * fork copies every page, and a fault is always an error (lazy
 * allocation and copy on write are exercises of its course). Linux
 * has this file's three levels under other names: the file's pages
 * are the page cache, shared by all programs and by read and write
 * too; a segment is a vm_area_struct; and a page may be taken back at
 * any time, because the first table is enough to find it again.
 *
 * References: T. Kilburn, D. B. G. Edwards, M. J. Lanigan and F. H.
 * Sumner, "One-Level Storage System" (IRE Transactions on Electronic
 * Computers, 1962). principia's Kernel.nw, the chapters on memory
 * (segment.c, fault.c, page.c). The xv6 book's chapter on page
 * tables, for what the MMU's own table is (here Mmu and Arch). *)

open Types
open Errors

(* a new segment, with no page yet; the last three arguments are its
 * image, and the offset and length of its bytes in the file *)
val create : seg_kind -> int -> int -> chan option -> int -> int -> segment

(* the segment of p that holds va *)
val segment : proc -> int -> segment option

(* [fault p va] maps the page at va, making it if need be, or copies it
 * if it is written while shared since a fork; then it returns true. It
 * returns false when va is not in a segment, or when the page is
 * mapped and the access is refused: that is the process's trap. *)
val fault : proc -> int -> bool

(* [validaddr p addr len] makes the pages of [addr, addr+len) that are
 * in a segment mapped, and the process's own (none of them is left
 * shared since a fork) *)
val validaddr : proc -> int -> int -> unit

(* [page pgdir s va] makes a page of s (zeroed) and maps it in the
 * table pgdir (exec does it to write the arguments in its new space) *)
val page : int -> segment -> int -> unit

(* [dup s from pgdir share] makes a fork's segment from s, whose pages
 * are mapped in the table [from], and maps it in pgdir. It is one of:
 * - s itself, when it is shared (text, and with RFMEM data and bss);
 * - for data and bss, a segment with s's pages, which are then read
 *   only in both tables and copied when written (fault);
 * - a copy of s's pages (the stack, or a segment that is shared).
 * The TLB of the table [from] must be flushed afterwards. *)
val dup : segment -> int -> int -> bool -> segment

(* gives up a process's segments (exec, exits). The last process of a
 * segment frees its pages and closes its image. The table's own pages
 * are freed. *)
val release : int -> segment list -> unit

(* [shrink p s newtop] frees the pages from newtop up (brk; Error
 * einuse when s is shared) *)
val shrink : proc -> segment -> int -> unit

(* [detach p s] does segdetach's work: it takes s out of p and its
 * pages out of p's table; the last process of s frees them *)
val detach : proc -> segment -> unit

(* [free_range p s lo hi] does segfree's work: it frees the pages of s
 * wholly in [lo, hi), which are zeros at their next touch (Error
 * einuse when s is shared) *)
val free_range : proc -> segment -> int -> int -> unit

(* [sync p va len] does segflush's work: it puts the bytes the process
 * wrote there in memory, and out of the instruction cache
 * (Machine.Phys.sync), so that the process may run them. It raises
 * Error ebadarg outside the process's segments. *)
val sync : proc -> int -> int -> unit

(* [read_image c off n] reads n bytes of an image's file from off,
 * fewer at its end. It reads a page's bytes (page), and a dying
 * process's symbol table (Syscall's trace). *)
val read_image : chan -> int -> int -> string
