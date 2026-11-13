(* The devices that 9pi has and mini-9pi does not have yet, as empty
 * directories. They are here so that boot.rc binds them as it does on
 * 9pi, and so that devtab's order is 9pi's: '#κ' is kbmap and '#t' is
 * uart. *)

(* each registers its device *)
val kbmap : unit -> unit
val uart : unit -> unit
