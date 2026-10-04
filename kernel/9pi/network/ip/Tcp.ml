(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* See Tcp.mli *)

open Types
open Errors

type st = Closed | Listen | Syn_sent | Syn_rcvd | Established | Fin_wait1 | Fin_wait2 | Close_wait | Closing | Last_ack

let stname = function
  | Closed -> "Closed" | Listen -> "Listen" | Syn_sent -> "Syn_sent" | Syn_rcvd -> "Syn_received"
  | Established -> "Established" | Fin_wait1 -> "Finwait1" | Fin_wait2 -> "Finwait2" | Close_wait -> "Close_wait"
  | Closing -> "Closing" | Last_ack -> "Last_ack"

(* a connection's control block: the sequence numbers (the first sent,
 * the first not acked, the next to send; the next expected), the
 * peer's window and MSS, the data not acked (from snd_una), the FIN
 * wanted (a close) and its number once sent, the retransmission's tick
 * and tries, its listener (a connection called in, not accepted yet),
 * an error (a reset, a timeout) *)
type tcb = {
  conv : Ip.conv;
  mutable st : st;
  mutable iss : Int32.t;
  mutable una : Int32.t;
  mutable nxt : Int32.t;
  mutable rcv : Int32.t;
  mutable swnd : int;
  mutable mss : int;
  sndbuf : Buffer.t;
  mutable finwanted : bool;
  mutable finseq : Int32.t option;
  mutable rto : int;
  mutable tries : int;
  mutable listener : Ip.conv option;
  mutable err : string option;
}

