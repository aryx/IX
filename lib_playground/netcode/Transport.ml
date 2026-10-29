(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's playground's libs/networking/protocols/Transport.ml, and its libs/networking/unix/Udp.ml's host and join over ix's Udp; no relay, no TLS; connect is called, not installed by a platform *)

(* See Transport.mli *)

type t = { send : string -> unit; receive : unit -> string list; status : unit -> string; player : unit -> int option }

type role =
  | Host of { bind : string; port : int }
  | Join of { host : string; port : int }
  | Relay of { host : string; port : int }

let hosting (caps : < Cap.network; Cap.fork; .. >) (bind : string) (port : int) : t =
  let peer = Udp.host caps ~address:bind ~port in
  {
    send = Udp.send peer;
    receive = (fun () -> Udp.arrived peer);
    status =
      (fun () ->
        match Udp.other peer with
        | None -> Printf.sprintf "hosting on %s:%d, waiting for a player" bind port
        | Some a -> Printf.sprintf "hosting on %s:%d, playing with %s" bind port a);
    player = (fun () -> Some 0);
  }

let joining (caps : < Cap.network; Cap.fork; .. >) (host : string) (port : int) : t =
  let peer = Udp.join caps ~address:host ~port in
  let heard = ref false in
  {
    send = Udp.send peer;
    receive =
      (fun () ->
        let packets = Udp.arrived peer in
        if packets <> [] then heard := true;
        packets);
    status =
      (fun () ->
        if !heard then Printf.sprintf "playing with %s:%d" host port
        else Printf.sprintf "joining %s:%d, waiting for an answer" host port);
    player = (fun () -> Some 1);
  }

let connect (caps : < Cap.network; Cap.fork; .. >) (role : role) : (t, string) result =
  try
    match role with
    | Host { bind; port } -> Ok (hosting caps bind port)
    | Join { host; port } -> Ok (joining caps host port)
    | Relay _ -> Error "a relay is a WebSocket, which ix has not"
  with
  | Unix.Unix_error (e, _, _) -> Error (Unix.error_message e)
  | Failure why -> Error why
