(* A window's process (rio's processes_winshell.c; xix's
 * Processes_winshell): rc, in a namespace of its own where the
 * window's files are before /dev's, so its console is the window. *)

(* [start caps w srv ~cd command] starts a process for the window (w.pid
 * is set to its number), in the directory [cd] when it is not "". It
 * runs rc, or rc -c command when a command is given. [srv] is the
 * window system's file in /srv, which the process mounts with the
 * window's number as the mount's spec. As in rio, the mount is on
 * /mnt/wsys, bound before /dev (where there is no /mnt/wsys, it is
 * mounted before /dev itself). The process's $wsys is srv: what
 * another process mounts to reach the windows' files. *)
val start : < Cap.chdir; Cap.fork; Cap.exec; Cap.mount; Cap.bind; Cap.open_in; Cap.open_out; .. > -> Window.t -> string -> cd:string -> string -> unit
(* [init caps srv command] does rio -i's job: it runs rc -c command in
 * a process with no window. Before that process's /dev is the root of
 * the window system's files (the empty spec): a wctl, for new, and
 * wsys. Its console is the one rio was started from. *)
val init : < Cap.fork; Cap.exec; Cap.mount; Cap.bind; Cap.open_in; Cap.open_out; .. > -> string -> string -> unit
(* sends a note to the window's processes ("interrupt", "hangup") by
 * writing their note group's file *)
val note : < Cap.open_out; .. > -> Window.t -> string -> unit
