(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Usbdev.mli *)

type t = { name : string; id : int; ctl : Unix.file_descr; mutable data : Unix.file_descr option }

type caps = < Cap.open_in; Cap.open_out >

let dir = "#u/usb/"

let open_ (caps : < caps; .. >) name =
  (* (ep3.0: the device of number 3) *)
  let id = int_of_string (String.sub name 2 (String.index name '.' - 2)) in
  { name; id; ctl = FS.open_rw_fd caps (dir ^ name ^ "/ctl"); data = None }

let open_data (caps : < caps; .. >) (d : t) mode =
  let file = dir ^ d.name ^ "/data" in
  d.data <- Some (if mode = 0 then FS.open_in_fd caps file else FS.open_rw_fd caps file)

let close (d : t) =
  Unix.close d.ctl;
  Option.iter Unix.close d.data

let ctl (d : t) line = ignore (Unix.write_substring d.ctl line 0 (String.length line))

let said (d : t) =
  let b = Bytes.create 256 in
  ignore (Unix.lseek d.ctl 0 Unix.SEEK_SET);
  Bytes.sub_string b 0 (Unix.read d.ctl b 0 256)

let data (d : t) = match d.data with Some fd -> fd | None -> failwith (d.name ^ ": data not open")

(* a request's 8 bytes: its kind, its number, a value, an index, how many bytes follow *)
let setup kind request value index count =
  let b = Bytes.create 8 in
  Binary.set_u8 b 0 kind; Binary.set_u8 b 1 request;
  Binary.set_le16 b 2 value; Binary.set_le16 b 4 index; Binary.set_le16 b 6 count;
  Bytes.to_string b

let send (d : t) kind request value index more =
  let s = setup kind request value index (String.length more) ^ more in
  ignore (Unix.write_substring (data d) s 0 (String.length s))

let ask (d : t) kind request value index count =
  let s = setup (kind lor 0x80) request value index count in
  ignore (Unix.write_substring (data d) s 0 8);
  let b = Bytes.create count in
  Bytes.sub_string b 0 (Unix.read (data d) b 0 count)

type endpoint = { number : int; input : bool; kind : int; maxpkt : int; interval : int }
type interface = { iface : int; cls : int; sub : int; proto : int; endpoints : endpoint list }

(* The descriptors one after the other, each its length and its type:
 * an interface's (4), then its endpoints' (5); the others passed over
 * (a HID's own, a hub's). *)
let interfaces s =
  let byte o = Binary.u8 s o in
  let rec go o (found : interface list) =
    if o + 2 > String.length s || byte o < 2 || o + byte o > String.length s then List.rev found
    else begin
      let next = o + byte o in
      match byte (o + 1), found with
      | 4, _ when byte o >= 9 ->
          go next ({ iface = byte (o + 2); cls = byte (o + 5); sub = byte (o + 6); proto = byte (o + 7); endpoints = [] } :: found)
      | 5, last :: before when byte o >= 7 ->
          let e = { number = byte (o + 2) land 0xf; input = byte (o + 2) land 0x80 <> 0; kind = byte (o + 3) land 3;
                    maxpkt = Binary.le16 s (o + 4) land 0x7ff; interval = byte (o + 6) } in
          go next ({ last with endpoints = last.endpoints @ [ e ] } :: before)
      | _ -> go next found
    end in
  go 0 []
