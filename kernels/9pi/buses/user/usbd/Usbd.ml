(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-usbd: the USB devices found and started (Plan 9's usbd, with
 * its kb: principia's kernel/buses/user/usb/usbd and kb), written
 * anew for what ix has: hubs, keyboards and mice.
 *
 * The kernel has the controller, and gives each endpoint as files
 * (#u: Usbdev); it knows no device. So a program does the rest: it
 * walks the bus from the root hub (../../lib_usb's Usbbus, which the
 * kernel can call too: "echo kernel > '#u/usb/ctl'" and no usbd), and
 * for each keyboard and each mouse starts a process that reads its
 * reports (Hid says what they mean) and writes the kernel's files:
 * scancodes, a PC keyboard's, to #Ι/kbin (the kernel's Kbd does the
 * rest: the characters, Shift, Alt), a line to #m/mousein, how far the
 * mouse moved and its buttons. So a device's driver is a program, and
 * the kernel has two files for it to write.
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

type caps = < Usbdev.caps; Cap.fork; Cap.stderr >

(* The device's process: a report read (the endpoint's largest packet,
 * no more: a report is one packet, and a read of more would wait for
 * a second one), what it means written; until the device is gone. *)
let reports fd maxpkt (kind : Hid.kind) out =
  let b = Bytes.create 64 in
  let write s = ignore (Unix.write_substring out s 0 (String.length s)) in
  let rec loop keyboard =
    let n = try Unix.read fd b 0 (min 64 maxpkt) with Unix.Unix_error _ -> 0 in
    if n > 0 then begin
      let report = Bytes.sub_string b 0 n in
      match kind with
      | Hid.Keyboard -> let keyboard, codes = Hid.typed keyboard report in List.iter write codes; loop keyboard
      | Hid.Mouse ->
          (match Hid.moved report with Some (x, y, buttons) -> write (Printf.sprintf "m%11d %11d %11d" x y buttons) | None -> ());
          loop keyboard
    end in
  loop Hid.keyboard

let drive (caps : < caps; .. >) (d : Usbdev.t) (kind : Hid.kind) (e : Usbdesc.endpoint) =
  (* its endpoint: made by a line to the device's ctl, then its own files *)
  Usbdev.ctl d (Printf.sprintf "new %d 3 r" e.number);
  let ep = Usbdev.open_ caps (Printf.sprintf "ep%d.%d" d.id e.number) in
  Usbdev.ctl ep (Printf.sprintf "maxpkt %d" e.maxpkt);
  if e.interval <> 0 then (try Usbdev.ctl ep (Printf.sprintf "pollival %d" e.interval) with Failure _ -> ());
  Usbdev.open_data caps ep 0;
  if CapUnix.fork caps () = 0 then begin
    reports (Option.get ep.data) e.maxpkt kind (FS.open_rw_fd caps (match kind with Hid.Keyboard -> "#Ι/kbin" | Hid.Mouse -> "#m/mousein"));
    Unix._exit 0
  end;
  Usbdev.close ep

let main (caps : < caps; .. >) : Exit.t =
  match Usbdev.open_ caps "ep1.0" with
  | exception Failure m -> Console.eprint caps (Printf.sprintf "usbd: #u/usb/ep1.0: %s\n" m); Exit.Err "no usb"
  | root ->
      Usbdev.open_data caps root 2;
      let io : Usbdev.t Usbbus.io = {
        name = (fun (d : Usbdev.t) -> d.name);
        number = (fun (d : Usbdev.t) -> d.id);
        send = Usbdev.send; ask = Usbdev.ask; set = Usbdev.ctl;
        (* the kernel's files for a new device: its name is read where the line was written *)
        child = (fun hub speed port ->
          Usbdev.ctl hub (Printf.sprintf "newdev %s %d" speed port);
          let d = Usbdev.open_ caps (Usbdev.said hub) in
          Usbdev.open_data caps d 2;
          d);
        drop = Usbdev.close;
        pause = (fun ms -> Unix.sleepf (float ms /. 1000.));
        drive = drive caps;
        say = Console.eprint caps } in
      (* the root hub: the kernel says how many ports ("ports 1") *)
      let words = String.split_on_char ' ' (String.map (fun c -> if c = '\n' then ' ' else c) (Usbdev.said root)) in
      let rec ports = function "ports" :: n :: _ -> (try int_of_string n with Failure _ -> 1) | _ :: more -> ports more | [] -> 1 in
      let bus = Usbbus.start io root (ports words) in
      ignore (Usbbus.look bus);
      (* the one that stays, and looks again *)
      if CapUnix.fork caps () = 0 then begin
        while true do Unix.sleepf 0.25; ignore (Usbbus.look bus) done
      end;
      Exit.OK

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps)))
