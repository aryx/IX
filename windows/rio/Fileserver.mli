(* The files a window's process sees (Plan 9's rio is a file server: its
 * fsys.c, xfid.c; xix's Fileserver and Threads_fileserver). Each
 * window has a directory of files, each a Device:
 * - the console, in Virtual_cons;
 * - the mouse, in Virtual_mouse;
 * - the window's own files, in Dev_wm;
 * - its control file, in Wctl.
 * The directory is served over 9P and mounted before /dev in the
 * process's namespace. So a program in a window opens /dev/cons as it
 * would on the bare machine, and it talks to the window. *)

(* The file server's thread. [serve requests mine] answers 9P's
 * requests on one end of a pipe, [mine]. The other end is posted in
 * /srv, and each window's process mounts it with the window's number
 * as the mount's spec. The empty spec gives the root, which -i's
 * process has: a wctl, for new, and wsys. rio's own spec new, which
 * makes a window by the mount, is not here: a program mounts a window
 * that exists, and writes its wctl.
 *
 * Each window's directory has wsys too, as rio's does. It holds a
 * directory for each window, named by its number, with that window's
 * files: this is how a program finds the windows there are.
 *
 * The requests come as a Source's messages (a process reads the pipe),
 * and they are cut into 9P's messages by their sizes. [serve] does not
 * return. *)
val serve : bytes Event.channel -> Unix.file_descr -> unit
