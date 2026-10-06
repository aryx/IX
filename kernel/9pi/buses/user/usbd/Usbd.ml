(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* mini-usbd: the USB devices found and started (Plan 9's usbd, with
 * its kb: principia's kernel/buses/user/usb/usbd and kb), written
 * anew for what ix has: hubs, keyboards and mice.
 *
 * The kernel has the controller, and gives each endpoint as files
 * (#u: Usbdev); it knows no device. So a program does what is called
 * the enumeration. It starts at the root hub, the controller's own
 * (ep1.0), and for each hub looks at its ports, by requests to the
 * hub. At a port where something is plugged: the port is reset (the
 * device then listens at address 0), the kernel is asked for a new
 * device there ("newdev": its ep N.0), the device is told its address
 * (N), and asked what it is. A hub is one more hub to look at; a
 * keyboard or a mouse gets its process (Hid).
 *
 *     usbd        started by the boot script: when it returns, the
 *                 keyboard and the mouse found are working
 *
 * It returns after it has looked at every port once; a process stays
 * and looks again four times a second: a device plugged later is
 * found, one unplugged is forgotten.
 *
 * Not usbd's other drivers (disks, serial lines, audio, ethernet: the
 * kernel has ethernet), nor its file server for drivers that are
 * other programs. *)

type caps = < Hid.caps; Cap.stderr >

(* a hub: its device, and for each port (from 1) what is there *)
type hub = { dev : Usbdev.t; ports : port array }
and port = { mutable present : bool; mutable device : Usbdev.t option; mutable below : hub option }

let hubs : hub list ref = ref []

(* requests to a hub about a port (a class's, "other": 0x23): a
 * feature set or cleared (1 the port enabled, 4 reset, 8 powered); its
 * status, bits (1 a device is there, 2 enabled, 0x200 a slow one,
 * 0x400 a fast one) *)
let feature (h : hub) p f on = try Usbdev.send h.dev 0x23 (if on then 3 else 1) f p "" with Unix.Unix_error _ -> ()
let status (h : hub) p = try (let s = Usbdev.ask h.dev 0x23 0 0 p 4 in if String.length s < 2 then -1 else Binary.le16 s 0) with Unix.Unix_error _ -> -1

let pause ms = Unix.sleepf (float ms /. 1000.)

let add_hub (dev : Usbdev.t) nports =
  Usbdev.ctl dev "hub";
  let h = { dev; ports = Array.init (nports + 1) (fun _ -> { present = false; device = None; below = None }) } in
  hubs := !hubs @ [ h ];
  h

(* a real hub: how many ports (its descriptor: a class's request to
 * the device, 0x20; type 0x29), each one powered *)
let hub (dev : Usbdev.t) =
  let d = Usbdev.ask dev 0x20 6 0x2900 0 64 in
  if String.length d < 7 then failwith "hub: descriptor too small";
  let h = add_hub dev (Binary.u8 d 2) in
  for p = 1 to Array.length h.ports - 1 do feature h p 8 true done;
  pause (max 100 (2 * Binary.u8 d 5));
  h

let forget (h : hub) p =
  let port = h.ports.(p) in
  (* (what was below a hub that is gone, first) *)
  let rec gone (below : hub) =
    Array.iter (fun (q : port) -> Option.iter gone q.below; Option.iter (fun (d : Usbdev.t) -> (try Usbdev.ctl d "detach" with Unix.Unix_error _ -> ()); Usbdev.close d) q.device) below.ports;
    hubs := List.filter (fun x -> x != below) !hubs in
  Option.iter gone port.below;
  Option.iter (fun (d : Usbdev.t) -> (try Usbdev.ctl d "detach" with Unix.Unix_error _ -> ()); Usbdev.close d) port.device;
  port.device <- None;
  port.below <- None

(* A device at a port: reset, numbered, asked what it is, started. *)
let attach (caps : < caps; .. >) (h : hub) p =
  let port = h.ports.(p) in
  pause 100;
  feature h p 1 true;
  pause 20;
  feature h p 4 true;
  pause 20;
  let sts = status h p in
  if sts < 0 || sts land 2 = 0 then failwith (Printf.sprintf "port %d: not enabled" p);
  let speed = if sts land 0x400 <> 0 then "high" else if sts land 0x200 <> 0 then "low" else "full" in
  (* the kernel's files for it: the name is read where the line was written *)
  Usbdev.ctl h.dev (Printf.sprintf "newdev %s %d" speed p);
  let d = Usbdev.open_ caps (Usbdev.said h.dev) in
  port.device <- Some d;
  Usbdev.open_data caps d 2;
  (* its address (SET_ADDRESS 5), said to the kernel too *)
  Usbdev.send d 0 5 d.id 0 "";
  Usbdev.ctl d "address";
  (* its descriptor (GET_DESCRIPTOR 6; 1 the device's: byte 4 its
   * class, byte 7 the largest packet of its endpoint 0), then its
   * configuration's (2: its 9 bytes say how long all of it is) *)
  let desc = Usbdev.ask d 0 6 0x0100 0 18 in
  if String.length desc < 8 then failwith "device descriptor too small";
  Usbdev.ctl d (Printf.sprintf "maxpkt %d" (Binary.u8 desc 7));
  let conf = Usbdev.ask d 0 6 0x0200 0 9 in
  let conf = Usbdev.ask d 0 6 0x0200 0 (if String.length conf >= 4 then Binary.le16 conf 2 else 9) in
  let interfaces = Usbdev.interfaces conf in
  (* the configuration chosen: the first (SET_CONFIGURATION 9) *)
  Usbdev.send d 0 9 1 0 "";
  (* (what is started is said, as usbd says it) *)
  if Binary.u8 desc 4 = 9 || List.exists (fun (i : Usbdev.interface) -> i.cls = 9) interfaces then begin
    Console.eprint caps "usb/hub... ";
    port.below <- Some (hub d)
  end
  else List.iter (fun i -> if Hid.start caps d i then Console.eprint caps "usb/kb... ") interfaces

(* every port of every hub looked at, the new hubs' too; true when something changed *)
let look (caps : < caps; .. >) =
  let changed = ref false in
  let rec each k =
    match List.nth_opt !hubs k with
    | None -> ()
    | Some h ->
        for p = 1 to Array.length h.ports - 1 do
          let port = h.ports.(p) in
          let sts = status h p in
          let present = sts >= 0 && sts land 1 <> 0 in
          if present && not port.present then begin
            changed := true;
            (try attach caps h p with
             | Failure m -> Console.eprint caps (Printf.sprintf "usbd: %s port %d: %s\n" h.dev.name p m); forget h p
             | Unix.Unix_error (e, _, _) -> Console.eprint caps (Printf.sprintf "usbd: %s port %d: %s\n" h.dev.name p (Unix.error_message e)); forget h p)
          end
          else if port.present && not present then begin changed := true; forget h p end;
          port.present <- present
        done;
        each (k + 1) in
  each 0;
  !changed

let main (caps : < caps; .. >) : Exit.t =
  match Usbdev.open_ caps "ep1.0" with
  | exception Unix.Unix_error (e, _, _) -> Console.eprint caps (Printf.sprintf "usbd: #u/usb/ep1.0: %s\n" (Unix.error_message e)); Exit.Err "no usb"
  | root ->
      Usbdev.open_data caps root 2;
      (* the root hub: the kernel says how many ports ("ports 1") *)
      let words = String.split_on_char ' ' (String.map (fun c -> if c = '\n' then ' ' else c) (Usbdev.said root)) in
      let rec ports = function "ports" :: n :: _ -> (try int_of_string n with Failure _ -> 1) | _ :: more -> ports more | [] -> 1 in
      ignore (add_hub root (ports words));
      ignore (look caps);
      (* the one that stays, and looks again *)
      if CapUnix.fork caps () = 0 then begin
        while true do pause 250; ignore (look caps) done
      end;
      Exit.OK

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps)))
