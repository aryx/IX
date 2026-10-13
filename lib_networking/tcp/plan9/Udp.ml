(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Udp.mli: Plan 9's, for mini-9pi (docs/plans/plan_browser.md, stage
 * 10). A directory of /net/udp, as Tcp's of /net/tcp: once "connect
 * address!port" is written to its ctl, a write to its data is a packet
 * sent there and a read a packet come from there. No select: the read
 * waits, [seconds] at most: an alarm set before it (Unix.setitimer,
 * as Tcp's), the read it interrupts no answer.
 * old: no alarm; a packet lost (a time server that did not answer)
 * held the program, and with it mini-9pi's boot *)

let ask (_caps : < Cap.network; .. >) ~(address : string) ~(port : int) (packet : string) (seconds : float) : string option =
  let ctl = Unix.openfile "/net/udp/clone" [ Unix.O_RDWR ] 0 in
  Fun.protect
    ~finally:(fun () -> Unix.close ctl)
    (fun () ->
      let b = Bytes.create 32 in
      let n = Unix.read ctl b 0 32 in
      let number = String.trim (Bytes.sub_string b 0 n) in
      let order = Printf.sprintf "connect %s!%d" address port in
      ignore (Unix.write_substring ctl order 0 (String.length order));
      let data = Unix.openfile ("/net/udp/" ^ number ^ "/data") [ Unix.O_RDWR ] 0 in
      Fun.protect
        ~finally:(fun () -> Unix.close data)
        (fun () ->
          ignore (Unix.write_substring data packet 0 (String.length packet));
          let b = Bytes.create 1500 in
          let alarm (t : float) : unit = ignore (Unix.setitimer Unix.ITIMER_REAL { Unix.it_interval = 0.; it_value = t }) in
          alarm seconds;
          let n = try Unix.read data b 0 1500 with Unix.Unix_error _ -> 0 in
          alarm 0.;
          if n = 0 then None else Some (Bytes.sub_string b 0 n)))

(* A game's conversation (Udp.mli's host and join). Its data file is
 * read by a process of its own (Source.reader: a message a packet),
 * and [arrived] takes what that process has given so far, the other
 * threads let to run first (the source's is one of them).
 *
 * The host's is announced with headers, Plan 9's way for a server of
 * UDP (udp(3)): each packet read comes behind 52 bytes that say who
 * sent it, and each one written goes behind 52 that say to whom:
 *
 *     0   the remote address   16 bytes (IPv6's; an IPv4 one is its
 *                              last 4, after ten 0 and two 0xff)
 *     16  the local address    16
 *     32  the interface's      16
 *     48  the remote port      2, the high byte first
 *     50  the local port       2
 *
 * The one who joins is connected, as [ask]: its packets alone. The
 * host's port is announced on all the machine's addresses ("*"),
 * whichever is asked: mini-9pi has one interface. *)
type peer = { ctl : Unix.file_descr; data : Unix.file_descr; packets : bytes Event.channel; mutable header : string option; hosting : bool; there : string }

let header_size = 52

let conversation (caps : < Cap.network; Cap.fork; .. >) (orders : string list) (hosting : bool) (there : string) : peer =
  let ctl = Unix.openfile "/net/udp/clone" [ Unix.O_RDWR ] 0 in
  try
    let b = Bytes.create 32 in
    let n = Unix.read ctl b 0 32 in
    let number = String.trim (Bytes.sub_string b 0 n) in
    List.iter (fun (order : string) -> ignore (Unix.write_substring ctl order 0 (String.length order))) orders;
    let data = Unix.openfile ("/net/udp/" ^ number ^ "/data") [ Unix.O_RDWR ] 0 in
    { ctl; data; packets = Source.reader caps data 2048; header = None; hosting; there }
  with e -> Unix.close ctl; raise e

let host (caps : < Cap.network; Cap.fork; .. >) ~address:(_ : string) ~(port : int) : peer =
  conversation caps [ "headers"; Printf.sprintf "announce *!%d" port ] true ""

let join (caps : < Cap.network; Cap.fork; .. >) ~(address : string) ~(port : int) : peer =
  conversation caps [ Printf.sprintf "connect %s!%d" address port ] false (Printf.sprintf "%s:%d" address port)

let send (p : peer) (s : string) : unit =
  let write (m : string) : unit = try ignore (Unix.write_substring p.data m 0 (String.length m)) with Unix.Unix_error _ -> () in
  if not p.hosting then write s else match p.header with Some h -> write (h ^ s) | None -> ()

(* (a host's player: whoever speaks first; the others' packets dropped) *)
let arrived (p : peer) : string list =
  let rec go (acc : string list) : string list =
    Thread.yield ();
    match Event.poll (Event.receive p.packets) with
    | Some b when Bytes.length b > 0 ->
        let m = Bytes.to_string b in
        if not p.hosting then go (m :: acc)
        else if String.length m < header_size then go acc
        else begin
          (* who sent it: the remote address and port, as a write names them *)
          let from = String.sub m 0 16 ^ String.sub m 48 2 in
          let same (h : string) : bool = String.sub h 0 16 ^ String.sub h 48 2 = from in
          if p.header = None then p.header <- Some (String.sub m 0 header_size);
          go (match p.header with Some h when same h -> String.sub m header_size (String.length m - header_size) :: acc | _ -> acc)
        end
    | _ -> List.rev acc
  in
  go []

let other (p : peer) : string option =
  if not p.hosting then Some p.there
  else match p.header with
    | Some h -> Some (Printf.sprintf "%d.%d.%d.%d:%d" (Char.code h.[12]) (Char.code h.[13]) (Char.code h.[14]) (Char.code h.[15]) ((Char.code h.[48] lsl 8) lor Char.code h.[49]))
    | None -> None
