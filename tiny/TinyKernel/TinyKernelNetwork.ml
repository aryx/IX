(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyKernelNetwork.mli *)

(*****************************************************************************)
(* Bytes *)
(*****************************************************************************)

(* each byte's string, made once; a number of 16 bits as the network
 * has it, the high byte first, and read back *)
let net_byte = Array.make 256 ""
let () = for c = 0 to 255 do net_byte.(c) <- String.make 1 (Char.chr c) done
let net16 v = net_byte.((v lsr 8) land 255) ^ net_byte.(v land 255)
let net_get16 s i = (256 * Char.code s.[i]) + Char.code s.[i + 1]

(* The Internet's checksum (RFC 1071): the bytes as numbers of 16 bits
 * added up, what goes over 16 bits added back in, the result's bits
 * turned. Written into the bytes it covers (at a place left 0 while
 * adding), the sum of the whole is then 0: that is the check. A
 * packet's 2,048 bytes add up to less than 2^27: an int of 31 bits
 * holds it. *)
let net_sum s =
  let n = String.length s in
  let acc = ref 0 in
  for i = 0 to (n / 2) - 1 do acc := !acc + net_get16 s (2 * i) done;
  if n land 1 = 1 then acc := !acc + (256 * Char.code s.[n - 1]);
  while !acc > 0xffff do acc := (!acc land 0xffff) + (!acc lsr 16) done;
  0xffff - !acc

(*****************************************************************************)
(* Addresses *)
(*****************************************************************************)

(* an address is its four bytes, a string: nothing is computed on one,
 * and 32 bits do not fit tiny-ml's int. "10.0.0.2" to it and back; ""
 * when the text is not an address *)
let net_address text =
  let n = String.length text in
  let rec go i v digits acc =
    if i = n || text.[i] = '.' then
      (if digits = 0 || v > 255 then ""
       else if i = n then acc ^ net_byte.(v)
       else go (i + 1) 0 0 (acc ^ net_byte.(v)))
    else if text.[i] >= '0' && text.[i] <= '9' then
      go (i + 1) ((10 * v) + Char.code text.[i] - 48) (digits + 1) acc
    else "" in
  let a = go 0 0 0 "" in
  if String.length a = 4 then a else ""

