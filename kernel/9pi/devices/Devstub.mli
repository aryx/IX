(* The devices 9pi has and mini-9pi does not yet, as empty directories,
 * so that boot.rc binds them as on 9pi and devtab's order is 9pi's:
 * '#κ' kbmap, '#l' ether, '#I' IP (stage
 * E; its first attach spends rxmitproc's pid, as 9pi's starts that
 * kernel process), '#t' uart. *)

(* each device registered *)
val kbmap : unit -> unit
val ether : unit -> unit
val ip : unit -> unit
val uart : unit -> unit
