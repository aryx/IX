(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Udp.mli *)

let ask (_caps : < Cap.network; .. >) ~(address : string) ~(port : int) (packet : string) (seconds : float) : string option =
  let fd = Unix.socket Unix.PF_INET Unix.SOCK_DGRAM 0 in
  Fun.protect ~finally:(fun () -> Unix.close fd) (fun () ->
    Unix.connect fd (Unix.ADDR_INET (Unix.inet_addr_of_string address, port));
    ignore (Unix.write_substring fd packet 0 (String.length packet));
    match Unix.select [ fd ] [] [] seconds with
    | [], _, _ -> None
    | _ ->
        let b = Bytes.create 1500 in
        let n = Unix.read fd b 0 1500 in
        Some (Bytes.sub_string b 0 n))

(* A game's socket (the author's playground's libs/networking/unix/Udp.ml,
 * its host and join): never waited on. A read is asked only when
 * select says a packet is there (the playground's socket is
 * non-blocking, and its read's EAGAIN the end). *)
type peer = { fd : Unix.file_descr; mutable other : Unix.sockaddr option; hosting : bool }

let resolve (host : string) (port : int) : Unix.sockaddr =
  match Unix.getaddrinfo host (string_of_int port) [ Unix.AI_SOCKTYPE Unix.SOCK_DGRAM; Unix.AI_FAMILY Unix.PF_INET ] with
  | a :: _ -> a.ai_addr
  | [] -> failwith (Printf.sprintf "Udp: can't resolve %S" host)

let host (_caps : < Cap.network; Cap.fork; .. >) ~(address : string) ~(port : int) : peer =
  let fd = Unix.socket Unix.PF_INET Unix.SOCK_DGRAM 0 in
  Unix.setsockopt fd Unix.SO_REUSEADDR true;
  Unix.bind fd (resolve address port);
  { fd; other = None; hosting = true }

let join (_caps : < Cap.network; Cap.fork; .. >) ~(address : string) ~(port : int) : peer =
  { fd = Unix.socket Unix.PF_INET Unix.SOCK_DGRAM 0; other = Some (resolve address port); hosting = false }

(* a lost send is a lost packet, which lockstep survives: never raise *)
let send (p : peer) (s : string) : unit =
  match p.other with
  | Some a -> (try ignore (Unix.sendto_substring p.fd s 0 (String.length s) [] a) with Unix.Unix_error _ -> ())
  | None -> ()

(* (a host's player: whoever speaks first; the others' packets, and for
 * the one who joined anyone's but the host's, are dropped) *)
let arrived (p : peer) : string list =
  let buf = Bytes.create 65536 in
  let rec go (acc : string list) : string list =
    match Unix.select [ p.fd ] [] [] 0. with
    | [], _, _ -> List.rev acc
    | _ -> (
        match Unix.recvfrom p.fd buf 0 (Bytes.length buf) [] with
        | n, from ->
            if p.other = None && p.hosting then p.other <- Some from;
            go (if p.other = Some from then Bytes.sub_string buf 0 n :: acc else acc)
        | exception Unix.Unix_error _ -> List.rev acc)
  in
  go []

let other (p : peer) : string option =
  match p.other with
  | Some (Unix.ADDR_INET (ip, port)) -> Some (Printf.sprintf "%s:%d" (Unix.string_of_inet_addr ip) port)
  | Some (Unix.ADDR_UNIX path) -> Some path
  | None -> None
