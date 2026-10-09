(* The files a window's process sees (Plan 9's rio is a file server:
 * its fsys.c, xfid.c; xix's Fileserver and Threads_fileserver): for
 * each window a directory of files (Device: the console in
 * Virtual_cons, the mouse in Virtual_mouse, the window's own in
 * Dev_wm, its control in Wctl), served over 9P and mounted before /dev
 * in the process's namespace. So a program in a window opens /dev/cons as it would on
 * the bare machine, and talks to the window. *)

(* The file server's thread: [serve requests mine] answers 9P's
 * requests on a pipe's end, [mine] (the other, posted in /srv, is
 * mounted by each window's process, the window's number its mount's
 * spec; rio's own spec new, a window made by the mount, is not here:
 * one mounts a window there is, and writes its wctl). The
 * requests are a Source's messages (a process reads the pipe), cut
 * into 9P's by their sizes. It does not return. *)
val serve : bytes Event.channel -> Unix.file_descr -> unit
