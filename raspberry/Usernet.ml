(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* See Usernet.mli *)

let host = "\010\000\002\002"
let hostmac = "\082\085\010\000\002\002"

(* a connection: the guest's address and port, the host's port; the
 * sequence numbers (ours next and first not acked, the guest's next
 * expected), the guest's window; the socket; the FINs *)
type conn = {
  gaddr : string; gport : int; hport : int;
  mutable snd : int32; mutable una : int32; mutable rcv : int32;
  mutable wnd : int; sock : Unix.file_descr;
  mutable hostfin : bool; mutable guestfin : bool;
}

type t = { send : string -> unit; mutable guestmac : string; mutable conns : conn list }

let create send = { send; guestmac = String.make 6 '\255'; conns = [] }

let get16 s o = (Char.code s.[o] lsl 8) lor Char.code s.[o + 1]
let put16 v = String.init 2 (fun i -> Char.chr ((v lsr (8 * (1 - i))) land 255))
let get32 s o = Int32.logor (Int32.shift_left (Int32.of_int (get16 s o)) 16) (Int32.of_int (get16 s (o + 2)))
let put32 v = put16 (Int32.to_int (Int32.shift_right_logical v 16) land 0xffff) ^ put16 (Int32.to_int v land 0xffff)

let cksum s =
  let sum = ref 0 and n = String.length s in
  let i = ref 0 in
  while !i + 1 < n do sum := !sum + get16 s !i; i := !i + 2 done;
  if !i < n then sum := !sum + (Char.code s.[!i] lsl 8);
  while !sum lsr 16 <> 0 do sum := (!sum land 0xffff) + (!sum lsr 16) done;
  lnot !sum land 0xffff

(* an IP packet from 10.0.2.2 to the guest, in a frame *)
let ip t proto dst payload =
  let h = "\069\000" ^ put16 (20 + String.length payload) ^ "\000\000\000\000\255" ^ String.make 1 (Char.chr proto) ^ "\000\000" ^ host ^ dst in
  let h = String.sub h 0 10 ^ put16 (cksum h) ^ String.sub h 12 8 in
  t.send (t.guestmac ^ hostmac ^ "\008\000" ^ h ^ payload)

let tcp t c flags data =
  let opts = if flags land 2 <> 0 then "\002\004" ^ put16 1460 else "" in
  let seg = put16 c.hport ^ put16 c.gport ^ put32 c.snd ^ put32 c.rcv
            ^ String.make 1 (Char.chr ((20 + String.length opts) * 4)) ^ String.make 1 (Char.chr flags) ^ put16 65535 ^ "\000\000\000\000" ^ opts ^ data in
  let k = cksum (host ^ c.gaddr ^ "\000\006" ^ put16 (String.length seg) ^ seg) in
  ip t 6 c.gaddr (String.sub seg 0 16 ^ put16 k ^ String.sub seg 18 (String.length seg - 18))

let fin = 1 and syn = 2 and rst = 4 and psh = 8 and ack = 16

let arp t f =
  let op = get16 f 20 and sip = String.sub f 28 4 and tip = String.sub f 38 4 in
  if op = 1 && tip = host then
    t.send (String.sub f 6 6 ^ hostmac ^ "\008\006" ^ "\000\001\008\000\006\004\000\002" ^ hostmac ^ host ^ String.sub f 6 6 ^ sip)

let icmp t pkt hl =
  if Char.code pkt.[hl] = 8 then begin
    let m = String.sub pkt hl (String.length pkt - hl) in
    let m = "\000" ^ String.sub m 1 1 ^ "\000\000" ^ String.sub m 4 (String.length m - 4) in
    let k = cksum m in
    ip t 1 (String.sub pkt 12 4) (String.sub m 0 2 ^ put16 k ^ String.sub m 4 (String.length m - 4))
  end

let close_conn t c = (try Unix.close c.sock with Unix.Unix_error _ -> ()); t.conns <- List.filter (fun x -> x != c) t.conns

let tcpin t pkt hl =
  let gaddr = String.sub pkt 12 4 in
  let sport = get16 pkt hl and dport = get16 pkt (hl + 2) in
  let seq = get32 pkt (hl + 4) and ackn = get32 pkt (hl + 8) in
  let off = (Char.code pkt.[hl + 12] lsr 4) * 4 and flags = Char.code pkt.[hl + 13] in
  let data = String.sub pkt (hl + off) (String.length pkt - hl - off) in
  match List.find_opt (fun c -> c.gport = sport && c.hport = dport && c.gaddr = gaddr) t.conns with
  | None ->
      if flags land syn <> 0 && flags land ack = 0 then begin
        (* a new one: the host's port, else a RST *)
        let sock = Unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
        let c = { gaddr; gport = sport; hport = dport; snd = 0x10000l; una = 0x10000l; rcv = Int32.add seq 1l; wnd = 65535;
                  sock; hostfin = false; guestfin = false } in
        match Unix.connect sock (Unix.ADDR_INET (Unix.inet_addr_loopback, dport)) with
        | () ->
            Unix.set_nonblock sock;
            t.conns <- c :: t.conns;
            tcp t c (syn lor ack) "";
            c.snd <- Int32.add c.snd 1l
        | exception Unix.Unix_error _ -> Unix.close sock; tcp t c (rst lor ack) ""
      end
  | Some c ->
      if flags land rst <> 0 then close_conn t c
      else begin
        if flags land ack <> 0 then begin c.una <- ackn; c.wnd <- get16 pkt (hl + 14) end;
        if String.length data > 0 && seq = c.rcv then begin
          (try ignore (Unix.write_substring c.sock data 0 (String.length data)) with Unix.Unix_error _ -> ());
          c.rcv <- Int32.add c.rcv (Int32.of_int (String.length data));
          tcp t c ack ""
        end;
        if flags land fin <> 0 && not c.guestfin then begin
          c.guestfin <- true;
          c.rcv <- Int32.add c.rcv 1l;
          (try Unix.shutdown c.sock Unix.SHUTDOWN_SEND with Unix.Unix_error _ -> ());
          tcp t c ack ""
        end;
        if c.guestfin && c.hostfin && c.una = c.snd then close_conn t c
      end

let input t f =
  if String.length f >= 14 then begin
    t.guestmac <- String.sub f 6 6;
    match get16 f 12 with
    | 0x806 when String.length f >= 42 -> arp t f
    | 0x800 when String.length f >= 34 ->
        let pkt = String.sub f 14 (String.length f - 14) in
        let pkt = String.sub pkt 0 (min (String.length pkt) (get16 pkt 2)) in
        let hl = (Char.code pkt.[0] land 15) * 4 in
        if String.sub pkt 16 4 = host && String.length pkt >= hl + 8 then
          (match Char.code pkt.[9] with 1 -> icmp t pkt hl | 6 when String.length pkt >= hl + 20 -> tcpin t pkt hl | _ -> ())
    | _ -> ()
  end

let buf = Bytes.create 1460

(* the host's data, within the guest's window; its EOF a FIN *)
let poll t =
  List.iter (fun c ->
    let inflight = Int32.to_int (Int32.sub c.snd c.una) in
    if not c.hostfin && inflight + 1460 <= c.wnd then
      match Unix.read c.sock buf 0 1460 with
      | 0 -> c.hostfin <- true; tcp t c (fin lor ack) ""; c.snd <- Int32.add c.snd 1l
      | n -> tcp t c (psh lor ack) (Bytes.sub_string buf 0 n); c.snd <- Int32.add c.snd (Int32.of_int n)
      | exception Unix.Unix_error ((Unix.EAGAIN | Unix.EWOULDBLOCK), _, _) -> ()
      | exception Unix.Unix_error _ -> c.hostfin <- true; tcp t c (fin lor ack) ""; c.snd <- Int32.add c.snd 1l) t.conns

(* a usb-net and its network; every network's host side polled (the
 * main loop's) *)
let nets = ref []

let usb ~path =
  let d = Usb.net ~path () in
  let t = create (Usb.net_input d) in
  Usb.net_output d (input t);
  nets := t :: !nets;
  d

let poll_all () = List.iter poll !nets
