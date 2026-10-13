(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Etherusb.mli *)

open Types
open Errors

(* An adapter: its endpoints (QEMU's: one number both ways), its
 * address, and how its transfers carry frames: [wrap] a frame as a
 * transfer out, [unwrap] the frames of a transfer in, of [room] bytes
 * at most *)
type adapter = { ep0 : Usb.ep; input : Usb.ep; output : Usb.ep; mac : string; room : int;
                 wrap : string -> string; unwrap : string -> string list }

let found = ref None


(* a control transfer: an IN's reply, an OUT's nothing *)
let control ep0 rt req value index len =
  (* (the request's 8 bytes: lib_usb's, as Kusb's and mini-usbd's) *)
  ignore (Usbdwc.epwrite ep0 (Usbdesc.setup rt req value index len));
  if rt land 0x80 <> 0 then Usbdwc.epread ep0 len else ""

let getdesc ep0 typ index lang len = control ep0 0x80 6 ((typ lsl 8) lor index) lang len

(* a configuration's descriptors, each [type; bytes] *)
let rec descs s i = if i + 1 >= String.length s then [] else
  let n = Char.code s.[i] in if n = 0 then [] else (Char.code s.[i + 1], String.sub s i (min n (String.length s - i))) :: descs s (i + n)

let hexval c = match c with '0' .. '9' -> Char.code c - 48 | 'a' .. 'f' -> Char.code c - 87 | 'A' .. 'F' -> Char.code c - 55 | _ -> 0

(*****************************************************************************)
(* The boards' adapter: SMSC's LAN9512 and LAN9514 *)
(*****************************************************************************)

(* The device's registers are read and written by two requests of its
 * own (principia's smsc.c, whose steps these are; Linux's smsc95xx.c
 * for what a word means): 4 bytes, the low one first. A register is
 * an int here, its top bit lost where an int has 31 (the Pi 1's): none
 * of the bits set or tested below is that one; what must be whole (the
 * address, a word of ones) is written as its bytes ([wrs]). *)
let b v = String.make 1 (Char.chr (v land 0xff))
let wrs ep0 reg s = ignore (Usbdwc.epwrite ep0 (Usbdesc.setup 0x40 0xa0 0 reg 4 ^ s))
let wr ep0 reg v = wrs ep0 reg (b v ^ b (v lsr 8) ^ b (v lsr 16) ^ b (v lsr 24))
let rr ep0 reg =
  let s = control ep0 0xc0 0xa1 0 reg 4 in
  if String.length s < 4 then 0
  else Char.code s.[0] lor (Char.code s.[1] lsl 8) lor (Char.code s.[2] lsl 16) lor (Char.code s.[3] lsl 24)

let hwcfg = 0x14 and pmctrl = 0x20 and maccr = 0x100 and miiaddr = 0x114 and miidata = 0x118 and coecr = 0x130
and intepctl = 0x68

(* a bit set, until the device clears it (a reset's: a second at most) *)
let reset ep0 reg bit =
  wr ep0 reg bit;
  let rec go n = if rr ep0 reg land bit = 0 then true else if n = 0 then false else begin Proc.tsleep 10; go (n - 1) end in
  go 100

(* the transceiver's registers (the PHY: what speaks to the cable),
 * through two of the device's: its number 1, the register, read or
 * write, and a busy bit *)
let rec quiet ep0 n = if n > 0 && rr ep0 miiaddr land 1 <> 0 then quiet ep0 (n - 1)
let miird ep0 idx = quiet ep0 100; wr ep0 miiaddr ((1 lsl 11) lor (idx lsl 6)); quiet ep0 100; rr ep0 miidata
let miiwr ep0 idx v = quiet ep0 100; wr ep0 miidata v; wr ep0 miiaddr ((1 lsl 11) lor (idx lsl 6) lor 2); quiet ep0 100

(* the address the firmware has for the board; one made up when it has
 * none (its second bit says so: locally administered) *)
let board_mac () =
  let l = List.map Machine.board_mac [ 0; 1; 2; 3; 4; 5 ] in
  if List.exists (fun x -> x < 0) l then "\002ix\000\000\001" else String.concat "" (List.map b l)

(* A transfer in is several frames (the device waits a little for more:
 * fewer transfers), each behind a word: its length in bits 16 to 29,
 * an error in bit 15, and after it nothing up to the next multiple of
 * 4. The length counts the 4 bytes of the frame's own check at its
 * end (the FCS), which are not given on. *)
let rec frames t o =
  if o + 4 > String.length t then []
  else begin
    let n = (Char.code t.[o + 2] lor (Char.code t.[o + 3] lsl 8)) land 0x3fff in
    let bad = Char.code t.[o + 1] land 0x80 <> 0 in
    if n < 6 || o + 4 + n > String.length t then []
    else (if bad || n < 18 then [] else [ String.sub t (o + 4) (n - 4) ]) @ frames t ((o + 4 + n + 3) land (lnot 3))
  end

(* a transfer out is one frame behind two words: its length, with the
 * bits that say it is a frame's first and last piece, and its length *)
let command frame =
  let n = String.length frame in
  b n ^ b ((n lsr 8) lor 0x30) ^ "\000\000" ^ b n ^ b (n lsr 8) ^ "\000\000" ^ frame

let lan95xx ep0 =
  (* its one configuration; its two bulk endpoints, in and out *)
  ignore (control ep0 0x00 9 1 0 0);
  let c9 = getdesc ep0 2 0 0 9 in
  let c = getdesc ep0 2 0 0 (Char.code c9.[2] lor (Char.code c9.[3] lsl 8)) in
  let bulk = List.filter (fun (t, d) -> t = 5 && String.length d >= 6 && Char.code d.[3] land 3 = 2) (descs c 0) in
  let ep inward =
    match List.filter (fun (_, d) -> (Char.code d.[2] land 0x80 <> 0) = inward) bulk with
    | (_, d) :: _ ->
        (* (the one made by a setup that did not end, kept) *)
        let nb = Char.code d.[2] land 0x0f in
        let e = match ep0.Usb.dev.Usb.deps.(nb) with Some e -> e | None -> Devusb.newdevep ep0 nb Usb.Tbulk 2 in
        e.Usb.maxpkt <- Char.code d.[4] lor (Char.code d.[5] lsl 8);
        Some e
    | [] -> None in
  match ep true, ep false with
  | Some input, Some output when reset ep0 hwcfg (1 lsl 3) && reset ep0 pmctrl (1 lsl 4) ->
      let mac = board_mac () in
      wrs ep0 0x108 (String.sub mac 0 4);
      wrs ep0 0x104 (String.sub mac 4 2 ^ "\000\000");
      (* several frames a transfer (MEF), of 8 packets of 512 bytes at
       * most (the burst's cap, BCE), no room before a frame (RXDOFF),
       * a NAK when it has nothing (BIR); the wait for more frames *)
      wr ep0 hwcfg ((rr ep0 hwcfg land (lnot (3 lsl 9))) lor (1 lsl 12) lor (1 lsl 5) lor (1 lsl 1));
      wr ep0 0x38 8;
      wr ep0 0x6c 0x2000;
      wrs ep0 0x08 "\255\255\255\255";
      (* the jack's three lights: speed, link, duplex *)
      wr ep0 0x24 ((1 lsl 24) lor (1 lsl 20) lor (1 lsl 16));
      (* no pause frames, the default thresholds, the VLAN's type, no
       * checksums made or checked by the device, no multicast, not
       * every frame of the cable *)
      wr ep0 0x11c 0;
      wr ep0 0x2c 0xf830a1;
      wr ep0 0x120 0x8100;
      wr ep0 coecr (rr ep0 coecr land (lnot ((1 lsl 16) lor 1)));
      wr ep0 0x10c 0;
      wr ep0 0x110 0;
      wr ep0 maccr (rr ep0 maccr land (lnot ((1 lsl 19) lor (1 lsl 18) lor (1 lsl 13))));
      (* the transceiver: reset, what it may agree on with the other end
       * of the cable (10 and 100 Mbit/s, half and full duplex, pause),
       * and the agreement started again. Two boards joined by one
       * cable agree as a board and a switch do: either end crosses
       * the pairs when the other does not (auto-MDIX) *)
      miiwr ep0 0 ((1 lsl 15) lor (1 lsl 12));
      let rec ready n = if n > 0 && miird ep0 0 land (1 lsl 15) <> 0 then begin Proc.tsleep 10; ready (n - 1) end in
      ready 100;
      miiwr ep0 4 (0x0001 lor 0x01e0 lor 0x0400 lor 0x0800);
      ignore (miird ep0 29);
      miiwr ep0 30 ((1 lsl 6) lor (1 lsl 4));
      miiwr ep0 0 (miird ep0 0 lor (1 lsl 12) lor (1 lsl 9));
      wr ep0 intepctl (rr ep0 intepctl lor (1 lsl 15));
      (* frames out and in, from now *)
      wr ep0 maccr (rr ep0 maccr lor (1 lsl 3) lor (1 lsl 2));
      wr ep0 0x10 (1 lsl 2);
      Some { ep0 = ep0; input = input; output = output; mac = mac; room = 8 * 512; wrap = command; unwrap = (fun t -> frames t 0) }
  | _ -> None

(*****************************************************************************)
(* QEMU's adapter: CDC Ethernet *)
(*****************************************************************************)

let cdc ep0 d =
  (* a communications device (class 2) *)
  if String.length d < 18 || Char.code d.[4] <> 2 then None
  else begin
    (* configuration 1's descriptors: QEMU's second (index 1) *)
    let c9 = getdesc ep0 2 1 0 9 in
    let total = Char.code c9.[2] lor (Char.code c9.[3] lsl 8) in
    let c = getdesc ep0 2 1 0 total in
    let ds = descs c 0 in
    (* the Ethernet functional descriptor (CS_INTERFACE 0x24, 0x0F): its
     * iMACAddress; a bulk endpoint's number and packet size *)
    let imac = List.fold_left (fun a (t, b) -> if t = 0x24 && String.length b > 3 && Char.code b.[2] = 0x0f then Char.code b.[3] else a) 0 ds in
    let bulk = List.filter (fun (t, b) -> t = 5 && Char.code b.[3] land 3 = 2) ds in
    match bulk with
    | [] -> None
    | (_, b) :: _ ->
        let nb = Char.code b.[2] land 0x0f and maxpkt = Char.code b.[4] lor (Char.code b.[5] lsl 8) in
        (* SET_CONFIGURATION 1, SET_INTERFACE 1 alternate 1 (the data's) *)
        ignore (control ep0 0x00 9 1 0 0);
        ignore (control ep0 0x01 11 1 1 0);
        let s = getdesc ep0 3 imac 0x0409 255 in
        (* the MAC's 12 hex digits, UTF-16 *)
        let mac = String.concat "" (List.init 6 (fun i -> String.make 1 (Char.chr ((hexval s.[2 + (4 * i)] lsl 4) lor hexval s.[2 + (4 * i) + 2])))) in
        let ep = Devusb.newdevep ep0 nb Usb.Tbulk 2 in
        ep.Usb.maxpkt <- maxpkt;
        (* (a transfer is a frame, as it is) *)
        Some { ep0 = ep0; input = ep; output = ep; mac = mac; room = 1536; wrap = (fun f -> f);
               unwrap = (fun t -> if t = "" then [] else [ t ]) }
  end

(* which adapter a device is, by who made it and what it is called
 * (its descriptor's bytes 8 to 11): SMSC's 0x0424, its LAN95xx 0xec00
 * (and the LAN9500, alone on a board of its own, 0x9500) *)
let adapter ep0 =
  let d = getdesc ep0 1 0 0 18 in
  let id o = if String.length d < 18 then 0 else Char.code d.[o] lor (Char.code d.[o + 1] lsl 8) in
  if id 8 = 0x0424 && (id 10 = 0xec00 || id 10 = 0x9500) then lan95xx ep0 else cdc ep0 d

let probe () =
  (match !found with
   | Some _ -> ()
   | None ->
       List.iter (fun ep0 -> if !found = None then (try found := adapter ep0 with Error _ -> ())) (Devusb.devices ()));
  match !found with Some a -> Some a.mac | None -> None

let send frame =
  match !found with
  | None -> ()
  | Some a ->
      let frame = if String.length frame < 60 then frame ^ String.make (60 - String.length frame) '\000' else frame in
      let t = a.wrap frame in
      ignore (Usbdwc.epwrite a.output t);
      if String.length t mod a.output.Usb.maxpkt = 0 then ignore (Usbdwc.epwrite a.output "")

(* each finished transfer its frames (QEMU's usb-net: one, up to 1536
 * bytes, a frame's packets in one transfer, a short packet its end) *)
(* A finished transfer is followed by another at once, and that one
 * asked again before the poll ends ([again]): an emulator's is done as
 * soon as it is started, when a frame waits, and a tick then takes all
 * that wait (64 at most, the clock's time being everyone's).
 * old: the transfer started after a frame was looked at the next tick:
 * one frame a tick, a hundred a second, and a game that is sent a
 * hundred packets a second by the other one read them later and later
 * (the playground's TinyTronscroll against Linux's under QEMU: a tick
 * of the game every half second, docs/plans/bugs/ix.md) *)
let poll () =
  match !found with
  | None -> []
  | Some a ->
      let rec go acc again n =
        match (try Usbdwc.inpoll a.input a.room with Error _ -> None) with
        | None -> if again then go acc false n else List.rev acc
        | Some t ->
            let acc = List.rev_append (a.unwrap t) acc in
            if n = 0 then List.rev acc else go acc true (n - 1) in
      go [] false 64
