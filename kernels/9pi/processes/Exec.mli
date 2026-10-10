(* exec (principia's sysexec): a Plan 9 a.out, or a "#!" script (its
 * interpreter run with the script's name), into a new address space:
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
 * as sysexec and arch_execregs lay it out, byte for byte. Only the
 * header is read, and the stack's pages the arguments are on written:
 * the rest comes at its first touch (Fault: text and data from the
 * file, the channel kept for that).
 *
 * The file, as ix's linker writes it and as exec reads its first 32
 * bytes (8 words, the highest byte first, on every processor):
 *
 *     0  magic  0x647 for arm     16  the symbols' size
 *     4  text's size              20  the entry point
 *     8  data's size              24, 28  two more tables' sizes
 *     12 bss's size
 *     32 the text, then the data: the file's bytes are the memory's,
 *        in order, the header itself at 0x1000
 *
 * Anything else is tried as a script: a first line "#!/bin/rc -e"
 * makes exec("/bin/x", x a b) the exec of /bin/rc with the arguments
 * x -e /bin/x a b, once (an interpreter that is a script is an
 * error). So a script is a program to whoever runs it, in any
 * language, and the shell is not special.
 *
 * What exec keeps is what the process is rather than what it runs:
 * its pid, its descriptors (but those opened with OCEXEC), its name
 * space, its environment, its parent. What it drops: the memory, and
 * the notes' handler, whose code is gone. That split is why rfork and
 * exec are two calls (shell's Process draws the moment between
 * them).
 *
 * plan9-is-cleaner:
 * A header of 32 bytes, with no table of sections and nothing to
 * relocate: the linker has put every byte where it will be, and exec
 * needs three sizes and an address. Unix's a.out was this too; ELF
 * (System V Release 4, then every Unix) describes segments, sections,
 * a dynamic linker to run first and the libraries it must find, and
 * exec's work is then mostly another program's, ld.so's. Plan 9 has
 * no shared libraries: a program is one file, whole.
 *
 * cs-history:
 * a.out is the name the first Unix assemblers gave their output when
 * told no other, kept for the format and still what a C compiler
 * writes by default. The "#!" line came into Unix at Bell Labs around
 * 1980 (Dennis Ritchie's, from memory) and spread with Berkeley's
 * releases; before it the shell itself, failing to exec a file, read
 * it as commands, and only the shell could.
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

(* [exec p path args]: the process's new program, its registers set
 * (pc, sp); the value its R0 gets (the Tos's address); Error when
 * the file is not a program, the old program kept *)
val exec : proc -> string -> string list -> int

(* the Tos's pid, after exec and fork (arch__kexit's) *)
val set_tos_pid : proc -> unit
