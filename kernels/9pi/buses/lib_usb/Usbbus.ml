(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Usbbus.mli *)

open Usbdesc

type 'd io = {
  name : 'd -> string;
  number : 'd -> int;
  send : 'd -> int -> int -> int -> int -> string -> unit;
  ask : 'd -> int -> int -> int -> int -> int -> string;
  set : 'd -> string -> unit;
  child : 'd -> string -> int -> 'd;
  drop : 'd -> unit;
  pause : int -> unit;
  drive : 'd -> Hid.kind -> Usbdesc.endpoint -> unit;
  say : string -> unit;
}

(* a hub: its device, and for each port (from 1) what is there *)
type 'd hub = { dev : 'd; ports : 'd port array }
and 'd port = { mutable present : bool; mutable device : 'd option; mutable below : 'd hub option }

let verbose = ref false

type 'd t = { io : 'd io; mutable hubs : 'd hub list }

(* requests to a hub about a port (a class's, "other": 0x23): a
 * feature set or cleared (1 the port enabled, 4 reset, 8 powered); its
 * status, bits (1 a device is there, 2 enabled, 0x200 a slow one,
 * 0x400 a fast one) *)
let feature t h p f on = try t.io.send h.dev 0x23 (if on then 3 else 1) f p "" with Failure _ -> ()
let status t h p = try (let s = t.io.ask h.dev 0x23 0 0 p 4 in if String.length s < 2 then -1 else le16 s 0) with Failure _ -> -1

let add_hub t dev nports =
  t.io.set dev "hub";
  let h = { dev = dev; ports = Array.init (nports + 1) (fun _ -> { present = false; device = None; below = None }) } in
  t.hubs <- t.hubs @ [ h ];
  h

let start io root nports =
  let t = { io = io; hubs = [] } in
  ignore (add_hub t root nports);
  t

(* a real hub: how many ports (its descriptor: a class's request to
 * the device, 0x20; type 0x29), each one powered *)
let hub t dev =
  let d = t.io.ask dev 0x20 6 0x2900 0 64 in
  if String.length d < 7 then failwith "hub: descriptor too small";
  let h = add_hub t dev (Char.code d.[2]) in
  if !verbose then t.io.say (Printf.sprintf "usb: %s: a hub of %d ports\n" (t.io.name dev) (Char.code d.[2]));
  for p = 1 to Array.length h.ports - 1 do feature t h p 8 true done;
  t.io.pause (max 100 (2 * Char.code d.[5]));
  h

let forget t h p =
  let port = h.ports.(p) in
  let gone d = (try t.io.set d "detach" with Failure _ -> ()); t.io.drop d in
  (* (what was below a hub that is gone, first) *)
  let rec under below =
    Array.iter (fun q -> Option.iter under q.below; Option.iter gone q.device) below.ports;
    t.hubs <- List.filter (fun x -> x != below) t.hubs in
  Option.iter under port.below;
  Option.iter gone port.device;
  port.device <- None;
  port.below <- None

(* A device at a port: reset, numbered, asked what it is, started. *)
let attach t h p =
  let io = t.io and port = h.ports.(p) in
  io.pause 100;
  feature t h p 1 true;
  io.pause 20;
  feature t h p 4 true;
  (* (a real hub's reset is some 10ms, and the device is given 10 more
   * before its first request; an emulator's is at once.
   * old: io.pause 20) *)
  io.pause 100;
  let sts = status t h p in
  if !verbose then io.say (Printf.sprintf "usb: %s port %d: status 0x%x\n" (io.name h.dev) p sts);
  if sts < 0 || sts land 2 = 0 then failwith "not enabled";
  let d = io.child h.dev (if sts land 0x400 <> 0 then "high" else if sts land 0x200 <> 0 then "low" else "full") p in
  port.device <- Some d;
  (* its address (SET_ADDRESS 5), said to the kernel too *)
  io.send d 0 5 (io.number d) 0 "";
  io.set d "address";
  (* (a device is given 2ms to change its address) *)
  io.pause 10;
  (* its descriptor (GET_DESCRIPTOR 6; 1 the device's: byte 4 its
   * class, byte 7 the largest packet of its endpoint 0), then its
   * configuration's (2: its 9 bytes say how long all of it is) *)
  let desc = io.ask d 0 6 0x0100 0 18 in
  if String.length desc < 8 then failwith "device descriptor too small";
  io.set d (Printf.sprintf "maxpkt %d" (Char.code desc.[7]));
  let conf = io.ask d 0 6 0x0200 0 9 in
  let conf = io.ask d 0 6 0x0200 0 (if String.length conf >= 4 then le16 conf 2 else 9) in
  let all = interfaces conf in
  if !verbose then
    io.say (Printf.sprintf "usb: %s: class %d, vendor %04x product %04x, configuration of %d bytes, interfaces of class%s\n" (io.name d)
              (Char.code desc.[4]) (if String.length desc >= 12 then le16 desc 8 else 0)
              (if String.length desc >= 12 then le16 desc 10 else 0) (String.length conf)
              (String.concat "" (List.map (fun i -> Printf.sprintf " %d" i.cls) all)));
  (* the configuration chosen: the first (SET_CONFIGURATION 9) *)
  io.send d 0 9 1 0 "";
  if Char.code desc.[4] = 9 || List.exists (fun i -> i.cls = 9) all then begin
    io.say "usb/hub... ";
    port.below <- Some (hub t d)
  end
  else
    List.iter (fun i ->
      match Hid.driven i with
      | Some (kind, e) ->
          (* the boot protocol (a class's request to the interface:
           * 0x21; SET_PROTOCOL 0x0b, 0), and how often it says its
           * state unasked (SET_IDLE 0x0a) *)
          io.send d 0x21 0x0b 0 i.iface "";
          (try io.send d 0x21 0x0a (Hid.idle kind lsl 8) i.iface "" with Failure _ -> ());
          io.drive d kind e;
          io.say "usb/kb... "
      | None -> ()) all

let look t =
  let changed = ref false in
  (* (the hubs found on the way are looked at too: the list grows) *)
  let rec each k =
    match List.nth_opt t.hubs k with
    | None -> ()
    | Some h ->
        for p = 1 to Array.length h.ports - 1 do
          let port = h.ports.(p) in
          let sts = status t h p in
          let present = sts >= 0 && sts land 1 <> 0 in
          if present && not port.present then begin
            changed := true;
            (try attach t h p with Failure m -> t.io.say (Printf.sprintf "usb: %s port %d: %s\n" (t.io.name h.dev) p m); forget t h p)
          end
          else if port.present && not present then begin changed := true; forget t h p end;
          port.present <- present
        done;
        each (k + 1) in
  each 0;
  !changed
