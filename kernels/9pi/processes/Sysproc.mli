(* The system calls on processes (principia's sysproc.c): rfork, exec,
 * exits, await, brk, sleep, alarm, notify and noted (only their
 * portable parts: the delivery of a note is the arch's, in Syscall),
 * rendezvous and errstr. There are also pexit and pprint, which the
 * arch's notes use too.
 *
 * rfork is the one call that makes a process, and its argument says
 * what the new process has of the old one's (the groups of Types):
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
 * Here is the life of a child, with the two other calls (the shell's
 * side is in shell's Process, with the same three calls under Unix's
 * names):
 *
 *     parent                          child
 *     pid = rfork(...)                rfork returns 0
 *                                     exec("/bin/ls", argv)     Exec
 *     await(buf, n)  sleeps           ... ls runs ...
 *       Child_exit                    exits("")   or exits("no file")
 *     buf: "63 0 0 20 ''"             (gone: Proc's Zombie)
 *
 * await's answer is text: the pid, then three times in ms (the user's
 * and the system's, which are 0 here, and the real one), and then the
 * exit message, quoted. A message that is not empty gets the
 * program's name and pid put before it ("ls 63: no file").
 *
 * A note is a string posted to a process (Proc.postnote). The kernel
 * posts one for a trap ("sys: trap: fault read va=0x35 pc=0x103ee4"),
 * the clock posts one for an alarm ("alarm"), and anyone who may write
 * the process's /proc/n/note can post one (Devproc). notify registers
 * one function for all of them. It is called with the string and
 * decides: noted(NCONT) goes on where the process was, and
 * noted(NDFLT) makes it die of the note. Without a handler, a note
 * ends the process, and its text is the exit message.
 *
 * rendezvous is the smallest way for two processes to meet: each
 * calls it with the same tag and a value, the first sleeps, the
 * second wakes it, and each returns with the other's value. Plan 9's
 * thread library builds its locks and its channels on it.
 *
 * plan9-is-cleaner:
 * There is one call with bits, where Unix grew a family: fork, vfork
 * (a fork that shares memory until exec), the creation of threads,
 * setsid and setpgrp for the groups, and much later unshare for the
 * name space. Each of them is a point of rfork's table. Linux's clone
 * has the same shape, with flags that say, resource by resource, what
 * is shared, and its unshare is rfork without RFPROC. What a container
 * is made of (CLONE_NEWNS and its kin) is the left column above.
 *
 * plan9-is-cleaner:
 * A process ends with a string, empty for success, where Unix has a
 * number from 0 to 255 whose meanings each program invents. A note is
 * a string too, where a signal is a number from a list fixed in the
 * kernel (SIGINT is 2, SIGSEGV is 11, and two are for the user's own
 * use). A trap's note says the address and the pc, a program may post
 * any words to another, and there is one handler to write, not a table
 * of them with masks. What is lost is a quick test: a handler has to
 * compare strings.
 *
 * wib:
 * A fork copies the child's data, bss and stack pages at once
 * (Fault.dup). 9pi shares them until one side writes, and only then
 * copies that page alone; so a fork followed by an exec, the usual
 * case, copies nearly nothing. Here a fork copies what the parent had
 * touched, and the code has no page shared by accident.
 *
 * References: fork(2), exec(2), exits(2), wait(2), notify(2) and
 * rendezvous(2) in the Plan 9 manual. Rob Pike and others, "Plan 9
 * from Bell Labs" (1995), its section on processes, for rfork.
 * principia's Kernel.nw. *)

open Types

(* [exits p status] ends the process (pexit): its files are closed, its
 * parent is told (with a wait record), and its memory is freed. When
 * the boot process ends, the kernel panics. *)
val exits : proc -> string -> unit

(* writes a message on the process's standard error, with "text pid: "
 * first (devcons_pprint) *)
val pprint : proc -> string -> unit

val sysrfork : proc -> int -> int
(* [sysexec p name argv], where argv is the user's array of strings *)
val sysexec : proc -> string -> int -> int
(* [sysexits p status], where status is a user's string (0 for none) *)
val sysexits : proc -> int -> int
val sysawait : proc -> int -> int -> int
val sysbrk : proc -> int -> int
val syssleep : proc -> int -> int
val sysalarm : proc -> int -> int
val sysnotify : proc -> int -> int
(* sysnoted checks its argument and keeps it in noted_arg for after the
 * call returns (arch__noted, which is Syscall's noted, uses it) *)
val sysnoted : proc -> int -> int
val noted_arg : int option ref
val sysrendezvous : proc -> int -> int -> int
val syserrstr : proc -> int -> int -> int

(* noted's arguments (NCONT, NDFLT, NSAVE, NRSTR) *)
val ncont : int
val ndflt : int
val nsave : int
val nrstr : int
