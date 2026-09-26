(* '#S', the disks (principia's devsd.c) with its one controller, the
 * SD card (Emmc: sdmmc's sdM): #S/sdctl, #S/sdM0/ctl (the card's
 * inquiry, registers, geometry, partitions; written "part name start
 * end", "delpart name"), raw, and the partitions ("data" the whole card,
 * boot.rc adds "dos"), each read and written by blocks (sdbio). The
 * card brought online at its first use. *)

(* the controller reset (sdreset) and the device registered *)
val init : unit -> unit
