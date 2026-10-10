(* Segments and page faults (principia's segment.c and fault.c, as far
 * as mini-9pi needs): a segment's pages are its own (a table of them),
 * given at their first touch: from the program's file for text and data
 * (read through its channel: devmnt's Tread, devroot's bytes), zeros
 * for bss and stack. A process's table maps a segment's pages as it
 * touches them, so that a segment may be shared (text always, data and
 * bss by rfork's RFMEM): a fault maps the page another sharer made. The
 * system calls fault a user's buffer in before using it (validaddr).
 *
 * Three tables, each the cache of the one before:
 *
 *     the program's file     where a text or data page's bytes are
 *            |  read once, at the page's first touch
 *     segment.pages          address -> physical page: what the
 *            |               segment has, for all who share it
 *            |  mapped as each process touches it
 *     the process's table    address -> physical page: what the MMU
 *     (pgdir: Mmu)           looks at, at each access of the program
 *
 * A program's first instruction, after an exec that read 32 bytes:
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
 * The same trap for an address in no segment is the program's
 * error, and its end: the note "sys: trap: fault read va=0x35", a
 * null pointer's (nothing is mapped below 0x1000, for that). And for
 * the bss or the stack there is no file: the page is zeros, so a
 * stack of 8 MB costs the pages a program reaches, and brk only
 * moves a number (Sysproc.sysbrk).
 *
 * The file's read may sleep (a server's file is a 9P message:
 * Devmnt), and another process sharing the segment may fault on the
 * same page meanwhile: the page is looked for again after the read,
 * and the one who lost maps the winner's.
 *
 * cs-history:
 * A page brought in when it is touched, and the program none the
 * wiser, is the Atlas computer's "one-level store" (Manchester,
 * 1962): made to let a program believe in more memory than the
 * machine had, the rest on a drum. Segments, a program's memory as a
 * few named ranges each with its own rule, are Multics's. Unix had
 * neither at first (a process was swapped whole); Berkeley's 3BSD
 * (1979, for the VAX) gave it demand paging.
 *
 * wib:
 * No page ever leaves: there is no swap, and no reclaiming of a text
 * page that could be read again. When memory runs out, the process
 * that asked is ended with a note saying so (Main.fault) and the
 * rest go on. No copy on write either (Sysproc's rfork copies), and
 * a text page can be written by its program: every page is mapped
 * for writing. A swap's plan is plan_kernel_swap.md.
 *
 * others:
 * xv6 has one table, the process's: exec reads the whole program in,
 * fork copies every page, and a fault is always an error (lazy
 * allocation and copy on write are its course's exercises). Linux
 * has this file's three levels under other names: the file's pages
 * are the page cache, shared by all programs and by read and write
 * too; a segment is a vm_area_struct; and a page may be taken back
 * at any time, the first table being enough to find it again.
 *
 * References: T. Kilburn, D. B. G. Edwards, M. J. Lanigan and F. H.
 * Sumner, "One-Level Storage System" (IRE Transactions on Electronic
 * Computers, 1962). principia's Kernel.nw, the chapters on memory
 * (segment.c, fault.c, page.c). The xv6 book's chapter on page
 * tables, for what the MMU's own table is (here Mmu and Arch). *)

open Types
open Errors

(* a new segment, no page yet (its image, the file's bytes' offset and
 * length) *)
val create : seg_kind -> int -> int -> chan option -> int -> int -> segment

(* [fault p va]: the page at va mapped, made if need be (true), or not
 * in a segment (false: the process's trap) *)
val fault : proc -> int -> bool

(* [validaddr p addr len]: the pages of [addr, addr+len) that are in a
 * segment, mapped *)
val validaddr : proc -> int -> int -> unit

(* [page pgdir s va]: a page of s made (zeroed) and mapped in the table
 * pgdir (exec writing the arguments in its new space) *)
val page : int -> segment -> int -> unit

(* [dup s pgdir share]: a fork's segment: s itself (shared: text, and
 * with RFMEM data and bss), or a copy of its pages, mapped in pgdir *)
val dup : segment -> int -> bool -> segment

(* a process's segments given up (exec, exits): a segment's pages freed,
 * its image closed, by its last process; the table's own pages freed *)
val release : int -> segment list -> unit

(* [shrink p s newtop]: the pages from newtop up freed (brk; Error
 * einuse when shared) *)
val shrink : proc -> segment -> int -> unit
