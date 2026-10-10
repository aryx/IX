(* The files' system calls (principia's sysfile.c): open, create,
 * close, pread, pwrite, seek, dup, pipe, fd2path, stat, fstat, wstat,
 * fwstat, remove, chdir; the namespace's: bind, mount, unmount. Names
 * are the user's strings already read (Systab), buffers the user's
 * addresses.
 *
 * Each call is a few lines, because the work is Kchan's (a name to a
 * channel, a descriptor to a channel) and then the device's (Dev):
 *
 *     open(name, mode)    Kchan.namec: the channel, through the name
 *                         space; the device's open_; Kchan.fdalloc:
 *                         the first free descriptor
 *     pread(fd, buf, n, off)
 *                         Kchan.fdtochan: the channel, open to read;
 *                         the device's read at off (-1: the channel's
 *                         own offset, then moved); Usermem.user_write
 *     close(fd)           the descriptor freed; at the channel's last
 *                         holder, the device's close
 *     bind(new, old, f)   two namec's, Kchan.bind
 *     mount(fd, old, f)   Devmnt.attach on fd's channel, Kchan.bind
 *
 * A directory is read as a file: its entries in their wire form
 * (Dev.encode), whole ones, as many as fit. ls is open, read, close.
 *
 * plan9-is-cleaner:
 * What is not here, because a file does it. No ioctl (Dev). No
 * mknod, link, symlink or readlink: a name space is made of binds,
 * which are a process's and vanish with it, where a link is a fact
 * written on a disk. No chmod, chown, utime, truncate, rename: each
 * is a wstat, an entry sent back with the fields to change. No
 * mkdir: a create with the directory bit (utilities' Mkdir). No
 * socket, connect, accept (Devip), no select or poll: a program that
 * waits on two files makes two processes, which rfork's shared
 * memory makes cheap. And read and write have no offset kept apart:
 * pread and pwrite are the only calls, read(fd, buf, n) is libc's
 * pread with -1.
 *
 * References: open(2), read(2), bind(2), stat(2) in the Plan 9
 * manual. principia's Kernel.nw (sysfile.c). *)

open Types

val sysopen : proc -> string -> int -> int
(* [syscreate p name mode perm] *)
val syscreate : proc -> string -> int -> int -> int
val sysclose : proc -> int -> int
(* [syspread p fd buf n off]: off None, the channel's own *)
val syspread : proc -> int -> int -> int -> int option -> int
val syspwrite : proc -> int -> int -> int -> int option -> int
(* [sysseek p ret fd lo hi type]: the new offset written at ret (a
 * vlong: 5c's results) *)
val sysseek : proc -> int -> int -> int -> int -> int -> int
val sysdup : proc -> int -> int -> int
val syspipe : proc -> int -> int
(* [sysfd2path p fd buf n] *)
val sysfd2path : proc -> int -> int -> int -> int
(* [sysstat p name buf n], [sysfstat p fd buf n]: the entry, or its
 * size alone when it does not fit *)
val sysstat : proc -> string -> int -> int -> int
val sysfstat : proc -> int -> int -> int -> int
val syswstat : proc -> string -> int -> int -> int
val sysfwstat : proc -> int -> int -> int -> int
val sysremove : proc -> string -> int
val syschdir : proc -> string -> int
(* [sysbind p new old flag] *)
val sysbind : proc -> string -> string -> int -> int
(* [sysmount p fd old flag aname]: the server on fd attached (devmnt) *)
val sysmount : proc -> int -> string -> int -> string -> int
(* [sysunmount p new old]: new a user's string (0: all of old's) *)
val sysunmount : proc -> int -> string -> int
