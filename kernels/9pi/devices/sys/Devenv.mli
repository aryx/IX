(* '#e', the environment (principia's devenv.c): a process's variables
 * as files (its Egrp: rc keeps its variables there, /env), created,
 * written, removed; '#ec' the kernel's configuration (confegrp: empty
 * here). *)

open Types

(* the device registered *)
val init : unit -> unit

(* a copy of an environment (RFENVG: envcpy) *)
val copy : egrp -> egrp
