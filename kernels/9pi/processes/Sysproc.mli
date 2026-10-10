(* The processes' system calls (principia's sysproc.c): rfork, exec,
 * exits, await, brk, sleep, alarm, notify and noted (their portable
 * parts: the note's delivery is the arch's, Syscall), rendezvous,
 * errstr; and pexit, pprint, which the arch's notes use too.
 *
 * rfork is the one call that makes a process, and its argument says
 * what the new one has of the old one's (Types' groups):
 *
 *                   bit set: a copy     C bit: a new, empty   neither
 *     name space    RFNAMEG             RFCNAMEG              shared
 *     environment   RFENVG              RFCENVG               shared
 *     descriptors   RFFDG               RFCFDG                shared
 *
 *     RFMEM      data and bss shared with the parent (else copied;
 *                the text is always shared, the stack always copied)
 *     RFNOTEG    a note group of its own      RFREND   a rendezvous
 *     RFNOWAIT   no status left for the parent         group of its own
 *     RFPROC     a new process. Without it nothing is made: the
 *                caller's own groups are changed as said
 *
 *     fork()                is rfork(RFFDG|RFREND|RFPROC), libc's
 *     a thread              is rfork(RFPROC|RFMEM|...)
 *     rc's rfork n          is rfork(RFNAMEG): the binds that follow
 *                           are this shell's and its children's only
 *
 * The life of a child, with the two other calls (the shell's side is
 * shell's Process: the same three, by Unix's names):
 *
 *     parent                          child
 *     pid = rfork(...)                rfork returns 0
 *                                     exec("/bin/ls", argv)     Exec
 *     await(buf, n)  sleeps           ... ls runs ...
 *       Child_exit                    exits("")   or exits("no file")
 *     buf: "63 0 0 20 ''"             (gone: Proc's Zombie)
 *
 * await's answer is text: the pid, then three times in ms (the
 * user's and the system's, 0 here, and the real one), and the exit
 * message, quoted; a message not empty has the program's name and pid
 * put before it ("ls 63: no file").
 *
 * A note is a string posted to a process (Proc.postnote): by the
 * kernel for a trap ("sys: trap: fault read va=0x35 pc=0x103ee4"),
 * by the clock for an alarm ("alarm"), by anyone who may write its
 * /proc/n/note (Devproc). notify registers one function for all of
 * them; it is called with the string and decides: noted(NCONT) to go
 * on where the process was, noted(NDFLT) to die of it. Without a
 * handler, a note ends the process, its text the exit message.
 *
 * rendezvous is the smallest way for two processes to meet: each
 * calls it with the same tag and a value, the first sleeps, the
 * second wakes it, and each returns with the other's value. Plan 9's
 * thread library builds its locks and its channels on it.
 *
 * plan9-is-cleaner:
 * One call with bits, where Unix grew a family: fork, vfork (a fork
 * that shares memory until exec), the threads' creation, setsid and
 * setpgrp for the groups, and much later unshare for the name space.
 * Each is a point of rfork's table. Linux's clone has the same shape,
 * flags that say resource by resource what is shared, and its
 * unshare is rfork without RFPROC. What a container is made of
 * (CLONE_NEWNS and its kin) is the left column above.
 *
 * plan9-is-cleaner:
 * A process ends with a string, empty for success, where Unix has a
 * number from 0 to 255 whose meanings each program invents. And a
 * note is a string too, where a signal is a number from a list fixed
 * in the kernel (SIGINT 2, SIGSEGV 11, two for the user's own): a
 * trap's note says the address and the pc, a program may post any
 * words to another, and there is one handler to write, not a table
 * of them with masks. What is lost is a quick test: a handler
 * compares strings.
 *
 * wib:
 * A fork copies the child's data, bss and stack pages at once
 * (Fault.dup). 9pi shares them until one side writes, and copies
 * then, the page alone; a fork followed by an exec, the usual case,
 * so copies nearly nothing. Here it copies what the parent had
 * touched, and the code has no page shared by accident.
 *
 * References: fork(2), exec(2), exits(2), wait(2), notify(2) and
 * rendezvous(2) in the Plan 9 manual. Rob Pike and others, "Plan 9
 * from Bell Labs" (1995), its section on processes, for rfork.
 * principia's Kernel.nw. *)

open Types

(* the process's end (pexit): its files closed, its parent told (a
 * wait record), its memory freed; the boot process's is the kernel's
 * panic *)
val exits : proc -> string -> unit

(* a message on the process's standard error, "text pid: " first
 * (devcons_pprint) *)
val pprint : proc -> string -> unit

val sysrfork : proc -> int -> int
(* [sysexec p name argv]: argv the user's array of strings *)
val sysexec : proc -> string -> int -> int
(* [sysexits p status]: status a user's string (0: none) *)
val sysexits : proc -> int -> int
val sysawait : proc -> int -> int -> int
val sysbrk : proc -> int -> int
val syssleep : proc -> int -> int
val sysalarm : proc -> int -> int
val sysnotify : proc -> int -> int
(* sysnoted: its argument checked, kept for after the call's return
 * (arch__noted: Syscall's noted) *)
val sysnoted : proc -> int -> int
val noted_arg : int option ref
val sysrendezvous : proc -> int -> int -> int
val syserrstr : proc -> int -> int -> int

(* noted's arguments (NCONT, NDFLT, NSAVE, NRSTR) *)
val ncont : int
val ndflt : int
val nsave : int
val nrstr : int
