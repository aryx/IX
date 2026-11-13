(* '#e' is the environment (principia's devenv.c). It shows a process's
 * variables as files, which can be created, written and removed. They
 * are the process's Egrp, and rc keeps its variables there, in /env.
 * '#ec' is the kernel's configuration (confegrp). Here it holds only
 * firmware, the firmware's date, which init sets on a board.
 *
 *     rc:  x=hello           create("/env/x"), write "hello"
 *          echo $x           (rc knows it; a child would open /env/x)
 *          ls /env           the variables' names
 *          rm /env/x         the variable removed
 *
 * The device has no tree of its own: its directory is the calling
 * process's Egrp (Types), found at each call. So two processes that open
 * #e/x may read two different files. A child sees its parent's later
 * changes, unless rfork gave it a copy (RFENVG: see [copy]) or an empty
 * environment (RFCENVG). shell's Env is the other side: it says how rc
 * writes a list, and a function, into such a file.
 *
 * plan9-is-cleaner:
 * In Unix the environment is not the kernel's. It is an array of
 * strings that each program holds in its own memory, and that exec
 * copies onto the new program's stack beside its arguments (since the
 * seventh edition, 1979). It is copied at each exec, exec puts limits on
 * its size, and there is no way to see another process's environment
 * except by reading its stack (/proc/n/environ), and no way to change
 * it. Here exec does not know there are variables, a value may be large
 * or binary, and a group of processes may share one set on purpose. *)

open Types

(* registers the device *)
val init : unit -> unit

(* sets a variable of the kernel's configuration, in '#ec' (something
 * the kernel knows and a boot script may want: the firmware's date) *)
val conf_set : string -> string -> unit

(* returns a copy of an environment (RFENVG: envcpy) *)
val copy : egrp -> egrp
