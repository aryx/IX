(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyLibPeer.mli *)

let latency = 40000
let tick = 20000

(* a connection to port 70: its line not read yet, its document asked
 * for, or the messages left to send *)
type serving = { conn : TinyNetwork.il; mutable todo : string list option; mutable asked : bool }

type t = {
  stack : TinyNetwork.net_stack; give : int -> string -> unit; said : string -> string -> unit;
  document : string -> (string list -> unit) -> unit;
  mutable now : int; mutable awake : bool; mutable serving : serving list; mutable sent : int; mutable lost : int list;
}

let create ~give ~said ~document =
  let stack = TinyNetwork.net_stack TinyNetwork.net_peer 5000 in
  stack.ns_ports <- [ 70 ];
  { stack = stack; give = give; said = said; document = document; now = 0; awake = false; serving = []; sent = 0; lost = [] }

let lose p n = p.lost <- (p.sent + n) :: p.lost

let rec messages text =
  let n = String.length text in
  if n = 0 then [] else if n <= TinyNetwork.il_max then [ text ]
  else String.sub text 0 TinyNetwork.il_max :: messages (String.sub text TinyNetwork.il_max (n - TinyNetwork.il_max))

let out p packets =
  List.iter (fun packet ->
    p.sent <- p.sent + 1;
    if List.mem p.sent p.lost then p.said "x" packet else (p.said "<" packet; p.give latency packet)) packets

(* the connections just made taken; a line that came answered by its
 * document; a document's messages sent while the connection has room,
 * and after the last the end said *)
let serve p =
  List.iter (fun conn -> p.serving <- { conn = conn; todo = None; asked = false } :: p.serving) p.stack.ns_fresh;
  p.stack.ns_fresh <- [];
  List.iter (fun (s : serving) ->
    if not s.asked then (
      match TinyNetwork.il_hear s.conn with
      | Some line -> s.asked <- true; p.document (String.trim line) (fun l -> s.todo <- Some l)
      | None -> ());
    let rec push () =
      match s.todo with
      | Some (m :: rest) when TinyNetwork.il_room s.conn -> s.todo <- Some rest; out p [ TinyNetwork.il_write s.conn m p.now ]; push ()
      | Some [] -> TinyNetwork.il_done s.conn
      | _ -> () in
    push ()) p.serving;
  p.serving <- List.filter (fun (s : serving) -> not (TinyNetwork.il_over s.conn || s.todo = Some [])) p.serving

let send p packet =
  if packet = "" then begin
    p.awake <- false;
    p.now <- p.now + 1;
    out p (TinyNetwork.net_tick p.stack p.now)
  end
  else (p.said ">" packet; out p (fst (TinyNetwork.net_input p.stack p.now packet)));
  serve p;
  (* a clock only while there is a connection *)
  if (not p.awake) && p.stack.ns_conns <> [] then (p.awake <- true; p.give tick "")
