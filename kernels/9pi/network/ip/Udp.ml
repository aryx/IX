(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Udp.mli *)

open Errors

let proto = ref None

(* the datagram's sum, over IP's pseudo-header (protocol 17) and it *)
let sum (src : string) (dst : string) (d : string) : int =
  Ip.cksum (src ^ dst ^ "\000\017" ^ Ip.put16 (String.length d) ^ d) 0 (12 + String.length d) 0

(* the bytes before the data of a read and of a write, with headers:
 * the remote address, the local one, the interface's (16 bytes each),
 * the remote port, the local one *)
let headers = 52

(* an IPv4 address as Plan 9's headers have every address: IPv6's 16
 * bytes, the 4 last *)
let v6 (a : string) : string = String.make 10 '\000' ^ "\255\255" ^ a

(* a datagram in: to the connection of its port that is connected to
 * its sender, its data alone; and to the one announced on its port,
 * with headers its sender's address before the data *)
let input pkt =
  let hl = (Char.code pkt.[0] land 15) * 4 in
  if String.length pkt >= hl + 8 then begin
    let src = String.sub pkt 12 4 and dst = String.sub pkt 16 4 in
    let sport = Ip.get16 pkt hl and dport = Ip.get16 pkt (hl + 2) and len = Ip.get16 pkt (hl + 4) in
    if len >= 8 && hl + len <= String.length pkt then begin
      let d = String.sub pkt hl len in
      (* (a checksum of 0: the sender made none) *)
      if Ip.get16 d 6 = 0 || sum src dst d = 0 then
        match !proto with
        | Some p ->
            Array.iter
              (function
                | Some c when c.Ip.cstate = "Connected" && c.Ip.lport = dport && c.Ip.raddr = src && c.Ip.rport = sport -> Ip.deliver c (String.sub d 8 (len - 8))
                | Some c when c.Ip.cstate = "Announced" && c.Ip.lport = dport ->
                    let h = if c.Ip.headers then v6 src ^ v6 dst ^ v6 (Ip.source src) ^ Ip.put16 sport ^ Ip.put16 dport else "" in
                    Ip.deliver c (h ^ String.sub d 8 (len - 8))
                | _ -> ())
              p.Ip.convs
        | None -> ()
    end
  end

let init () =
  let p = { Ip.pname = "udp"; Ip.convs = Array.make 16 None;
            Ip.connect = (fun c a ->
              let (ra, rp) = Ip.addrport a in
              c.Ip.raddr <- ra; c.Ip.rport <- rp; c.Ip.laddr <- Ip.source ra;
              c.Ip.lport <- Ip.nextport (); c.Ip.cstate <- "Connected");
            Ip.announce = (fun c a ->
              let (_, lp) = Ip.addrport a in
              c.Ip.lport <- lp; c.Ip.cstate <- "Announced");
            Ip.write = (fun c s ->
              (* where to: the connection's other end, or with headers
               * the one the write's first 52 bytes name *)
              let (laddr, raddr, rport, s) =
                if c.Ip.headers then begin
                  if String.length s < headers then raise (Error "short write");
                  let ra = String.sub s 12 4 in
                  (Ip.source ra, ra, Ip.get16 s 48, String.sub s headers (String.length s - headers))
                end
                else if c.Ip.cstate <> "Connected" then raise (Error "not connected")
                else (c.Ip.laddr, c.Ip.raddr, c.Ip.rport, s) in
              let len = 8 + String.length s in
              let d = Ip.put16 c.Ip.lport ^ Ip.put16 rport ^ Ip.put16 len ^ "\000\000" ^ s in
              let k = sum laddr raddr d in
              let k = if k = 0 then 0xffff else k in
              Ip.send 17 laddr raddr (String.sub d 0 6 ^ Ip.put16 k ^ s));
            Ip.state = (fun c -> c.Ip.cstate ^ "\n");
            Ip.close = (fun _ -> ());
            Ip.listen = (fun _ -> raise (Error "not announced"));
            Ip.ctl = (fun _ _ -> false) } in
  proto := Some p;
  Ip.protos := !Ip.protos @ [ p ];
  Ip.register 17 input
