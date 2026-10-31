(* A window's process (rio's processes_winshell.c; xix's
 * Processes_winshell): rc, in a namespace of its own where the
 * window's files are before /dev's, so its console is the window. *)

(* [start caps w srv ~cd command]: a process started for the window (w.pid
 * is its number), in the directory [cd] when it is not "": rc, or rc -c
 * command when one is said. [srv] is the
 * window system's file in /srv, which it mounts, the window's number
 * the mount's spec: on /mnt/wsys, bound before /dev, as rio (where
 * there is no /mnt/wsys: before /dev itself). Its $wsys is srv: what
 * another process mounts to reach the windows' files *)
val start : < Cap.chdir; Cap.fork; Cap.exec; Cap.mount; Cap.bind; Cap.open_in; Cap.open_out; .. > -> Window.t -> string -> cd:string -> string -> unit
(* [init caps srv command]: rio -i's: rc -c command in a process with no
 * window. Before its /dev, the root of the window system's files (the
 * empty spec): a wctl, for new, and wsys. Its console is the one rio
 * was started from *)
val init : < Cap.fork; Cap.exec; Cap.mount; Cap.bind; Cap.open_in; Cap.open_out; .. > -> string -> string -> unit
(* a note for the window's processes ("interrupt", "hangup"): their
 * note group's file is written *)
val note : < Cap.open_out; .. > -> Window.t -> string -> unit
