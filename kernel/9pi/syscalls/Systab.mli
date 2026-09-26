(* The system calls' table (principia's systab.c): their numbers as
 * sys.h has them, their names as /proc/n/status shows them (sysctab),
 * and each one's function called with its arguments (the words the
 * arch's Syscall took from the user). The segments' calls (segattach,
 * ...) are not yet: "not yet", named on the console. *)

open Types

type call =
  | Nop | Rfork | Exec | Exits | Await | Brk | Open | Close | Dup | Fd2path | Pread | Pwrite | Seek
  | Create | Remove | Chdir | Stat | Fstat | Wstat | Fwstat | Bind | Mount | Unmount | Sleep | Alarm
  | Notify | Noted | Pipe | Segattach | Segdetach | Segfree | Segflush | Segbrk
  | Rendezvous | Semacquire | Semrelease | Tsemacquire | Fversion | Fauth | Errstr

(* by number: the call, its name *)
val calls : (call * string) array

(* [call p c a words]: its result; a its five argument words as ints,
 * words their bytes (a permission's bit 31, DMDIR) *)
val call : proc -> call -> int array -> string -> int
