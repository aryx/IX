(* '#|' makes the pipes (principia's devpipe.c). An attach makes a pipe,
 * which is a directory of two files, data and data1. What is written on
 * one is read on the other, as a stream of up to 32KB in each direction.
 * A reader waits for data, and a writer waits for room. Once an end is
 * closed, the reader of the other end gets the end of file, and its
 * writer gets an error.
 *
 *     data  -- write --> [ a queue, 32 KB ] -- read -->  data1
 *     data  <-- read --- [ a queue, 32 KB ] <-- write -- data1
 *
 * The pipe system call is a few lines over this device (Sysfile's
 * syspipe). It walks the name #|, which attaches and so makes a pipe,
 * opens its two files to read and write, and gives their descriptors
 * back. A read takes what there is, up to what was asked, and sleeps
 * only when there is nothing (Pipe_data); a write sleeps while the queue
 * is full (Pipe_room). The two sleeps and the two wakeups are the whole
 * of it. That makes this the device to read first, for how a device is
 * written (Dev) and how processes wait (Proc).
 *
 * In ix a pipe is also what carries 9P between the kernel and a file
 * server on the same machine (Devmnt), and what a server posts in #s
 * (Devsrv). For the shell's side, and for where pipes came from, see
 * shell's Process.
 *
 * others:
 * A Unix pipe goes one way, with one descriptor to write and one to
 * read. Plan 9's pipe goes both ways, and each end is read and written.
 * That is what a conversation with a server needs, and what Unix later
 * asked a socket pair for. And since each pipe is a device's directory
 * with two named files, an end can be bound in a name space or posted in
 * #s, where Unix needed another kind of file, the named pipe. *)

(* registers the device *)
val init : unit -> unit
