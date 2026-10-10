(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Etherusb.mli *)

open Types
open Errors

type adapter = { ep0 : Usb.ep; bulk : Usb.ep; mac : string }

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

let adapter ep0 =
  let d = getdesc ep0 1 0 0 18 in
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
        Some { ep0 = ep0; bulk = ep; mac = mac }
  end

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
      ignore (Usbdwc.epwrite a.bulk frame);
      if String.length frame mod a.bulk.Usb.maxpkt = 0 then ignore (Usbdwc.epwrite a.bulk "")

(* each finished transfer a frame (up to 1536 bytes: QEMU's usb-net
 * sends a frame's packets in one, a short packet its end) *)
let poll () =
  match !found with
  | None -> []
  | Some a ->
      let rec go acc =
        match (try Usbdwc.inpoll a.bulk 1536 with Error _ -> None) with
        | None -> List.rev acc
        | Some f -> go (if String.length f > 0 then f :: acc else acc) in
      go []
