(* The files a window's process sees (Plan 9's rio is a file server:
 * its fsys.c, xfid.c; xix's Fileserver and Threads_fileserver): for
 * each window a directory with its console, served over 9P and
 * mounted before /dev in the process's namespace. So a program in a
 * window opens /dev/cons as it would on the bare machine, and talks
 * to the window. cons and consctl, for now. *)

type file

(* the file system, over the windows by their numbers (a mount's spec) *)
val fs : (int -> Window.t option) -> file P9_server.fs
