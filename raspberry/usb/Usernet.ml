(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Usernet.mli *)

let host = "\010\000\002\002"
let dns = "\010\000\002\003"
let hostmac = "\082\085\010\000\002\002"

(* the host's name server, which 10.0.2.3 stands for (Main reads it in
 * /etc/resolv.conf); and where a connection the guest makes to an
 * address really goes: the gateway is this machine, the name server
 * the host's, any other itself *)
let resolver = ref Unix.inet_addr_loopback
let show a = String.concat "." (List.init 4 (fun i -> string_of_int (Char.code a.[i])))
let real a = if a = host then Unix.inet_addr_loopback else if a = dns then !resolver else Unix.inet_addr_of_string (show a)

(* a connection: the guest's address and port, the host's port; the
 * sequence numbers (ours next and first not acked, the guest's next
 * expected), the guest's window; the socket; the FINs *)
type conn = {
  gaddr : string; gport : int; haddr : string; hport : int;
  mutable snd : int32; mutable una : int32; mutable rcv : int32;
  mutable wnd : int; sock : Unix.file_descr;
  mutable hostfin : bool; mutable guestfin : bool;
}

(* a UDP conversation: the guest's address and port, the address and
 * port it sends to, the host's socket connected there, when it last
 * carried a datagram *)
type flow = { fgaddr : string; fgport : int; faddr : string; fport : int; fsock : Unix.file_descr; mutable used : float }

type t = {
  send : string -> unit; mutable guestmac : string; mutable conns : conn list; mutable flows : flow list;
  (* for who watches (Monitor): the frames' bytes each way, and the
   * last things that happened, the newest first *)
  mutable from_guest : int; mutable to_guest : int; mutable events : string list;
}

let create send = { send; guestmac = String.make 6 '\255'; conns = []; flows = []; from_guest = 0; to_guest = 0; events = [] }

let note t what = t.events <- what :: (if List.length t.events >= 8 then List.filteri (fun i _ -> i < 7) t.events else t.events)
let out t frame = t.to_guest <- t.to_guest + String.length frame; t.send frame

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

(* an IP packet from src (10.0.2.2, or an address beyond it: the
 * gateway's card carries them all) to the guest, in a frame *)
let ip t proto src dst payload =
  let h = "\069\000" ^ put16 (20 + String.length payload) ^ "\000\000\000\000\255" ^ String.make 1 (Char.chr proto) ^ "\000\000" ^ src ^ dst in
  let h = String.sub h 0 10 ^ put16 (cksum h) ^ String.sub h 12 8 in
  out t (t.guestmac ^ hostmac ^ "\008\000" ^ h ^ payload)

let tcp t c flags data =
  let opts = if flags land 2 <> 0 then "\002\004" ^ put16 1460 else "" in
  let seg = put16 c.hport ^ put16 c.gport ^ put32 c.snd ^ put32 c.rcv
            ^ String.make 1 (Char.chr ((20 + String.length opts) * 4)) ^ String.make 1 (Char.chr flags) ^ put16 65535 ^ "\000\000\000\000" ^ opts ^ data in
  let k = cksum (c.haddr ^ c.gaddr ^ "\000\006" ^ put16 (String.length seg) ^ seg) in
  ip t 6 c.haddr c.gaddr (String.sub seg 0 16 ^ put16 k ^ String.sub seg 18 (String.length seg - 18))

let fin = 1 and syn = 2 and rst = 4 and psh = 8 and ack = 16

let arp t f =
  let op = get16 f 20 and sip = String.sub f 28 4 and tip = String.sub f 38 4 in
  (* the gateway and the name server: one card for both *)
  if op = 1 && (tip = host || tip = dns) then
    out t (String.sub f 6 6 ^ hostmac ^ "\008\006" ^ "\000\001\008\000\006\004\000\002" ^ hostmac ^ tip ^ String.sub f 6 6 ^ sip)

let icmp t pkt hl =
  if Char.code pkt.[hl] = 8 then begin
    let m = String.sub pkt hl (String.length pkt - hl) in
    let m = "\000" ^ String.sub m 1 1 ^ "\000\000" ^ String.sub m 4 (String.length m - 4) in
    let k = cksum m in
    ip t 1 (String.sub pkt 16 4) (String.sub pkt 12 4) (String.sub m 0 2 ^ put16 k ^ String.sub m 4 (String.length m - 4))
  end

let close_conn t c = (try Unix.close c.sock with Unix.Unix_error _ -> ()); t.conns <- List.filter (fun x -> x != c) t.conns

let tcpin t pkt hl =
  let gaddr = String.sub pkt 12 4 and haddr = String.sub pkt 16 4 in
  let sport = get16 pkt hl and dport = get16 pkt (hl + 2) in
  let seq = get32 pkt (hl + 4) and ackn = get32 pkt (hl + 8) in
  let off = (Char.code pkt.[hl + 12] lsr 4) * 4 and flags = Char.code pkt.[hl + 13] in
  let data = String.sub pkt (hl + off) (String.length pkt - hl - off) in
  match List.find_opt (fun c -> c.gport = sport && c.hport = dport && c.gaddr = gaddr && c.haddr = haddr) t.conns with
  | None ->
      if flags land syn <> 0 && flags land ack = 0 then begin
        (* a new one: a connection of the host's to where the guest
         * calls (10.0.2.2: this machine), else a RST. Waited for, 10 s
         * at most, the board stopped meanwhile: its clock is the
         * instructions' and jumps over an idle wait, so a connection
         * left to be made while the board ran (tried) was "timed out"
         * for the guest's kernel after 40 ms of the host's.
         * old: Unix.connect to 127.0.0.1 alone, then set_nonblock *)
        let sock = Unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
        let c = { gaddr; gport = sport; haddr; hport = dport; snd = 0x10000l; una = 0x10000l; rcv = Int32.add seq 1l; wnd = 65535;
                  sock; hostfin = false; guestfin = false } in
        Unix.set_nonblock sock;
        let made =
          match Unix.connect sock (Unix.ADDR_INET (real haddr, dport)) with
          | () -> true
          | exception Unix.Unix_error (Unix.EINPROGRESS, _, _) ->
              (* (made or not: asked by calling again, which says EISCONN
               * of a connection made and its error of one that failed;
               * lib_core's Unix has no getsockopt_error.
               * old: Unix.getsockopt_error sock = None) *)
              (match Unix.select [] [ sock ] [] 10. with
               | _, [ _ ], _ ->
                   (match Unix.connect sock (Unix.ADDR_INET (real haddr, dport)) with
                    | () -> true
                    | exception Unix.Unix_error (Unix.EISCONN, _, _) -> true
                    | exception Unix.Unix_error _ -> false)
               | _ -> false)
          | exception (Unix.Unix_error _ | Failure _) -> false in
        if made then begin
          note t (Printf.sprintf "tcp %s:%d" (show haddr) dport);
          t.conns <- c :: t.conns;
          tcp t c (syn lor ack) "";
          c.snd <- Int32.add c.snd 1l
        end
        else begin note t (Printf.sprintf "refused %s:%d" (show haddr) dport); Unix.close sock; tcp t c (rst lor ack) "" end
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

(* A datagram of the guest's: given to a socket of the host's connected
 * where it goes (10.0.2.3, the name server: the host's own), one for
 * each conversation; what comes back on it is [poll]'s. *)
let udpin t pkt hl =
  let gaddr = String.sub pkt 12 4 and faddr = String.sub pkt 16 4 in
  let sport = get16 pkt hl and dport = get16 pkt (hl + 2) and len = get16 pkt (hl + 4) in
  if len >= 8 && hl + len <= String.length pkt then begin
    let now = Unix.gettimeofday () in
    let flow =
      match List.find_opt (fun w -> w.fgport = sport && w.fport = dport && w.fgaddr = gaddr && w.faddr = faddr) t.flows with
      | Some w -> Some w
      | None -> (
          let fsock = Unix.socket Unix.PF_INET Unix.SOCK_DGRAM 0 in
          match Unix.connect fsock (Unix.ADDR_INET (real faddr, dport)) with
          | () ->
              Unix.set_nonblock fsock;
              let w = { fgaddr = gaddr; fgport = sport; faddr; fport = dport; fsock; used = now } in
              note t (Printf.sprintf "udp %s:%d" (show faddr) dport);
              t.flows <- w :: t.flows;
              Some w
          | exception (Unix.Unix_error _ | Failure _) -> Unix.close fsock; None)
    in
    Option.iter (fun w ->
      w.used <- now;
      try ignore (Unix.write_substring w.fsock pkt (hl + 8) (len - 8)) with Unix.Unix_error _ -> ()) flow
  end

let input t f =
  t.from_guest <- t.from_guest + String.length f;
  if String.length f >= 14 then begin
    t.guestmac <- String.sub f 6 6;
    match get16 f 12 with
    | 0x806 when String.length f >= 42 -> arp t f
    | 0x800 when String.length f >= 34 ->
        let pkt = String.sub f 14 (String.length f - 14) in
        let pkt = String.sub pkt 0 (min (String.length pkt) (get16 pkt 2)) in
        let hl = (Char.code pkt.[0] land 15) * 4 in
        (* (to any address: the gateway's card takes what leaves the
         * subnet; a ping is answered for the gateway and the name
         * server only.
         * old: if String.sub pkt 16 4 = host && ...) *)
        let dst = String.sub pkt 16 4 in
        if String.length pkt >= hl + 8 then
          (match Char.code pkt.[9] with
           | 1 when dst = host || dst = dns -> icmp t pkt hl
           | 6 when String.length pkt >= hl + 20 -> tcpin t pkt hl
           | 17 -> udpin t pkt hl
           | _ -> ())
    | _ -> ()
  end

let buf = Bytes.create 1460
let ubuf = Bytes.create 2048

(* the host's data, within the guest's window; its EOF a FIN *)
let poll t =
  (* the datagrams come back, each to its conversation's port; a
   * conversation silent for a minute is forgotten *)
  let now = Unix.gettimeofday () in
  List.iter (fun w ->
    let rec take () =
      match Unix.read w.fsock ubuf 0 (Bytes.length ubuf) with
      | n ->
          w.used <- now;
          let d = put16 w.fport ^ put16 w.fgport ^ put16 (8 + n) ^ "\000\000" ^ Bytes.sub_string ubuf 0 n in
          let k = cksum (w.faddr ^ w.fgaddr ^ "\000\017" ^ put16 (String.length d) ^ d) in
          ip t 17 w.faddr w.fgaddr (String.sub d 0 6 ^ put16 (if k = 0 then 0xffff else k) ^ String.sub d 8 n);
          take ()
      | exception Unix.Unix_error _ -> () in
    take ()) t.flows;
  let old, young = List.partition (fun w -> now -. w.used > 60.) t.flows in
  List.iter (fun w -> try Unix.close w.fsock with Unix.Unix_error _ -> ()) old;
  t.flows <- young;
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

(* what every network carried since the start, and holds now *)
type totals = { from_guest : int; to_guest : int; tcp : int; udp : int; events : string list }

let totals () =
  List.fold_left (fun (a : totals) (t : t) ->
    { from_guest = a.from_guest + t.from_guest; to_guest = a.to_guest + t.to_guest; tcp = a.tcp + List.length t.conns;
      udp = a.udp + List.length t.flows; events = a.events @ t.events })
    { from_guest = 0; to_guest = 0; tcp = 0; udp = 0; events = [] } !nets
