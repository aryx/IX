(* The files' system calls (principia's sysfile.c): open, create,
 * close, pread, pwrite, seek, dup, pipe, fd2path, stat, fstat, wstat,
 * fwstat, remove and chdir; and the namespace's: bind, mount and
 * unmount. Names are the user's strings, already read (Systab), and
 * buffers are the user's addresses.
 *
 * Each call is a few lines, because the work is done by Kchan (from a
 * name to a channel, from a descriptor to a channel) and then by the
 * device (Dev):
 *
 *     open(name, mode)    Kchan.namec finds the channel through the
 *                         name space; the device's open_ opens it;
 *                         Kchan.fdalloc gives the first free descriptor
 *     pread(fd, buf, n, off)
 *                         Kchan.fdtochan gives the channel, open to
 *                         read; the device reads at off (-1 means the
 *                         channel's own offset, which then moves);
 *                         Usermem.user_write copies the bytes
 *     close(fd)           the descriptor is freed; when the channel's
 *                         last holder lets go, the device closes it
 *     bind(new, old, f)   two namec's, then Kchan.bind
 *     mount(fd, old, f)   Devmnt.attach on fd's channel, Kchan.bind
 *
 * A directory is read as a file: the read returns its entries in their
 * wire form (Dev.encode), as many whole ones as fit. ls is open, read
 * and close.
 *
 * plan9-is-cleaner:
 * What is not here is missing because a file does it. There is no
 * ioctl (Dev). There is no mknod, link, symlink or readlink: a name
 * space is made of binds, which belong to a process and vanish with
 * it, where a link is a fact written on a disk. There is no chmod,
 * chown, utime, truncate or rename: each is a wstat, an entry sent
 * back with the fields to change. There is no mkdir: it is a create
 * with the directory bit (utilities' Mkdir). There is no socket,
 * connect or accept (Devip), and no select or poll: a program that
 * waits on two files makes two processes, which rfork's shared memory
 * makes cheap. And read and write keep no separate offset: pread and
 * pwrite are the only calls, and libc's read(fd, buf, n) is pread with
 * -1.
 *
 * References: open(2), read(2), bind(2), stat(2) in the Plan 9
 * manual. principia's Kernel.nw (sysfile.c). *)

open Types

val sysopen : proc -> string -> int -> int
(* [syscreate p name mode perm] *)
val syscreate : proc -> string -> int -> int -> int
val sysclose : proc -> int -> int
(* [syspread p fd buf n off]: when off is None, the channel's own
 * offset is used *)
val syspread : proc -> int -> int -> int -> int option -> int
val syspwrite : proc -> int -> int -> int -> int option -> int
(* [sysseek p ret fd lo hi type] writes the new offset at ret, because
 * it is a vlong and 5c returns a vlong result that way *)
val sysseek : proc -> int -> int -> int -> int -> int -> int
val sysdup : proc -> int -> int -> int
val syspipe : proc -> int -> int
(* [sysfd2path p fd buf n] *)
val sysfd2path : proc -> int -> int -> int -> int
(* [sysstat p name buf n] and [sysfstat p fd buf n] write the entry,
 * or only its size when it does not fit *)
val sysstat : proc -> string -> int -> int -> int
val sysfstat : proc -> int -> int -> int -> int
val syswstat : proc -> string -> int -> int -> int
val sysfwstat : proc -> int -> int -> int -> int
val sysremove : proc -> string -> int
val syschdir : proc -> string -> int
(* [sysbind p new old flag] *)
val sysbind : proc -> string -> string -> int -> int
(* [sysmount p fd old flag aname] attaches the server on fd (devmnt) *)
val sysmount : proc -> int -> string -> int -> string -> int
(* [sysunmount p new old]: new is the address of a user's string, or
 * 0 to unmount all of old's union *)
val sysunmount : proc -> int -> string -> int
