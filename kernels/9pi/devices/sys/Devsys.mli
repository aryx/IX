(* '#k' holds the system's files (principia's devsys.c):
 * - osversion, config, hostdomain, sysname, drivers and sysstat;
 * - hostowner, which when written sets the kernel's owner, eve;
 * - reboot, which takes three words: "panic" stops the machine, as Plan
 *   9's does; "hang" leaves the kernel stuck with its lock held, for the
 *   watchdog; "exception" raises one in the system call, for a panic's
 *   trace.
 *
 * plan9-is-cleaner:
 * There is no root. Unix has a user of number 0 whom no check stops, and
 * a bit on a program's file (set-user-id) that makes whoever runs it
 * that user for a while, so every such program is a way in if it has a
 * bug. Plan 9 has neither. A machine has an owner, whose name is like
 * any other (here it is what boot.rc writes to hostowner: Dev.eve). The
 * owner owns the files of the kernel's devices and may do to them what
 * their modes say; on a file server, the owner of the terminal is nobody
 * special. What needed root on Unix mostly needs nothing here, because
 * mounting is a process's own business (Kchan). *)

(* registers the device *)
val init : unit -> unit
