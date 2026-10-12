(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyLibPeer.mli *)

let latency = 40000
let tick = 20000

(* a connection to one of the peer's own ports: its line not read yet,
 * what answers it asked, or the messages left to send *)
type serving = {
  conn : TinyNetwork.il; ask : string -> (string list -> unit) -> unit; mutable todo : string list option; mutable asked : bool;
}

type relay = { take : unit -> string option; put : string -> unit; shut : unit -> unit }

(* a connection that is a program's outside: the bytes that came from
 * it and are not yet messages, whether it has ended *)
type relaying = { rconn : TinyNetwork.il; relay : relay; mutable coming : string; mutable ended : bool }

type outside = { name : string -> string; connect : string -> int -> relay option }

type t = {
  stack : TinyNetwork.net_stack; give : int -> string -> unit; said : string -> string -> unit;
  document : string -> (string list -> unit) -> unit; outside : outside option;
  mutable now : int; mutable awake : bool; mutable serving : serving list; mutable sent : int; mutable lost : int list;
  mutable relays : relaying list; mutable agreed : ((string * int * int) * relay) list;
}

let create ~give ~said ~document ~outside =
  let stack = TinyNetwork.net_stack TinyNetwork.net_peer 5000 in
  stack.ns_ports <- [ 70; 53 ];
  stack.ns_gate <- outside <> None;
  { stack = stack; give = give; said = said; document = document; outside = outside; now = 0; awake = false; serving = []; sent = 0;
    lost = []; relays = []; agreed = [] }

let lose p n = p.lost <- (p.sent + n) :: p.lost

let rec messages text =
  let n = String.length text in
  if n = 0 then [] else if n <= TinyNetwork.il_max then [ text ]
  else String.sub text 0 TinyNetwork.il_max :: messages (String.sub text TinyNetwork.il_max (n - TinyNetwork.il_max))

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
      | [ Some w; Some h ] when w > 0 && w <= TinyNetwork.il_max && h > 0 && i + 1 + (w * h) <= String.length file ->
          let after = i + 1 + (w * h) in
          Some (picture (String.sub file after (String.length file - after)) w h (String.sub file (i + 1) (w * h)))
      | _ -> None)

let out p packets =
  List.iter (fun packet ->
    p.sent <- p.sent + 1;
    if List.mem p.sent p.lost then p.said "x" packet else (p.said "<" packet; p.give latency packet)) packets

(* A connection the machine asks for to another address than the
 * peer's: the outside is asked first, and if it has a way there the
 * stack will answer that sync as that address (TinyNetwork's gateway).
 * So a dial to a port nothing listens on fails in the machine too. *)
let gate p packet =
  match p.outside, TinyNetwork.ip_read "" packet with
  | Some outside, Some (proto, _, body) when proto = TinyNetwork.ip_il && String.sub packet 16 4 <> TinyNetwork.net_peer -> (
      let to_ = String.sub packet 16 4 in
      match TinyNetwork.il_read body with
      | Some (kind, sport, dport, _, 0, _)
        when kind = TinyNetwork.il_sync
             && not (List.exists (fun (c : TinyNetwork.il) -> c.il_me = to_ && c.il_lport = dport && c.il_rport = sport) p.stack.ns_conns) -> (
          match outside.connect (TinyNetwork.net_dotted to_) dport with
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
  let rec hear () = match TinyNetwork.il_hear r.rconn with Some m -> r.relay.put m; hear () | None -> () in
  hear ();
  if (not r.ended) && String.length r.coming < 4096 then (match r.relay.take () with Some b -> r.coming <- r.coming ^ b | None -> r.ended <- true);
  while r.coming <> "" && TinyNetwork.il_room r.rconn do
    let n = min TinyNetwork.il_max (String.length r.coming) in
    out p [ TinyNetwork.il_write r.rconn (String.sub r.coming 0 n) p.now ];
    r.coming <- String.sub r.coming n (String.length r.coming - n)
  done;
  if r.ended && r.coming = "" then TinyNetwork.il_done r.rconn

(* the connections just made taken: one for another address is its
 * relay's, one to port 53 asks an address of a name, one to port 70 a
 * document; a line that came answered; an answer's messages sent while
 * the connection has room, and after the last the end said; the
 * relays' turns *)
let serve p =
  List.iter (fun (conn : TinyNetwork.il) ->
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
  p.relays <- List.filter (fun (r : relaying) -> if TinyNetwork.il_over r.rconn then (r.relay.shut (); false) else true) p.relays;
  List.iter (fun (s : serving) ->
    if not s.asked then (
      match TinyNetwork.il_hear s.conn with
      | Some line -> s.asked <- true; s.ask (String.trim line) (fun l -> s.todo <- Some l)
      | None -> ());
    let rec push () =
      match s.todo with
      | Some (m :: rest) when TinyNetwork.il_room s.conn -> s.todo <- Some rest; out p [ TinyNetwork.il_write s.conn m p.now ]; push ()
      | Some [] -> TinyNetwork.il_done s.conn
      | _ -> () in
    push ()) p.serving;
  p.serving <- List.filter (fun (s : serving) -> not (TinyNetwork.il_over s.conn || s.todo = Some [])) p.serving

(* what there is to do, and a clock only while there is a connection *)
let poll p =
  serve p;
  if (not p.awake) && p.stack.ns_conns <> [] then (p.awake <- true; p.give tick "")

let send p packet =
  if packet = "" then begin
    p.awake <- false;
    p.now <- p.now + 1;
    out p (TinyNetwork.net_tick p.stack p.now)
  end
  else (p.said ">" packet; gate p packet; out p (fst (TinyNetwork.net_input p.stack p.now packet)));
  poll p

let dial p port relay =
  let conn, sync = TinyNetwork.net_dial p.stack TinyNetwork.net_machine port p.now in
  out p [ sync ];
  p.relays <- { rconn = conn; relay = relay; coming = ""; ended = false } :: p.relays;
  poll p