(* the two ends of tiny-machine's wire: the machine, and its host *)
let net_machine = net_address "10.0.0.2"
let net_peer = net_address "10.0.0.1"

(*****************************************************************************)
(* IP: the envelope *)
(*****************************************************************************)

(* what a packet carries: IP's numbers *)
let ip_icmp = 1

(* a packet: IP's header of 20 bytes (version 4 and its length in
 * words, 0x45; the whole length; no fragment; 64 hops to live; what
 * it carries; the header's checksum; from; to), then what it carries *)
let ip_packet proto src dst payload =
  let head sum =
    net_byte.(0x45) ^ net_byte.(0) ^ net16 (20 + String.length payload)
    ^ net16 0 ^ net16 0 ^ net_byte.(64) ^ net_byte.(proto) ^ net16 sum
    ^ src ^ dst in
  head (net_sum (head 0)) ^ payload

(* a packet that came, if it is one for [me]: what it carries (IP's
 * number), who sent it, the bytes. Anything else is dropped without a
 * word, as on the Internet: a header that is not this plain one, a
 * length that is not the packet's, a checksum that is wrong, another's
 * address (for "", any address will do: a gateway's) *)
let ip_read me p =
  let n = String.length p in
  if n < 20 || Char.code p.[0] <> 0x45 then None
  else begin
    let total = net_get16 p 2 in
    if total < 20 || total > n || net_sum (String.sub p 0 20) <> 0
       || (me <> "" && String.sub p 16 4 <> me) then None
    else Some (Char.code p.[9], String.sub p 12 4, String.sub p 20 (total - 20))
  end

(*****************************************************************************)
(* ICMP: the echo *)
(*****************************************************************************)

(* "are you there?" and "yes": the question's kind is 8, the answer's
 * 0, and the answer returns the question's two numbers (whose
 * question, which one of them) and its bytes *)
(* an ICMP message's kind: echo's question, its answer, another (old:
 * the numbers, 8 and 0) *)
type icmp_kind = Echo_ask | Echo_answer | Icmp_other of int
let icmp_code k =
  match k with Echo_ask -> 8 | Echo_answer -> 0 | Icmp_other n -> n

let icmp_message (kind : icmp_kind) id seq data =
  (* old: let m sum = kind ^ 0 ^ net16 sum ^ net16 id ^ net16 seq ^ data in
   * m (net_sum (m 0)): the data copied at each ^ (it joins from the
   * right), ten times in all *)
  let head = net_byte.(icmp_code kind) ^ net_byte.(0) in
  let rest = (net16 id ^ net16 seq) ^ data in
  head ^ net16 (net_sum (head ^ rest)) ^ rest

(* its kind, its two numbers, its bytes; None when cut or damaged *)
let icmp_read b =
  if String.length b < 8 || net_sum b <> 0 then None
  else
    Some ((match Char.code b.[0] with
           | 8 -> Echo_ask
           | 0 -> Echo_answer
           | n -> Icmp_other n),
          net_get16 b 4, net_get16 b 6, String.sub b 8 (String.length b - 8))

(*****************************************************************************)
(* IL: its packets *)
(*****************************************************************************)

let ip_il = 40

(* IL's numbers have 32 bits and tiny-ml's int 31: the two ends here
 * start theirs small and stay under 2^30 (a number written as two
 * halves of 16 bits), and a packet with a larger one is not read (-1) *)
let net32 v = net16 ((v lsr 16) land 0xffff) ^ net16 (v land 0xffff)
let net_get32 s i =
  if net_get16 s i >= 0x4000 then -1
  else (65536 * net_get16 s i) + net_get16 s (i + 2)

(* a packet's seven kinds, Plan 9's numbers 0 to 6 on the wire (old:
 * the numbers, compared in if chains) *)
type il_kind =
  | Il_sync | Il_data | Il_dataquery | Il_ack | Il_query | Il_state | Il_close
(* (by their numbers; Array.of_list: tiny-ml reads no [| |]) *)
let il_kinds =
  Array.of_list
    [ Il_sync; Il_data; Il_dataquery; Il_ack; Il_query; Il_state; Il_close ]
let il_code k =
  match k with
  | Il_sync -> 0 | Il_data -> 1 | Il_dataquery -> 2 | Il_ack -> 3
  | Il_query -> 4 | Il_state -> 5 | Il_close -> 6

(* a packet's header, but its checksum and length: its kind, the
 * sender's port and the other's, its number, the last number its
 * sender received in order (ih_: the labels are one name space) *)
type il_header =
  { ih_kind : il_kind; ih_sport : int; ih_dport : int; ih_id : int;
    ih_ack : int }

(* IL's header, 18 bytes after IP's: a checksum of all of it and of the
 * message, the length of both, the kind, a byte not used here, the
 * sender's port and the other's, the packet's number (its id) and the
 * last number its sender received in order (its ack); then the
 * message, in a packet of data *)
let il_message (h : il_header) data =
  (* (the header first, then the message joined once: ^ joins from the
   * right, and a ^ b ^ data copies data at each ^. The sum's own two
   * bytes, 0 while adding and at an even place, add nothing: the sum
   * is the rest's) *)
  let head =
    net16 (18 + String.length data) ^ net_byte.(il_code h.ih_kind)
    ^ net_byte.(0) ^ net16 h.ih_sport ^ net16 h.ih_dport ^ net32 h.ih_id
    ^ net32 h.ih_ack in
  let rest = head ^ data in
  net16 (net_sum rest) ^ rest

(* its header and the message; None when cut, damaged or not ours to
 * read *)
let il_read b : (il_header * string) option =
  let n = String.length b in
  if n < 18 || net_get16 b 2 <> n || net_sum b <> 0
     || Char.code b.[4] > 6 || net_get32 b 10 < 0 || net_get32 b 14 < 0
  then None
  else
    Some ({ ih_kind = il_kinds.(Char.code b.[4]); ih_sport = net_get16 b 6;
            ih_dport = net_get16 b 8; ih_id = net_get32 b 10;
            ih_ack = net_get32 b 14 },
          String.sub b 18 (n - 18))

(*****************************************************************************)
(* IL: a connection *)
(*****************************************************************************)

(* where a connection is: it asked to talk (its sync sent), it was
 * asked (its own sync sent back), both know the other is there, it
 * said or was told the end, it is over *)
type il_at = Il_syncer | Il_syncee | Il_established | Il_closing | Il_closed

(* One end of a connection, in three records (tiny-ml's compiler for
 * tiny-machine makes one of ten fields at most). What it sends: its
 * next message's number; the messages sent that the other end has not
 * said it has, the oldest first; whether the program is done (the end
 * is said once everything sent has arrived); its next number when it
 * last asked where the other end is; when to act if nothing comes, how
 * many times it has since the last news (each wait is twice the one
 * before), and how many since anything at all was heard (patience).
 * What it receives: where the other end's numbers started, the last
 * received in order, and the last it said the program took; the
 * messages that came before one that is missing, those in order that
 * the program has not read. And itself: who and which ports, where it
 * is, the number its messages started from. *)
type il_sending = {
  mutable il_next : int; mutable il_unacked : (int * string) list;
  mutable il_leaving : bool; mutable il_asked : int;
  mutable il_timeout : int; mutable il_tries : int; mutable il_silent : int;
}

type il_receiving = {
  mutable il_rstart : int; mutable il_recvd : int; mutable il_told : int;
  mutable il_early : (int * string) list;
  mutable il_heard : string list;
}

type il = {
  il_me : string; il_peer : string; il_lport : int; il_rport : int;
  mutable il_at : il_at; il_start : int; il_s : il_sending;
  il_r : il_receiving;
}

(* at most 20 messages sent and not acknowledged, or received and not
 * read (Plan 9's window); a message's bytes; how long nothing may come
 * before asking, in its caller's ticks (tiny-kernel's: 2.5 ms), twice
 * as long each time; how many times before giving up *)
let il_window = 20
let il_max = 1024
let il_wait = 40
let il_patience = 5

let il_new me peer lport rport start at now =
  { il_me = me; il_peer = peer; il_lport = lport; il_rport = rport;
    il_at = at; il_start = start;
    il_s = { il_next = start + 1; il_unacked = []; il_leaving = false;
             il_asked = 0; il_timeout = now + il_wait; il_tries = 0;
             il_silent = 0 };
    il_r = { il_rstart = 0; il_recvd = 0; il_told = 0; il_early = [];
             il_heard = [] } }

(* The last message the program took. That, and not the last received,
 * is what an acknowledgement says: a sender holds at most [il_window]
 * messages not acknowledged, so it is never more than that ahead of a
 * program that reads slowly, and nothing received has to be dropped
 * for want of room. (old: the last received, il.c's; a picture's rows
 * sent 20 at once were received faster than read, those over 20
 * dropped, and asked for again one at a time: 11 s for 240 rows, 5
 * now.) *)
let il_taken c = c.il_r.il_recvd - List.length c.il_r.il_heard

(* a packet of a connection's: every one says it. But a state and a
 * close say all that was received, read or not: a state answers
 * "where are you?", for the other end to know what is missing and not
 * send again what only waits to be read; after a close nothing more
 * will be *)
let il_out c (kind : il_kind) id data =
  let ack =
    if kind = Il_close || kind = Il_state then c.il_r.il_recvd
    else (c.il_r.il_told <- il_taken c; c.il_r.il_told) in
  ip_packet ip_il c.il_me c.il_peer
    (il_message
       { ih_kind = kind; ih_sport = c.il_lport; ih_dport = c.il_rport;
         ih_id = id; ih_ack = ack }
       data)

let il_arm c now = c.il_s.il_timeout <- now + (il_wait lsl c.il_s.il_tries)
let il_fresh c now = c.il_s.il_tries <- 0; il_arm c now

(* whether a message may be written now; one written: its packet. It
 * is kept until the other end says it has it *)
let il_room c =
  (match c.il_at with Il_established -> true | _ -> false)
  && (not c.il_s.il_leaving)
  && List.length c.il_s.il_unacked < il_window

let il_write c data now =
  let id = c.il_s.il_next in
  c.il_s.il_next <- id + 1;
  (match c.il_s.il_unacked with [] -> il_fresh c now | _ -> ());
  c.il_s.il_unacked <- c.il_s.il_unacked @ [ id, data ];
  il_out c Il_data id data

(* the program is done: the end is said by [il_tick], once what was
 * written has arrived *)
let il_done c =
  match c.il_at with
  | Il_established -> c.il_s.il_leaving <- true
  | Il_syncer | Il_syncee -> c.il_at <- Il_closed
  | _ -> ()

(* the next message for the program, taken; whether a read would not
 * wait (a message, or the end) *)
let il_hear c =
  match c.il_r.il_heard with
  | [] -> None
  | m :: rest -> c.il_r.il_heard <- rest; Some m
let il_readable c =
  (match c.il_r.il_heard with [] -> false | _ -> true)
  || (match c.il_at with Il_closing | Il_closed -> true | _ -> false)

(* whether a read has nothing more to wait for *)
let il_over c = match c.il_at with Il_closing | Il_closed -> true | _ -> false

(* the other end has everything up to [ack]: forgotten here; whether
 * that was news *)
let il_ackto c ack now =
  let left = List.filter (fun (id, _) -> id > ack) c.il_s.il_unacked in
  if List.length left < List.length c.il_s.il_unacked then
    (c.il_s.il_unacked <- left; il_fresh c now; true)
  else false

(* a message that came: dropped if it came already, if it is too far
 * ahead or if the program reads too slowly (it will be sent again);
 * kept, and given to the program with those that were waiting for it
 * when it is the next *)
let rec il_pullup c =
  match List.filter (fun (id, _) -> id = c.il_r.il_recvd + 1) c.il_r.il_early with
  | (id, data) :: _ ->
      c.il_r.il_early <- List.filter (fun (i, _) -> i <> id) c.il_r.il_early;
      c.il_r.il_recvd <- id;
      c.il_r.il_heard <- c.il_r.il_heard @ [ data ];
      il_pullup c
  | [] -> ()

let il_take c id data =
  if id > c.il_r.il_recvd && id <= c.il_r.il_recvd + il_window
     && List.length c.il_r.il_heard < il_window
     && not (List.exists (fun (i, _) -> i = id) c.il_r.il_early) then begin
    c.il_r.il_early <- (id, data) :: c.il_r.il_early;
    il_pullup c
  end

(* "where are you?" answered: what was received. And what the program
 * took is to be said again at the next tick: the other end asks
 * because it heard nothing, and the packet that said it may be the one
 * that was lost *)
let il_where c =
  c.il_r.il_told <- -1;
  [ il_out c Il_state c.il_s.il_next "" ]

(* A packet for a connection where both ends talk. A question (query,
 * or data sent again, which asks too) is answered by where this end
 * is (state). An answer says what the other end received: if a
 * message sent is missing there, the oldest such is sent again, as a
 * question, so a wire that lost several is caught up one answer at a
 * time (each brings the other end one further, or is lost itself and
 * the timer asks again). It frees nothing here: only what the other
 * end's program took does. *)
let il_talk c kind id ack data now =
  if kind = Il_sync then
    (if id = c.il_r.il_rstart then
       [ ip_packet ip_il c.il_me c.il_peer
           (il_message
              { ih_kind = Il_ack; ih_sport = c.il_lport;
                ih_dport = c.il_rport; ih_id = c.il_s.il_next;
                ih_ack = c.il_r.il_rstart }
              "") ]
     else (c.il_at <- Il_closed; []))
  else if kind = Il_data || kind = Il_dataquery then begin
    ignore (il_ackto c ack now);
    il_take c id data;
    if kind = Il_dataquery then il_where c else []
  end
  else if kind = Il_ack then (ignore (il_ackto c ack now); [])
  else if kind = Il_query then (ignore (il_ackto c ack now); il_where c)
  else if kind = Il_state then begin
    (* (of those sent before the question: one sent since may be on
     * its way still. il.c's qt) *)
    match
      List.filter (fun (i, _) -> i > ack && i < c.il_s.il_asked)
        c.il_s.il_unacked
    with
    | (first, message) :: _ -> [ il_out c Il_dataquery first message ]
    | [] -> []
  end
  else if ack >= c.il_start && ack <= c.il_s.il_next then begin
    (* the other end is done: said back, what was not yet read stays *)
    c.il_r.il_recvd <- id;
    c.il_at <- Il_closing;
    c.il_s.il_unacked <- [];
    il_fresh c now;
    [ il_out c Il_close c.il_s.il_next "" ]
  end
  else []

(* a packet that came for this connection: the packets to send back.
 * The other end is there: patience starts again *)
let il_input c kind id ack data now =
  c.il_s.il_silent <- 0;
  match c.il_at with
  | Il_closed -> []
  | Il_syncer ->
      if kind = Il_sync && ack = c.il_start then begin
        c.il_r.il_recvd <- id;
        c.il_r.il_rstart <- id;
        c.il_at <- Il_established;
        il_fresh c now;
        [ il_out c Il_ack c.il_s.il_next "" ]
      end
      else if kind = Il_close && ack = c.il_start then (c.il_at <- Il_closed; [])
      else []
  | Il_syncee ->
      if kind = Il_sync then
        (if id = c.il_r.il_rstart then [ il_out c Il_sync c.il_start "" ]
         else [])
      else if kind = Il_close then
        (if ack = c.il_start then c.il_at <- Il_closed; [])
      else if (kind = Il_ack || kind = Il_data) && ack = c.il_start then
        (c.il_at <- Il_established;
         il_fresh c now;
         il_talk c kind id ack data now)
      else []
  | Il_established -> il_talk c kind id ack data now
  | Il_closing ->
      if kind = Il_close then begin
        (* the end said by both: over when the other end has heard
         * this one's; said once more by who said it first, for the
         * other to be over too (il.c: by both, the last to nobody) *)
        c.il_r.il_recvd <- id;
        let back = il_out c Il_close c.il_s.il_next "" in
        if ack = c.il_s.il_next then
          (c.il_at <- Il_closed; if c.il_s.il_leaving then [ back ] else [])
        else [ back ]
      end
      else []

(* said again when nothing came in time, the next wait twice this one
 * (32 times the first at most); when nothing at all was heard for
 * [il_patience] of them, the end said once, to whoever may still
 * hear, and the connection is over *)
let il_again c kind id now =
  if c.il_s.il_silent >= il_patience then
    (c.il_at <- Il_closed; [ il_out c Il_close c.il_s.il_next "" ])
  else begin
    c.il_s.il_silent <- c.il_s.il_silent + 1;
    c.il_s.il_tries <- min 5 (c.il_s.il_tries + 1);
    il_arm c now;
    [ il_out c kind id "" ]
  end

(* time passed: the packets to send. Its sync or its close again; the
 * end said, when the program is done and all has arrived; a question,
 * when messages sent were not acknowledged in time (the other end's
 * answer says which to send again: nothing is sent again blindly);
 * else what the program took acknowledged, if no packet said it yet *)
let il_tick c now =
  let late = now >= c.il_s.il_timeout in
  match c.il_at with
  | Il_closed -> []
  | Il_syncer | Il_syncee -> if late then il_again c Il_sync c.il_start now else []
  | Il_closing -> if late then il_again c Il_close c.il_s.il_next now else []
  | Il_established ->
      if c.il_s.il_unacked = [] && c.il_s.il_leaving then
        (c.il_at <- Il_closing;
         il_fresh c now;
         [ il_out c Il_close c.il_s.il_next "" ])
      else if c.il_s.il_unacked <> [] && late then
        (c.il_s.il_asked <- c.il_s.il_next;
         il_again c Il_query c.il_s.il_next now)
      else if c.il_r.il_told <> il_taken c then [ il_out c Il_ack c.il_s.il_next "" ]
      else []

(*****************************************************************************)
(* A machine's connections *)
(*****************************************************************************)

(* What one address has: its connections, the ports it listens on, the
 * connections made by others that no program took yet, and the number
 * the next connection's messages start from and its port on this side.
 * And, for a wire's end that is the way to other machines (a
 * gateway): the addresses and ports, not its own, that it will answer
 * the next sync for, as if it were them *)
type net_stack = {
  ns_me : string; mutable ns_conns : il list; mutable ns_ports : int list;
  mutable ns_fresh : il list; mutable ns_start : int;
  mutable ns_port : int; mutable ns_gate : bool;
  mutable ns_others : (string * int) list;
}

let net_stack me start =
  { ns_me = me; ns_conns = []; ns_ports = []; ns_fresh = []; ns_start = start;
    ns_port = 5000; ns_gate = false; ns_others = [] }

let net_conn s me peer lport rport at now =
  let c = il_new me peer lport rport s.ns_start at now in
  s.ns_start <- s.ns_start + 1000;
  s.ns_conns <- c :: s.ns_conns;
  c

(* a connection asked for: it, and its first packet *)
let net_dial s peer port now =
  let c = net_conn s s.ns_me peer s.ns_port port Il_syncer now in
  s.ns_port <- 5000 + ((s.ns_port - 4999) land 0x3fff);
  c, il_out c Il_sync c.il_start ""

(* time passed for every connection; those that are over forgotten *)
let net_tick s now =
  let out = List.concat (List.map (fun c -> il_tick c now) s.ns_conns) in
  s.ns_conns <-
    List.filter (fun c -> match c.il_at with Il_closed -> false | _ -> true)
      s.ns_conns;
  out

(* A packet of IL's: its connection's, by who sent it, who it is for
 * and the two ports. For none: a sync to a port listened on (or, a
 * gateway's, to an address and a port it said it would answer for,
 * once) makes a connection, its own sync sent back; anything else but
 * a close is answered by a close, which is how who dials a port nobody
 * listens on learns it *)
let net_il s now from to_ body =
  match il_read body with
  | None -> []
  | Some ({ ih_kind = kind; ih_sport = sport; ih_dport = dport; ih_id = id;
            ih_ack = ack }, data) -> (
      match
        List.filter
          (fun c -> c.il_peer = from && c.il_me = to_ && c.il_lport = dport
                    && c.il_rport = sport)
          s.ns_conns
      with
      | c :: _ -> il_input c kind id ack data now
      | [] ->
          let mine = to_ = s.ns_me && List.mem dport s.ns_ports
          and other = List.mem (to_, dport) s.ns_others in
          if kind = Il_sync && ack = 0 && (mine || other) then begin
            if other then
              s.ns_others <- List.filter (fun o -> o <> (to_, dport)) s.ns_others;
            let c = net_conn s to_ from dport sport Il_syncee now in
            c.il_r.il_rstart <- id;
            c.il_r.il_recvd <- id;
            s.ns_fresh <- s.ns_fresh @ [ c ];
            [ il_out c Il_sync c.il_start "" ]
          end
          else if kind <> Il_close then
            [ ip_packet ip_il to_ from
                (il_message
                   { ih_kind = Il_close; ih_sport = dport; ih_dport = sport;
                     ih_id = 0; ih_ack = id }
                   "") ]
          else [])

(*****************************************************************************)
(* A packet that came *)
(*****************************************************************************)

(* The packets to send back, and an answer to an echo if it is one (who
 * answers, the question's two numbers, its bytes), for who asked. A
 * question is answered here, by whoever has the address: the kernel,
 * and the host's end of the wire, which is this same function. What
 * IL's packets change is in the connections: their messages, their
 * state, [ns_fresh]. *)
let net_input s now packet =
  match ip_read (if s.ns_gate then "" else s.ns_me) packet with
  | None -> [], None
  | Some (proto, from, body) ->
      let to_ = String.sub packet 16 4 in
      if proto = ip_il then net_il s now from to_ body, None
      else if proto <> ip_icmp || to_ <> s.ns_me then [], None
      else (
        match icmp_read body with
        | None -> [], None
        | Some (kind, id, seq, data) ->
            match kind with
            | Echo_ask ->
                [ ip_packet ip_icmp s.ns_me from
                    (icmp_message Echo_answer id seq data) ], None
            | Echo_answer -> [], Some (from, id, seq, data)
            | Icmp_other _ -> [], None)
