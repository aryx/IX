(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Icmp.mli *)

open Types
open Errors

let echoreply = 0 and echorequest = 8

let proto = ref None

let input pkt =
  let hl = (Char.code pkt.[0] land 15) * 4 in
  if String.length pkt >= hl + 8 then begin
    let typ = Char.code pkt.[hl] in
    let src = String.sub pkt 12 4 and dst = String.sub pkt 16 4 in
    if typ = echorequest then begin
      (* the reply: the same message, its type 0, its checksum anew *)
      let m = String.sub pkt hl (String.length pkt - hl) in
      let m = "\000" ^ String.sub m 1 1 ^ "\000\000" ^ String.sub m 4 (String.length m - 4) in
      let c = Ip.cksum m 0 (String.length m) 0 in
      Ip.send 1 dst src (String.sub m 0 2 ^ Ip.put16 c ^ String.sub m 4 (String.length m - 4))
    end
    else if typ = echoreply then begin
      let id = Ip.get16 pkt (hl + 4) in
      match !proto with
      | Some p -> Array.iter (function Some c when c.Ip.lport = id -> Ip.deliver c pkt | _ -> ()) p.Ip.convs
      | None -> ()
    end
  end

let init () =
  let p = { Ip.pname = "icmp"; Ip.convs = Array.make 16 None;
            Ip.connect = (fun c a ->
              let (ra, rp) = Ip.addrport a in
              c.Ip.raddr <- ra; c.Ip.rport <- rp; c.Ip.laddr <- Ip.source ra;
              c.Ip.lport <- Ip.nextport (); c.Ip.cstate <- "Connected");
            Ip.announce = (fun c _ -> c.Ip.cstate <- "Announced");
            Ip.write = (fun c s ->
              (* past the IP header's 20 bytes: the ICMP message, its
               * identifier ours, its checksum *)
              if String.length s < 28 then raise (Error "short icmp message");
              let m = String.sub s 20 (String.length s - 20) in
              let m = String.sub m 0 2 ^ "\000\000" ^ Ip.put16 c.Ip.lport ^ String.sub m 6 (String.length m - 6) in
              let k = Ip.cksum m 0 (String.length m) 0 in
              Ip.send 1 (Ip.source c.Ip.raddr) c.Ip.raddr (String.sub m 0 2 ^ Ip.put16 k ^ String.sub m 4 (String.length m - 4)));
            Ip.state = (fun c -> c.Ip.cstate ^ "\n");
            Ip.close = (fun _ -> ());
            Ip.listen = (fun _ -> raise (Error "not announced"));
            Ip.ctl = (fun _ _ -> false) } in
  proto := Some p;
  Ip.protos := !Ip.protos @ [ p ];
  Ip.register 1 input
