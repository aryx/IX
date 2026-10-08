(* The devices 9pi has and mini-9pi does not yet, as empty directories,
 * so that boot.rc binds them as on 9pi and devtab's order is 9pi's:
 * '#κ' kbmap, '#t' uart. *)

(* each device registered *)
val kbmap : unit -> unit
val uart : unit -> unit
