(* The segments a program attaches (principia's segattach, segdetach,
 * segfree, segflush in sysproc.c and segment.c): a range of zeros
 * added to its memory, given at their first touch (Fault) as the bss's,
 * shared with its children at a fork, gone at an exec.
 *
 *     code = segattach(0, "memory", nil, 4096)   a hole below the stack
 *     code[0] = ...; code[1] = ...               the program writes
 *     segflush(code, 8)                          the caches told
 *     f = (fn)code; f(1)                         and it runs it
 *
 * That is a JIT's memory (mini-dotnet's on mini-9pi). On the Pi the
 * data cache keeps what the program wrote for a while, and the
 * instructions' cache is filled from the memory, never from the data
 * cache; so the bytes must reach the memory and the instructions'
 * cache be emptied of what was there (Machine.Phys.sync: the same as
 * for a program's page the kernel reads in), or the processor runs
 * the old instructions. Under mini-qemu its decoded instructions are
 * dropped at that same emptying.
 *
 * Mapped with the segment's rights: SG_RONLY (0o40) read only, a
 * write the program's trap; else read and write, and run: arm's pages
 * have no right to run apart (no XN here). So segattach's attributes
 * are mmap's protections, given once, at the attach; Plan 9 has no
 * mprotect, and neither has mini-9pi.
 *
 * The classes are "memory" and "shared", the same here: zeros. Plan
 * 9's others (a device's physical memory, "lock") are not; nor
 * segbrk; nor SG_CEXEC's choice: every attached segment goes at an
 * exec, where Plan 9 keeps those without it.
 *
 * others:
 * Linux's mmap (from 4.2BSD's design, 1982) does all of a process's
 * memory, files and zeros, with mprotect to change the rights after;
 * a JIT there maps writable, writes, then mprotect to read and run
 * (or two views of one memfd: mini-dotnet's Code_memory on Linux), and
 * calls __builtin___clear_cache, arm's cacheflush, for the caches.
 * Plan 9's segattach names memory by a class rather than a file. *)

open Types

(* [syssegattach p attr class va len]: the segment's address *)
val syssegattach : proc -> int -> string -> int -> int -> int

(* the segment attached at va taken out; Error ebadarg if none *)
val syssegdetach : proc -> int -> int

(* its pages wholly in [va, va+len) zeros again *)
val syssegfree : proc -> int -> int -> int

(* [va, va+len) written, to be run: Fault.sync *)
val syssegflush : proc -> int -> int -> int
