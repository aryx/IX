(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Usbdev.mli *)

type t = { name : string; id : int; ctl : Unix.file_descr; mutable data : Unix.file_descr option }

type caps = < Cap.open_in; Cap.open_out >

let dir = "#u/usb/"

(* the kernel's refusal, as a Failure *)
let failing f = try f () with Unix.Unix_error (e, _, _) -> failwith (Unix.error_message e)

let open_ (caps : < caps; .. >) name =
  (* (ep3.0: the device of number 3) *)
  let id = int_of_string (String.sub name 2 (String.index name '.' - 2)) in
  { name; id; ctl = failing (fun () -> FS.open_rw_fd caps (dir ^ name ^ "/ctl")); data = None }

let open_data (caps : < caps; .. >) (d : t) mode =
  let file = dir ^ d.name ^ "/data" in
  d.data <- Some (failing (fun () -> if mode = 0 then FS.open_in_fd caps file else FS.open_rw_fd caps file))

let close (d : t) =
  Unix.close d.ctl;
  Option.iter Unix.close d.data

let ctl (d : t) line = failing (fun () -> ignore (Unix.write_substring d.ctl line 0 (String.length line)))

let said (d : t) =
  let b = Bytes.create 256 in
  failing (fun () -> ignore (Unix.lseek d.ctl 0 Unix.SEEK_SET); Bytes.sub_string b 0 (Unix.read d.ctl b 0 256))

let data (d : t) = match d.data with Some fd -> fd | None -> failwith (d.name ^ ": data not open")

let send (d : t) kind request value index more =
  let s = Usbdesc.setup kind request value index (String.length more) ^ more in
  failing (fun () -> ignore (Unix.write_substring (data d) s 0 (String.length s)))

let ask (d : t) kind request value index count =
  let s = Usbdesc.setup (kind lor 0x80) request value index count in
  let b = Bytes.create count in
  failing (fun () -> ignore (Unix.write_substring (data d) s 0 8); Bytes.sub_string b 0 (Unix.read (data d) b 0 count))
