(* exec (principia's sysexec) loads a Plan 9 a.out, or a "#!" script
 * (whose interpreter is run with the script's name), into a new address
 * space:
 *
 *   UTZERO 0x1000  text (the 32-byte header, big-endian, included)
 *   t              data, from the file          t = UTROUND(UTZERO+32+text)
 *   d              bss, zero, brk's to grow     d = ROUND(t+data)
 *   b                                           b = ROUND(t+data+bss)
 *   ...
 *   USTKTOP-USTKSIZE  the stack (8MB)
 *   USTKTOP-ssize-4   argc, then argv[], 0, then the strings, then
 *   USTKTOP-72        the Tos (clock, pid, ...: libc's _tos)
 *   USTKTOP 0x20000000
 *
 * This is the layout sysexec and arch_execregs make, byte for byte.
 * exec reads only the header, and writes only the stack's pages that
 * the arguments are on. The rest comes at its first touch (Fault reads
 * the text and data from the file, whose channel is kept for that).
 *
 * Here is the file, as ix's linker writes it and as exec reads its
 * first 32 bytes (8 words, the highest byte first, on every processor):
 *
 *     0  magic  0x647 for arm     16  the symbols' size
 *     4  text's size              20  the entry point
 *     8  data's size              24, 28  two more tables' sizes
 *     12 bss's size
 *     32 the text, then the data: the file's bytes are the memory's
 *        bytes, in order, with the header itself at 0x1000
 *
 * Any other file is tried as a script. A first line "#!/bin/rc -e"
 * turns exec("/bin/x", x a b) into the exec of /bin/rc with the
 * arguments x -e /bin/x a b. This is done only once (an interpreter
 * that is itself a script is an error). So a script is a program to
 * whoever runs it, in any language, and the shell is not special.
 *
 * What exec keeps is what the process is, rather than what it runs:
 * its pid, its descriptors (except those opened with OCEXEC), its name
 * space, its environment, and its parent. What it drops is the memory,
 * and the notes' handler, whose code is gone. That split is why rfork
 * and exec are two calls (shell's Process draws the moment between
 * them).
 *
 * plan9-is-cleaner:
 * The header has 32 bytes, with no table of sections and nothing to
 * relocate: the linker has put every byte where it will be, and exec
 * needs three sizes and an address. Unix's a.out was like this too.
 * ELF (System V Release 4, then every Unix) describes segments,
 * sections, a dynamic linker to run first and the libraries it must
 * find, and exec's work is then mostly done by another program,
 * ld.so. Plan 9 has no shared libraries: a program is one file, whole.
 *
 * cs-history:
 * a.out is the name the first Unix assemblers gave their output when
 * told no other. The name was kept for the format, and it is still
 * what a C compiler writes by default. The "#!" line came into Unix at
 * Bell Labs in January 1980 (it is Dennis Ritchie's) and spread with
 * Berkeley's releases. Before it, the shell itself, when it failed to
 * exec a file, read it as commands, and only the shell could do that.
 *
 * others:
 * xv6's exec reads the whole program into memory before it returns
 * (mini-xv6's Exec); here a program of 300 KB whose first screen
 * needs 20 pages reads 20 pages. Linux does as here, by mapping the
 * file (mmap), with the page cache between the file and the process.
 *
 * References: a.out(6) and exec(2) in the Plan 9 manual. principia's
 * Kernel.nw (sysexec), and its Linker book for who writes the
 * header. *)

open Types
open Errors

val utzero : int
val ustktop : int
val tos_size : int

(* the most the arguments may take, with their strings and argv
 * (TSTKSIZ's pages). It is exec's only bound on them, and on each
 * string too. *)
val maxargs : int

(* [exec p path args] gives the process its new program and sets its
 * registers (pc, sp). It returns the value its R0 gets (the Tos's
 * address). It raises Error when the file is not a program, and the old
 * program is then kept. *)
val exec : proc -> string -> string list -> int

(* sets the Tos's pid, after exec and fork (as arch__kexit does) *)
val set_tos_pid : proc -> unit
