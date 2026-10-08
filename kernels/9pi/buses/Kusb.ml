(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Kusb.mli *)

open Usb
open Errors

(* a device read from the clock: what it is, its endpoint, a keyboard's state *)
type polled = { kind : Hid.kind; ep : ep; mutable keys : Hid.keyboard }

let devices : polled list ref = ref []

(* the kernel's refusal, as Usbbus wants it *)
let failing f = try f () with Error m -> failwith m

(* How Usbbus reaches a device here: Devusb's and Usbdwc's functions,
 * where mini-usbd has the files of #u. *)
let io = {
  Usbbus.name = (fun ep -> Printf.sprintf "ep%d.%d" ep.dev.dnb ep.enb);
  Usbbus.number = (fun ep -> ep.dev.dnb);
  Usbbus.send = (fun ep kind request value index more ->
    failing (fun () -> ignore (Devusb.request ep (Usbdesc.setup kind request value index (String.length more) ^ more) 0)));
  Usbbus.ask = (fun ep kind request value index count ->
    failing (fun () -> Devusb.request ep (Usbdesc.setup (kind lor 0x80) request value index count) count));
  Usbbus.set = (fun ep line -> failing (fun () -> Devusb.control ep line));
  Usbbus.child = (fun hub speed port -> failing (fun () -> Devusb.child hub speed port));
  Usbbus.drop = (fun ep -> devices := List.filter (fun d -> d.ep.dev != ep.dev) !devices);
  Usbbus.pause = Proc.tsleep;
  (* its endpoint, held by the kernel, read from the clock *)
  Usbbus.drive = (fun ep0 kind e ->
    failing (fun () ->
      let ep = Devusb.newdevep ep0 e.Usbdesc.number Tintr 0 in
      ep.maxpkt <- e.Usbdesc.maxpkt;
      ep.pollival <- max 1 e.Usbdesc.interval;
      ep.inuse <- true;
      devices := { kind = kind; ep = ep; keys = Hid.keyboard } :: !devices));
  Usbbus.say = Devcons.print;
}

let started = ref false

let start () =
  match !Devusb.the_root with
  | Some root when not !started ->
      started := true;
      (* (the root hub is the kernel's now: a usbd would find it taken) *)
      root.inuse <- true;
      let bus = Usbbus.start io root 1 in
      ignore (Usbbus.look bus);
      (* a device plugged later is found, one unplugged forgotten *)
      (* (by a process of the kernel's own: a look waits, a port's reset,
       * which the clock cannot) *)
      Kproc.start (Proc.myproc ()) "usb" (fun () ->
        while true do
          (try Proc.tsleep 1000 with Error _ -> ());
          (try ignore (Usbbus.look bus) with Error _ | Failure _ -> ())
        done)
  | _ -> ()

(* A device is asked again while it answers, up to [most] reports a
 * tick: a keyboard that has several to give (QEMU's keeps the keys'
 * changes in a queue of 16 and gives one a poll; a key held on the
 * host is its press again thirty times a second, two codes each for an
 * arrow) is emptied, where one report a tick, and fewer when the
 * kernel is long in a call, let the queue fill: the release was lost,
 * and the key stayed down for the game (the author, playing
 * TinyCameltry: "typing nothing the screen is still rotating"). A
 * device with nothing more says so at once (a NAK): one question more
 * a tick, and only after an answer.
 * old: one Usbdwc.intry a device a tick *)
let most = 16

let clock () =
  let now = !Proc.ticks * 10 in
  List.iter (fun d ->
    if now - d.ep.lastpoll >= d.ep.pollival then begin
      d.ep.lastpoll <- now;
      let rec ask left =
        match (try Usbdwc.intry d.ep d.ep.maxpkt with Error _ -> devices := List.filter (fun x -> x != d) !devices; None) with
        | None -> ()
        | Some report ->
            (match d.kind with
             | Hid.Keyboard ->
                 let keys, codes = Hid.typed d.keys report in
                 d.keys <- keys;
                 List.iter (fun s -> for i = 0 to String.length s - 1 do Kbd.kbdputsc (Char.code s.[i]) done) codes
             | Hid.Mouse ->
                 (match Hid.moved report with Some (x, y, buttons) -> Devmouse.track x y buttons | None -> ()));
            if left > 1 then ask (left - 1) in
      ask most
    end) !devices

let () = Devusb.kernel := start
