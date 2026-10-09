(* A window's process (rio's processes_winshell.c; xix's
 * Processes_winshell): rc, in a namespace of its own where the
 * window's files are before /dev's, so its console is the window. *)

(* [start caps w served]: a process started for the window (w.pid is
 * its number); [served] is the pipe's end it mounts, the window's
 * number the mount's spec. rio mounts on /mnt/wsys and binds that
 * before /dev; here the mount is before /dev itself *)
val start : < Cap.fork; Cap.exec; Cap.mount; Cap.open_in; Cap.open_out; .. > -> Window.t -> Unix.file_descr -> unit
(* a note for the window's processes ("interrupt", "hangup"): their
 * note group's file is written *)
val note : < Cap.open_out; .. > -> Window.t -> string -> unit
