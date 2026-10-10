(* '#|', the pipes (principia's devpipe.c): an attach makes a pipe, a
 * directory of two files, data and data1: what is written on one is
 * read on the other, a stream of up to 32KB each way; a reader waits for
 * data, a writer for room; once an end is closed, the other end's
 * reader gets the end of file, its writer an error.
 *
 *     data  -- write --> [ a queue, 32 KB ] -- read -->  data1
 *     data  <-- read --- [ a queue, 32 KB ] <-- write -- data1
 *
 * The pipe system call is a few lines over this device (Sysfile's
 * syspipe): the name #| walked, which attaches and so makes a pipe,
 * its two files opened to read and write, their descriptors given
 * back. A read takes what there is, up to what was asked, and
 * sleeps only when there is nothing (Pipe_data); a write sleeps
 * while the queue is full (Pipe_room). The two sleeps and the two
 * wakeups are the whole of it: the device to read first for how a
 * device is written (Dev) and how processes wait (Proc).
 *
 * In ix a pipe is also what carries 9P between the kernel and a file
 * server on the same machine (Devmnt), and what a server posts in
 * #s (Devsrv); for the shell's side, and where pipes came from, see
 * shell's Process.
 *
 * others:
 * A Unix pipe goes one way: one descriptor to write, one to read.
 * Plan 9's goes both, each end read and written, which is what a
 * conversation with a server needs and what Unix later asked a
 * socket pair for. And since each pipe is a device's directory with
 * two named files, an end can be bound in a name space or posted in
 * #s, where Unix needed another kind of file, the named pipe. *)

(* the device registered *)
val init : unit -> unit
