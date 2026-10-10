(* '#k', the system's files (principia's devsys.c): osversion, config,
 * hostowner (written: the kernel's owner, eve), hostdomain, sysname,
 * drivers, reboot, sysstat.
 *
 * plan9-is-cleaner:
 * No root. Unix has a user of number 0 whom no check stops, and a
 * bit on a program's file (set-user-id) that makes whoever runs it
 * that user for a while: every such program is a way in if it has a
 * bug. Plan 9 has neither. A machine has an owner, a name like
 * another (here what boot.rc writes to hostowner: Dev.eve), who owns
 * the kernel's devices' files and may do to them what their modes
 * say; on a file server the owner of the terminal is nobody special.
 * What needed root on Unix mostly needs nothing here: mounting is a
 * process's own business (Kchan). *)

(* the device registered *)
val init : unit -> unit
