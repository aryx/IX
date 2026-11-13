(* '#M' is the mount driver (principia's devmnt.c). It shows the files
 * of a 9P server (dossrv, ramfs, rio...) as channels, each one a fid. A
 * mount is a connection plus its 9P session. The connection is a channel
 * to the server (#s/dos, a pipe's end); the session is a Tversion once,
 * then an attach for each mount. A remote file's walk, open, read and so
 * on are each an RPC on it. Replies come back in any order: one process
 * at a time reads the connection and hands each reply to the process
 * that waits for its tag (mountmux).
 *
 *     cat (a program)      the kernel                 dossrv (a program)
 *     read(fd, buf, n)
 *       Sysfile.syspread
 *         Dev 'M'.read
 *           rpc: T Read written on the connection
 *                (a pipe's end: Devpipe.write) - - -> read: a request
 *           the reply read from it                    Fat: the bytes
 *                (Devpipe.read: cat sleeps)   <- - -  write: R Read
 *         the bytes, into buf
 *     n
 *
 * This device is Dev's record filled with one idea: each function is
 * its 9P message (P9 has the messages of an open and a read). It is all
 * that the kernel knows of file servers, and it knows nothing of what
 * they serve: a FAT, a window's text and another machine's files are
 * all a connection and a session here. The connection is any channel
 * that carries bytes both ways, which is why a server can be local (a
 * pipe, posted in #s: Devsrv) or remote (a TCP connection's data file:
 * Devip) with no line of difference.
 *
 * Here is how two processes share one connection. A sends tag 1 and
 * reads the connection; B sends tag 2, finds A reading, and sleeps
 * (Mnt_reply). The server answers 2 first. A reads it, sees that it is
 * not its own, keeps it in the session's replies, wakes the sleepers,
 * and looks again: B takes its reply and goes, and A reads on. No
 * process is the reader by office; whoever waits does the reading for
 * all.
 *
 * reframe:
 * A file system is a program. In Unix it is kernel code behind an
 * interface of functions (the vnode, Sun's since 1986; Linux's VFS), and
 * a new file system is a kernel module, with the kernel's powers and the
 * kernel's bugs. Here the kernel has this one client, and a new file
 * system is whatever program answers thirteen messages, in any
 * language, started and killed by a user. Linux got there by another
 * door in 2005: FUSE, a device that a program reads requests from, which
 * is this file with another protocol.
 *
 * wib:
 * Each read and each walk costs two messages and two changes of
 * process, where in a file system inside the kernel it is a function
 * call. 9pi softens this with a cache of the files' pages (MCACHE, which
 * is not here). ix has the other way to compare with: the same FAT code
 * in the kernel (Kdos). And some fids are never given back (plan_9pi.md:
 * fids leaked).
 *
 * References: mnt(3) in the Plan 9 manual. principia's Kernel.nw
 * (devmnt.c: mountrpc, mountio, mountmux). S. R. Kleiman, "Vnodes:
 * An Architecture for Multiple File System Types in Sun UNIX"
 * (USENIX Summer 1986), for the other door. *)

open Types
open Errors

(* [attach c aname] attaches the server on c (with a Tversion the first
 * time, then a Tattach), and returns its root's channel (for sysmount) *)
val attach : chan -> string -> chan

(* sends a Tauth (for fauth); the server's refusal (dossrv needs no
 * authentication) is raised as Error *)
val auth : chan -> string -> chan

(* sends a Tversion (for fversion), and returns the message size agreed *)
val version : chan -> int -> string -> int

(* registers the device *)
val init : unit -> unit
