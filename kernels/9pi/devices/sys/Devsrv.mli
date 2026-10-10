(* '#s', the services (principia's devsrv.c): a file created there
 * and written a descriptor's number posts that descriptor's channel;
 * opening the file gives the channel back (a file server's connection,
 * dossrv's #s/dos, mounted by others).
 *
 *     a server (dossrv)                   anyone, later
 *     pipe(p)
 *     fd = create("/srv/dos", OWRITE, 0666)
 *     write(fd, "4")        p[0] is 4     fd = open("/srv/dos", ORDWR)
 *     close(p[0])                           the same channel as p[0]
 *     reads requests on p[1]              mount(fd, "/mnt/fat", ...)
 *
 * Descriptors are a process's own, inherited at rfork and reached no
 * other way; this is the door between processes that are not
 * related. The file holds a reference to the channel (not to a
 * descriptor's number, which means nothing outside its process), so
 * the server may close its copy and the pipe lives on in /srv. It is
 * a bulletin board more than a device: ls /srv says which servers
 * run on the machine.
 *
 * plan9-is-cleaner:
 * Unix has several mechanisms for this one need: a named pipe when
 * the two only want a stream, a Unix-domain socket with a name in
 * the file system when they want a conversation, and to hand over a
 * descriptor already open a special message on such a socket
 * (SCM_RIGHTS) with its own structures. Here it is create, write,
 * open, and the permission to connect to a server is the file's
 * mode. *)

(* the device registered *)
val init : unit -> unit
