(* The segments a program attaches (principia's segattach, segdetach,
 * segfree and segflush, in sysproc.c and segment.c). Such a segment is
 * a range of zeros added to the program's memory. Its pages are given
 * at their first touch (Fault), as the bss's are; it is shared with
 * the program's children at a fork, and it goes away at an exec.
 *
 *     code = segattach(0, "memory", nil, 4096)   a hole below the stack
 *     code[0] = ...; code[1] = ...               the program writes
 *     segflush(code, 8)                          the caches are told
 *     f = (fn)code; f(1)                         and it runs it
 *
 * That is a JIT's memory (mini-dotnet's, on mini-9pi). On the Pi the
 * data cache keeps what the program wrote for a while, and the
 * instruction cache is filled from the memory, never from the data
 * cache. So the bytes must reach the memory, and the instruction
 * cache must be emptied of what was there (Machine.Phys.sync, the same
 * as for a program's page that the kernel reads in); otherwise the
 * processor runs the old instructions. Under mini-qemu, its decoded
 * instructions are dropped at that same emptying.
 *
 * A segment is mapped with its rights. With SG_RONLY (0o40) it is read
 * only, and a write is the program's trap. Otherwise it can be read,
 * written and run, because arm's pages have no separate right to run
 * (there is no XN here). So segattach's attributes are mmap's
 * protections, given once, at the attach; Plan 9 has no mprotect, and
 * neither has mini-9pi.
 *
 * The classes are "memory" and "shared", and they are the same here:
 * zeros. Plan 9's other classes (a device's physical memory, "lock")
 * are not here, nor is segbrk, nor SG_CEXEC's choice: every attached
 * segment goes away at an exec, where Plan 9 keeps those without
 * SG_CEXEC.
 *
 * others:
 * Linux's mmap (from 4.2BSD's design, 1982) does all of a process's
 * memory, files and zeros, with mprotect to change the rights
 * afterwards. A JIT there maps memory writable, writes, then calls
 * mprotect to make it readable and runnable (or it uses two views of
 * one memfd, as mini-dotnet's Code_memory does on Linux), and it calls
 * __builtin___clear_cache, arm's cacheflush, for the caches. Plan 9's
 * segattach names memory by a class rather than by a file. *)

open Types

(* [syssegattach p attr class va len] returns the segment's address *)
val syssegattach : proc -> int -> string -> int -> int -> int

(* takes out the segment attached at va; Error ebadarg if there is
 * none *)
val syssegdetach : proc -> int -> int

(* makes the pages wholly in [va, va+len) zeros again *)
val syssegfree : proc -> int -> int -> int

(* makes what was written in [va, va+len) ready to run (Fault.sync) *)
val syssegflush : proc -> int -> int -> int
