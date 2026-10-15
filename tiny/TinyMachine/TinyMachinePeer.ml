(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyMachinePeer.mli *)

(* an address said: "10.0.0.2" *)
let net_dotted a =
  string_of_int (Char.code a.[0]) ^ "." ^ string_of_int (Char.code a.[1]) ^ "." ^ string_of_int (Char.code a.[2]) ^ "."
  ^ string_of_int (Char.code a.[3])

(*****************************************************************************)
(* A packet said (the host's: who watches the wire) *)
(*****************************************************************************)

(* a packet in a few words, for who watches the wire: "echo? 1, 4
 * bytes, from 10.0.0.2 to 10.0.0.1", "data id 1001 ack 5000, 9 bytes,
 * from ..." *)
let net_describe p =
  if String.length p < 20 || Char.code p.[0] <> 0x45 || TinyKernelNetwork.net_sum (String.sub p 0 20) <> 0 then
    "not a packet, " ^ string_of_int (String.length p) ^ " bytes"
  else begin
    let body = String.sub p 20 (String.length p - 20) in
    let bytes data = string_of_int (String.length data) ^ " bytes" in
    let what =
      if Char.code p.[9] = TinyKernelNetwork.ip_il then (
        match TinyKernelNetwork.il_read body with
        | None -> "il, damaged"
        | Some (kind, _, _, id, ack, data) ->
            (if kind = TinyKernelNetwork.il_sync then "sync" else if kind = TinyKernelNetwork.il_data then "data" else if kind = TinyKernelNetwork.il_dataquery then "data?" else if kind = TinyKernelNetwork.il_ack then "ack"
             else if kind = TinyKernelNetwork.il_query then "query" else if kind = TinyKernelNetwork.il_state then "state" else "close")
            ^ " id " ^ string_of_int id ^ " ack " ^ string_of_int ack ^ (if data = "" then "" else ", " ^ bytes data))
      else if Char.code p.[9] <> TinyKernelNetwork.ip_icmp then "protocol " ^ string_of_int (Char.code p.[9]) ^ ", " ^ bytes body
      else (
        match TinyKernelNetwork.icmp_read body with
        | None -> "icmp, damaged"
        | Some (kind, _, seq, data) ->
            (if kind = TinyKernelNetwork.icmp_ask then "echo? " else if kind = TinyKernelNetwork.icmp_answer then "echo! " else "icmp " ^ string_of_int kind ^ " ")
            ^ string_of_int seq ^ ", " ^ bytes data) in
    what ^ ", from " ^ net_dotted (String.sub p 12 4) ^ " to " ^ net_dotted (String.sub p 16 4)
  end

(*****************************************************************************)
(* The peer *)
(*****************************************************************************)

(* Both are in the machine's instructions, so they follow its speed:
 * 5 ms and 2.5 ms of its time. *)
let latency () = !TinyMachineDevices.rate / 200

let tick () = !TinyMachineDevices.rate / 400

(* a connection to one of the peer's own ports: its line not read yet,
 * what answers it asked, or the messages left to send *)
type serving = {
  conn : TinyKernelNetwork.il; ask : string -> (string list -> unit) -> unit; mutable todo : string list option; mutable asked : bool;
}

type relay = { take : unit -> string option; put : string -> unit; shut : unit -> unit }

(* a connection that is a program's outside: the bytes that came from
 * it and are not yet messages, whether it has ended *)
type relaying = { rconn : TinyKernelNetwork.il; relay : relay; mutable coming : string; mutable ended : bool }

type outside = { name : string -> string; connect : string -> int -> relay option }

type t = {
  stack : TinyKernelNetwork.net_stack; give : int -> string -> unit; said : string -> string -> unit;
  document : string -> (string list -> unit) -> unit; outside : outside option;
  mutable now : int; mutable awake : bool; mutable serving : serving list; mutable sent : int; mutable lost : int list;
  mutable relays : relaying list; mutable agreed : ((string * int * int) * relay) list;
}

let create ~give ~said ~document ~outside =
  let stack = TinyKernelNetwork.net_stack TinyKernelNetwork.net_peer 5000 in
  stack.ns_ports <- [ 70; 53 ];
  stack.ns_gate <- outside <> None;
  { stack = stack; give = give; said = said; document = document; outside = outside; now = 0; awake = false; serving = []; sent = 0;
    lost = []; relays = []; agreed = [] }

let lose p n = p.lost <- (p.sent + n) :: p.lost

let rec messages text =
  let n = String.length text in
  if n = 0 then [] else if n <= TinyKernelNetwork.il_max then [ text ]
  else String.sub text 0 TinyKernelNetwork.il_max :: messages (String.sub text TinyKernelNetwork.il_max (n - TinyKernelNetwork.il_max))

(* a picture with its text: a first message "t w h" (how many messages
 * of text follow, then h rows of w pixels, a row a message); a kept
 * one read ("w h", a line; the pixels; the text) *)
let picture text w h pixels =
  let texts = messages text in
  (string_of_int (List.length texts) ^ " " ^ string_of_int w ^ " " ^ string_of_int h) :: texts
  @ List.init h (fun y -> String.sub pixels (y * w) w)

let kept file =
  match String.index_opt file '\n' with
  | None -> None
  | Some i -> (
      match List.map int_of_string_opt (String.split_on_char ' ' (String.sub file 0 i)) with
      | [ Some w; Some h ] when w > 0 && w <= TinyKernelNetwork.il_max && h > 0 && i + 1 + (w * h) <= String.length file ->
          let after = i + 1 + (w * h) in
          Some (picture (String.sub file after (String.length file - after)) w h (String.sub file (i + 1) (w * h)))
      | _ -> None)

(*****************************************************************************)
(* www *)
(*****************************************************************************)

let starts p s = String.length s >= String.length p && String.sub s 0 (String.length p) = p
let wiki_prefix = "/wiki/" and rest_prefix = "/api/rest_v1/page/html/"

(* a Wikipedia address cut in two: its host (en.wikipedia.org) and the
 * article's title, if it is one *)
let wikipedia url =
  match String.index_opt url ':' with
  | Some i when starts "https://" url || starts "http://" url ->
      let rest = String.sub url (i + 3) (String.length url - i - 3) in
      (match String.index_opt rest '/' with
       | Some j ->
           let host = String.sub rest 0 j and path = String.sub rest j (String.length rest - j) in
           let title p = String.sub path (String.length p) (String.length path - String.length p) in
           if not (Filename.check_suffix host ".wikipedia.org") then None
           else if starts wiki_prefix path then Some (host, title wiki_prefix)
           else if starts rest_prefix path then Some (host, title rest_prefix)
           else None
       | None -> None)
  | _ -> None

let www_address typed =
  let s = String.trim typed in
  let s = match String.index_opt s '#' with Some i -> String.sub s 0 i | None -> s in
  let url =
    if starts "https://" s || starts "http://" s then s
    else
      let first = match String.index_opt s '/' with Some i -> String.sub s 0 i | None -> s in
      if String.contains first '.' && not (String.contains first ' ') then "https://" ^ s
      else "https://en.wikipedia.org/wiki/" ^ String.map (fun c -> if c = ' ' then '_' else c) s in
  match wikipedia url with
  | Some (host, title) -> "https://" ^ host ^ rest_prefix ^ title
  | None -> url

let www_kept url =
  match wikipedia url with
  | Some (_, title) when title <> "" && not (String.contains title '/') && title.[0] <> '.' -> Some (title ^ ".html")
  | _ -> None

let out p packets =
  List.iter (fun packet ->
    p.sent <- p.sent + 1;
    if List.mem p.sent p.lost then p.said "x" packet else (p.said "<" packet; p.give (latency ()) packet)) packets

(* A connection the machine asks for to another address than the
 * peer's: the outside is asked first, and if it has a way there the
 * stack will answer that sync as that address (TinyKernelNetwork's gateway).
 * So a dial to a port nothing listens on fails in the machine too. *)
let gate p packet =
  match p.outside, TinyKernelNetwork.ip_read "" packet with
  | Some outside, Some (proto, _, body) when proto = TinyKernelNetwork.ip_il && String.sub packet 16 4 <> TinyKernelNetwork.net_peer -> (
      let to_ = String.sub packet 16 4 in
      match TinyKernelNetwork.il_read body with
      | Some (kind, sport, dport, _, 0, _)
        when kind = TinyKernelNetwork.il_sync
             && not (List.exists (fun (c : TinyKernelNetwork.il) -> c.il_me = to_ && c.il_lport = dport && c.il_rport = sport) p.stack.ns_conns) -> (
          match outside.connect (net_dotted to_) dport with
          | Some relay ->
              p.stack.ns_others <- (to_, dport) :: p.stack.ns_others;
              p.agreed <- ((to_, dport, sport), relay) :: p.agreed
          | None -> ())
      | _ -> ())
  | _ -> ()

(* a relay's turn: the machine's messages to the outside; the outside's
 * bytes, 4 KB ahead at most, cut in messages while the connection has
 * room; the outside's end said when all of it was sent; the
 * connection's end the outside's *)
let relay_turn p (r : relaying) =
  let rec hear () = match TinyKernelNetwork.il_hear r.rconn with Some m -> r.relay.put m; hear () | None -> () in
  hear ();
  if (not r.ended) && String.length r.coming < 4096 then (match r.relay.take () with Some b -> r.coming <- r.coming ^ b | None -> r.ended <- true);
  while r.coming <> "" && TinyKernelNetwork.il_room r.rconn do
    let n = min TinyKernelNetwork.il_max (String.length r.coming) in
    out p [ TinyKernelNetwork.il_write r.rconn (String.sub r.coming 0 n) p.now ];
    r.coming <- String.sub r.coming n (String.length r.coming - n)
  done;
  if r.ended && r.coming = "" then TinyKernelNetwork.il_done r.rconn

(* the connections just made taken: one for another address is its
 * relay's, one to port 53 asks an address of a name, one to port 70 a
 * document; a line that came answered; an answer's messages sent while
 * the connection has room, and after the last the end said; the
 * relays' turns *)
let serve p =
  List.iter (fun (conn : TinyKernelNetwork.il) ->
    let key = conn.il_me, conn.il_lport, conn.il_rport in
    match List.assoc_opt key p.agreed with
    | Some relay ->
        p.agreed <- List.filter (fun (k, _) -> k <> key) p.agreed;
        p.relays <- { rconn = conn; relay = relay; coming = ""; ended = false } :: p.relays
    | None ->
        let name line answer = match p.outside with
          | Some o -> (match o.name line with "" -> answer [] | a -> answer [ a ])
          | None -> answer [] in
        p.serving <- { conn = conn; ask = (if conn.il_lport = 53 then name else p.document); todo = None; asked = false } :: p.serving)
    p.stack.ns_fresh;
  p.stack.ns_fresh <- [];
  List.iter (relay_turn p) p.relays;
  p.relays <- List.filter (fun (r : relaying) -> if TinyKernelNetwork.il_over r.rconn then (r.relay.shut (); false) else true) p.relays;
  List.iter (fun (s : serving) ->
    if not s.asked then (
      match TinyKernelNetwork.il_hear s.conn with
      | Some line -> s.asked <- true; s.ask (String.trim line) (fun l -> s.todo <- Some l)
      | None -> ());
    let rec push () =
      match s.todo with
      | Some (m :: rest) when TinyKernelNetwork.il_room s.conn -> s.todo <- Some rest; out p [ TinyKernelNetwork.il_write s.conn m p.now ]; push ()
      | Some [] -> TinyKernelNetwork.il_done s.conn
      | _ -> () in
    push ()) p.serving;
  p.serving <- List.filter (fun (s : serving) -> not (TinyKernelNetwork.il_over s.conn || s.todo = Some [])) p.serving

(* what there is to do, and a clock only while there is a connection *)
let poll p =
  serve p;
  if (not p.awake) && p.stack.ns_conns <> [] then (p.awake <- true; p.give (tick ()) "")

let send p packet =
  if packet = "" then begin
    p.awake <- false;
    p.now <- p.now + 1;
    out p (TinyKernelNetwork.net_tick p.stack p.now)
  end
  else (p.said ">" packet; gate p packet; out p (fst (TinyKernelNetwork.net_input p.stack p.now packet)));
  poll p

let dial p port relay =
  let conn, sync = TinyKernelNetwork.net_dial p.stack TinyKernelNetwork.net_machine port p.now in
  out p [ sync ];
  p.relays <- { rconn = conn; relay = relay; coming = ""; ended = false } :: p.relays;
  poll p
