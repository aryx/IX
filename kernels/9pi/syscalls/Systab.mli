(* The system calls' table (principia's systab.c): their numbers as
 * sys.h has them, their names as /proc/n/status shows them (sysctab),
 * and each one's function called with its arguments (the words the
 * arch's Syscall took from the user). The segments' calls (segattach,
 * ...) are not yet: "not yet", named on the console.
 *
 * All of them, by number:
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
 *     memory      the five seg calls                         (not yet)
 *
 * plan9-is-cleaner:
 * Forty calls is the whole interface of the system, and the list is
 * as telling for what it lacks. No getpid: a program reads #c/pid.
 * No time, no gettimeofday: /dev/time. No kill: a write to
 * /proc/n/note. No ioctl, no socket and its dozen companions, no
 * chmod or chown, no mknod, no setuid or getuid (/dev/user is read;
 * no program runs as another user by a bit of its file), no ptrace
 * (a debugger opens /proc/n/mem), no uname, sysctl or sysinfo
 * (#k's files). Linux has over three hundred calls, and adds some
 * each year; each of the missing ones above is there a call, here a
 * file that cat and echo reach, and that another machine reaches by
 * mounting it. The numbers are principia's own: Bell Labs' and
 * 9front's are others (pread is 50 there, rfork 19).
 *
 * design:
 * The table is a variant and an array. A call's arguments are read
 * as five words whatever it takes, and each line of [call] says, by
 * what it does with them, which is an address, which a string to
 * fetch, which a number: the C kernel's va_list and casts, typed. *)

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