let tcbs = ref []
(* the connections called in, by their listener's key, not accepted yet *)
let accepts = ref []

let proto = ref None
let getproto () = match !proto with Some p -> p | None -> failwith "tcp"

(*****************************************************************************)
(* Sequence numbers, the header *)
(*****************************************************************************)

let i32 = Int32.of_int
let add s n = Int32.add s (i32 n)
let diff a b = Int32.to_int (Int32.sub a b)
(* a before b, modulo 2^32 *)
let before a b = Int32.to_int (Int32.shift_right (Int32.sub a b) 31) <> 0

let get32 s o =
  Int32.logor (Int32.shift_left (i32 (Ip.get16 s o)) 16) (i32 (Ip.get16 s (o + 2)))
let put32 v =
  Ip.put16 (Int32.to_int (Int32.shift_right_logical v 16) land 0xffff) ^ Ip.put16 (Int32.to_int v land 0xffff)

let fin = 1 and syn = 2 and rst = 4 and psh = 8 and ack = 16

let ticks () = !Proc.ticks
let rtoticks = 100

(* a segment: our window 65535, SYN's MSS option 1460 *)
let segment t flags seq data =
  let c = t.conv in
  let opts = if flags land syn <> 0 then "\002\004" ^ Ip.put16 1460 else "" in
  let off = (20 + String.length opts) / 4 in
  let h = Ip.put16 c.Ip.lport ^ Ip.put16 c.Ip.rport ^ put32 seq ^ put32 (if flags land ack <> 0 then t.rcv else Int32.zero)
          ^ String.make 1 (Char.chr (off lsl 4)) ^ String.make 1 (Char.chr flags) ^ Ip.put16 65535 ^ "\000\000\000\000" ^ opts in
  let seg = h ^ data in
  let pseudo = c.Ip.laddr ^ c.Ip.raddr ^ "\000\006" ^ Ip.put16 (String.length seg) in
  let k = Ip.cksum (pseudo ^ seg) 0 (12 + String.length seg) 0 in
  Ip.send 6 c.Ip.laddr c.Ip.raddr (String.sub seg 0 16 ^ Ip.put16 k ^ String.sub seg 18 (String.length seg - 18))

let wake t = Proc.wakeup (Ip_conv t.conv.Ip.key)

(*****************************************************************************)
(* Output *)
(*****************************************************************************)

(* the data not sent yet within the peer's window, in MSS pieces; then
 * the FIN, once the data is all out *)
let output t =
  let sent = diff t.nxt t.una - (if t.st = Syn_sent || t.st = Syn_rcvd then 1 else 0) in
  let len = Buffer.length t.sndbuf in
  let rec go off =
    if off < len && off < t.swnd then begin
      let n = min (min t.mss (len - off)) (t.swnd - off) in
      segment t (ack lor psh) (add t.una off) (Buffer.sub t.sndbuf off n);
      t.nxt <- add t.una (off + n);
      go (off + n)
    end in
  if t.st = Established || t.st = Close_wait then go (max 0 sent);
  if t.finwanted && t.finseq = None && diff t.nxt t.una >= len && (t.st = Established || t.st = Close_wait) then begin
    segment t (fin lor ack) t.nxt "";
    t.finseq <- Some t.nxt;
    t.nxt <- add t.nxt 1;
    t.st <- (if t.st = Established then Fin_wait1 else Last_ack)
  end;
  if diff t.nxt t.una > 0 && t.rto = 0 then t.rto <- ticks () + rtoticks

let drop t = tcbs := List.filter (fun x -> x != t) !tcbs

let fail t e = t.err <- Some e; t.st <- Closed; t.conv.Ip.eof <- true; drop t; wake t

(* go back to the first not acked, all of it again *)
let retransmit t =
  t.tries <- t.tries + 1;
  if t.tries > 10 then fail t "connection timed out"
  else begin
    t.rto <- ticks () + rtoticks;
    match t.st with
    | Syn_sent -> segment t syn t.iss ""
    | Syn_rcvd -> segment t (syn lor ack) t.iss ""
    | _ ->
        t.nxt <- t.una;
        (match t.finseq with Some _ when Buffer.length t.sndbuf = 0 -> segment t (fin lor ack) t.una ""; t.nxt <- add t.una 1 | _ -> ());
        if Buffer.length t.sndbuf > 0 then begin
          let saved = t.finseq in
          t.finseq <- None;
          let st = t.st in
          t.st <- (match st with Fin_wait1 -> Established | Last_ack | Closing -> Close_wait | s -> s);
          output t;
          t.st <- st;
          (match saved with
           | Some f -> segment t (fin lor ack) f ""; t.finseq <- saved; t.nxt <- add f 1
           | None -> ())
        end
  end

let tick () =
  List.iter (fun t -> if t.rto <> 0 && ticks () >= t.rto && diff t.nxt t.una > 0 then retransmit t) !tcbs

(*****************************************************************************)
(* Input *)
(*****************************************************************************)

let newtcb c st =
  let iss = i32 ((ticks () * 64000) land 0x3fffffff) in
  let t = { conv = c; st = st; iss = iss; una = iss; nxt = iss; rcv = Int32.zero; swnd = 65535; mss = 536;
            sndbuf = Buffer.create 1024; finwanted = false; finseq = None; rto = 0; tries = 0; listener = None; err = None } in
  tcbs := t :: !tcbs;
  t

(* the MSS option of a SYN's header *)
let mssopt pkt o hlen =
  let rec go i = if i + 3 >= o + hlen then 536
    else match Char.code pkt.[i] with
      | 0 -> 536 | 1 -> go (i + 1)
      | 2 -> Ip.get16 pkt (i + 2)
      | _ -> go (i + max 2 (Char.code pkt.[i + 1])) in
  go (o + 20)

let input pkt =
  let hl = (Char.code pkt.[0] land 15) * 4 in
  if String.length pkt >= hl + 20 then begin
    let src = String.sub pkt 12 4 and dst = String.sub pkt 16 4 in
    let sport = Ip.get16 pkt hl and dport = Ip.get16 pkt (hl + 2) in
    let seq = get32 pkt (hl + 4) and ackn = get32 pkt (hl + 8) in
    let off = (Char.code pkt.[hl + 12] lsr 4) * 4 in
    let flags = Char.code pkt.[hl + 13] and win = Ip.get16 pkt (hl + 14) in
    let data = String.sub pkt (hl + off) (String.length pkt - hl - off) in
    let exact t = t.conv.Ip.lport = dport && t.conv.Ip.rport = sport && t.conv.Ip.raddr = src && t.st <> Listen in
    match (try Some (List.find exact !tcbs) with Not_found -> None) with
    | None ->
        (* a listener's, for a SYN *)
        (match (try Some (List.find (fun t -> t.st = Listen && t.conv.Ip.lport = dport) !tcbs) with Not_found -> None) with
         | Some l when flags land syn <> 0 && flags land ack = 0 ->
             let c = Ip.newconv (getproto ()) in
             c.Ip.laddr <- dst; c.Ip.lport <- dport; c.Ip.raddr <- src; c.Ip.rport <- sport;
             let t = newtcb c Syn_rcvd in
             t.listener <- Some l.conv;
             t.rcv <- add seq 1;
             t.mss <- mssopt pkt hl off;
             t.swnd <- win;
             segment t (syn lor ack) t.iss "";
             t.nxt <- add t.iss 1;
             t.rto <- ticks () + rtoticks
         | _ -> ())
    | Some t ->
        if flags land rst <> 0 then fail t (if t.st = Syn_sent then "connection refused" else "connection reset")
        else if t.st = Syn_sent then begin
          if flags land syn <> 0 && flags land ack <> 0 && Int32.to_int (Int32.sub ackn (add t.iss 1)) = 0 then begin
            t.rcv <- add seq 1;
            t.una <- ackn;
            t.mss <- min 1460 (mssopt pkt hl off);
            t.swnd <- win;
            t.st <- Established;
            t.rto <- 0; t.tries <- 0;
            segment t ack t.nxt "";
            wake t
          end
        end
        else begin
          (* the ACK: data acked, removed; the FIN's too *)
          if flags land ack <> 0 && before t.una ackn && not (before t.nxt ackn) then begin
            let n = diff ackn t.una in
            let n = if t.st = Syn_rcvd then begin
                t.st <- Established;
                (match t.listener with
                 | Some l -> accepts := !accepts @ [ (l.Ip.key, t.conv) ]; Proc.wakeup (Ip_conv l.Ip.key)
                 | None -> ());
                n - 1
              end else n in
            let d = min n (Buffer.length t.sndbuf) in
            let rest = Buffer.sub t.sndbuf d (Buffer.length t.sndbuf - d) in
            Buffer.clear t.sndbuf;
            Buffer.add_string t.sndbuf rest;
            t.una <- ackn;
            t.tries <- 0;
            t.rto <- (if diff t.nxt t.una > 0 then ticks () + rtoticks else 0);
            (match t.finseq with
             | Some f when Int32.to_int (Int32.sub ackn (add f 1)) = 0 ->
                 (match t.st with
                  | Fin_wait1 -> t.st <- Fin_wait2
                  | Closing | Last_ack -> t.st <- Closed; drop t
                  | _ -> ())
             | _ -> ());
            wake t
          end;
          if flags land ack <> 0 then t.swnd <- win;
          (* the data, in order; else the expected asked for again *)
          let dlen = String.length data in
          if dlen > 0 || flags land fin <> 0 then begin
            if Int32.to_int (Int32.sub seq t.rcv) = 0 then begin
              if dlen > 0 then begin Ip.deliver t.conv data; t.rcv <- add t.rcv dlen end;
              if flags land fin <> 0 then begin
                t.rcv <- add t.rcv 1;
                t.conv.Ip.eof <- true;
                t.st <- (match t.st with
                  | Established -> Close_wait
                  | Fin_wait1 -> Closing
                  | Fin_wait2 -> (drop t; Closed)
                  | s -> s);
                wake t
              end
            end;
            segment t ack t.nxt ""
          end;
          output t
        end
  end

(*****************************************************************************)
(* The protocol *)
(*****************************************************************************)

let tcbof c = try Some (List.find (fun t -> t.conv == c) !tcbs) with Not_found -> None

let rec waitfor c cond =
  if not (cond ()) then begin Proc.sleep (Ip_conv c.Ip.key); waitfor c cond end

let connect c a =
  let (ra, rp) = Ip.addrport a in
  c.Ip.raddr <- ra; c.Ip.rport <- rp; c.Ip.laddr <- Ip.source ra; c.Ip.lport <- Ip.nextport ();
  let t = newtcb c Syn_sent in
  segment t syn t.iss "";
  t.nxt <- add t.iss 1;
  t.rto <- ticks () + rtoticks;
  waitfor c (fun () -> t.st <> Syn_sent);
  match t.err with Some e -> raise (Error e) | None -> c.Ip.cstate <- "Established"

let announce c a =
  let (_, lp) = Ip.addrport a in
  c.Ip.lport <- lp;
  ignore (newtcb c Listen)

let listen c =
  waitfor c (fun () -> List.exists (fun (k, _) -> k = c.Ip.key) !accepts);
  let (_, nc) = List.find (fun (k, _) -> k = c.Ip.key) !accepts in
  accepts := List.filter (fun (_, x) -> x != nc) !accepts;
  nc

let write c s =
  match tcbof c with
  | Some t when t.st = Established || t.st = Close_wait ->
      Buffer.add_string t.sndbuf s;
      output t;
      (* not too much waiting to be acked *)
      waitfor c (fun () -> Buffer.length t.sndbuf < 65536 || t.st = Closed)
  | _ -> raise (Error "Hangup")

let close c =
  match tcbof c with
  | Some t ->
      (match t.st with
       | Established | Close_wait -> t.finwanted <- true; output t
       | Listen | Syn_sent | Closed -> drop t
       | _ -> ())
  | None -> ()

let state c =
  match tcbof c with
  | Some t -> Printf.sprintf "%s qin %d qout %d\n" (stname t.st) (Queue.length c.Ip.rq) (Buffer.length t.sndbuf)
  | None -> "Closed qin 0 qout 0\n"

let init () =
  let p = { Ip.pname = "tcp"; Ip.convs = Array.make 32 None; Ip.connect = connect; Ip.announce = announce;
            Ip.write = write; Ip.state = state; Ip.close = close; Ip.listen = listen; Ip.ctl = (fun _ _ -> false) } in
  proto := Some p;
  Ip.protos := !Ip.protos @ [ p ];
  Ip.register 6 input
