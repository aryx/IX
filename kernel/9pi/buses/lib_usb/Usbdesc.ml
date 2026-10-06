(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Usbdesc.mli *)

let le16 s o = Char.code s.[o] lor (Char.code s.[o + 1] lsl 8)

let setup kind request value index count =
  let b v = String.make 1 (Char.chr (v land 0xff)) in
  b kind ^ b request ^ b value ^ b (value lsr 8) ^ b index ^ b (index lsr 8) ^ b count ^ b (count lsr 8)

type endpoint = { number : int; input : bool; kind : int; maxpkt : int; interval : int }
type interface = { iface : int; cls : int; sub : int; proto : int; endpoints : endpoint list }

(* The descriptors one after the other, each its length and its type:
 * an interface's (4), then its endpoints' (5); the others passed over
 * (a HID's own, a hub's). *)
let interfaces s =
  let byte o = Char.code s.[o] in
  let rec go o found =
    if o + 2 > String.length s || byte o < 2 || o + byte o > String.length s then List.rev found
    else begin
      let next = o + byte o in
      match byte (o + 1), found with
      | 4, _ when byte o >= 9 ->
          go next ({ iface = byte (o + 2); cls = byte (o + 5); sub = byte (o + 6); proto = byte (o + 7); endpoints = [] } :: found)
      | 5, last :: before when byte o >= 7 ->
          let e = { number = byte (o + 2) land 0xf; input = byte (o + 2) land 0x80 <> 0; kind = byte (o + 3) land 3;
                    maxpkt = le16 s (o + 4) land 0x7ff; interval = byte (o + 6) } in
          go next ({ last with endpoints = last.endpoints @ [ e ] } :: before)
      | _ -> go next found
    end in
  go 0 []
