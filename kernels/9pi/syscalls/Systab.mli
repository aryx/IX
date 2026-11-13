(* The table of system calls (principia's systab.c). It has their
 * numbers as sys.h has them, their names as /proc/n/status shows them
 * (sysctab), and, for each one, the function called with its arguments
 * (the words the arch's Syscall took from the user). segbrk is not
 * done yet: it fails with "not yet", and the console names it.
 *
 * Here are all of them, by number:
 *
 *      0 nop       10 pread     20 bind       30 segfree
 *      1 rfork     11 pwrite    21 mount      31 segflush
 *      2 exec      12 seek      22 unmount    32 segbrk
 *      3 exits     13 create    23 sleep      33 rendezvous
 *      4 await     14 remove    24 alarm      34 semacquire
 *      5 brk       15 chdir     25 notify     35 semrelease
 *      6 open      16 stat      26 noted      36 tsemacquire
 *      7 close     17 fstat     27 pipe       37 fversion
 *      8 dup       18 wstat     28 segattach  38 fauth
 *      9 fd2path   19 fwstat    29 segdetach  39 errstr
 *
 *     processes   rfork exec exits await brk sleep alarm     Sysproc
 *     notes       notify noted; errstr, the last error       Sysproc
 *     waiting     rendezvous semacquire semrelease tsem...   Syssema
 *     files       open create close dup pipe pread pwrite
 *                 seek stat fstat wstat fwstat remove chdir
 *                 fd2path                                    Sysfile
 *     name space  bind mount unmount                         Sysfile
 *     a server    fversion fauth                             Auth
 *     memory      segattach segdetach segfree segflush       Sysseg
 *                 (segbrk not yet)
 *
 * plan9-is-cleaner:
 * Forty calls are the whole interface of the system, and the list is
 * as telling for what it lacks:
 * - there is no getpid: a program reads #c/pid;
 * - there is no time or gettimeofday: a program reads /dev/time;
 * - there is no kill: a program writes to /proc/n/note;
 * - there is no ioctl, no socket and its dozen companions, no chmod or
 *   chown, and no mknod;
 * - there is no setuid or getuid: a program reads /dev/user, and no
 *   program runs as another user because of a bit of its file;
 * - there is no ptrace: a debugger opens /proc/n/mem;
 * - there is no uname, sysctl or sysinfo: there are #k's files.
 * Linux has over three hundred calls, and adds some each year. Each of
 * the missing ones above is a call there, and here it is a file that
 * cat and echo reach, and that another machine reaches by mounting it.
 * The numbers are principia's own; Bell Labs' and 9front's are
 * different (pread is 50 there, and rfork is 19).
 *
 * design:
 * The table is a variant and an array. A call's arguments are read as
 * five words, whatever the call takes, and each line of [call] says, by
 * what it does with them, which word is an address, which is a string
 * to fetch, and which is a number. This is the C kernel's va_list and
 * casts, typed. *)

open Types

type call =
  | Nop | Rfork | Exec | Exits | Await | Brk | Open | Close | Dup | Fd2path | Pread | Pwrite | Seek
  | Create | Remove | Chdir | Stat | Fstat | Wstat | Fwstat | Bind | Mount | Unmount | Sleep | Alarm
  | Notify | Noted | Pipe | Segattach | Segdetach | Segfree | Segflush | Segbrk
  | Rendezvous | Semacquire | Semrelease | Tsemacquire | Fversion | Fauth | Errstr

(* the calls by number, each with its name *)
val calls : (call * string) array

(* [call p c a words] makes the call and returns its result. a holds
 * its five argument words as ints, and words holds their bytes (for a
 * permission's bit 31, DMDIR). *)
val call : proc -> call -> int array -> string -> int
