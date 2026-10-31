(* A window's process (rio's processes_winshell.c; xix's
 * Processes_winshell): rc, in a namespace of its own where the
 * window's files are before /dev's, so its console is the window. *)

(* [start caps w srv command]: a process started for the window (w.pid
 * is its number): rc, or rc -c command when one is said. [srv] is the
 * window system's file in /srv, which it mounts, the window's number
 * the mount's spec: on /mnt/wsys, bound before /dev, as rio (where
 * there is no /mnt/wsys: before /dev itself). Its $wsys is srv: what
 * another process mounts to reach the windows' files *)
val start : < Cap.fork; Cap.exec; Cap.mount; Cap.bind; Cap.open_in; Cap.open_out; .. > -> Window.t -> string -> string -> unit
(* a note for the window's processes ("interrupt", "hangup"): their
 * note group's file is written *)
val note : < Cap.open_out; .. > -> Window.t -> string -> unit
