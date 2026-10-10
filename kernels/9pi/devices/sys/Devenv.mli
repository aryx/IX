(* '#e', the environment (principia's devenv.c): a process's variables
 * as files (its Egrp: rc keeps its variables there, /env), created,
 * written, removed; '#ec' the kernel's configuration (confegrp: empty
 * here).
 *
 *     rc:  x=hello           create("/env/x"), write "hello"
 *          echo $x           (rc knows it; a child would open /env/x)
 *          ls /env           the variables' names
 *          rm /env/x         the variable removed
 *
 * The device has no tree of its own: its directory is the calling
 * process's Egrp (Types), found at each call. So two processes that
 * open #e/x may read two files, and a child sees its parent's later
 * changes unless rfork gave it a copy (RFENVG: [copy]) or an empty
 * one (RFCENVG). shell's Env is the other side: how rc writes a
 * list, and a function, into such a file.
 *
 * plan9-is-cleaner:
 * In Unix the environment is not the kernel's: it is an array of
 * strings each program holds in its own memory, that exec copies
 * onto the new program's stack beside its arguments (since the
 * seventh edition, 1979). A copy at each exec, limits on its size
 * that are exec's, no way to see another process's but by reading
 * its stack (/proc/n/environ), none to change it. Here exec does not
 * know there are variables, a value may be large or binary, and a
 * group of processes may share one set on purpose. *)

open Types

(* the device registered *)
val init : unit -> unit

(* a copy of an environment (RFENVG: envcpy) *)
val copy : egrp -> egrp
