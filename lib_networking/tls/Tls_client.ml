(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's playground's libs/networking/unix/Tls_client.ml; the roots said by the caller (no optional argument), files read with Cap.open_in, no mutex, no Transport of lines (docs/plans/plan_browser.md) *)

(* See Tls_client.mli *)

(* (the last two mini-9pi's: its card's, and the one of an image without a card, in the kernel's /boot) *)
let bundles =
  [ "/etc/ssl/certs/ca-certificates.crt"; "/etc/pki/tls/certs/ca-bundle.crt"; "/etc/ssl/cert.pem"; "/etc/ssl/ca-bundle.pem";
    "/lib/tls/ca.pem"; "/boot/ca.pem" ]
let roots : X509.roots option ref = ref None

let system_roots (caps : < Cap.open_in; .. >) : X509.roots =
  match !roots with
  | Some r -> r
  | None ->
      let r =
        match List.find_opt Sys.file_exists bundles with
        (* old: each parsed here (List.filter_map ... X509.parse): X509.roots_of_der parses the one a chain names *)
        | Some path -> X509.roots_of_der (Pem.certificates (FS.read caps (Fpath.v path)))
        | None -> X509.roots []
      in
      roots := Some r;
      r

let trust_file (caps : < Cap.open_in; .. >) (path : string) : unit =
  roots := Some (X509.roots_of_der (Pem.certificates (FS.read caps (Fpath.v path))))

(* randomness from the kernel *)
(* (Plan 9's is /dev/random: on mini-9pi the board's generator) *)
let random (caps : < Cap.open_in; .. >) (n : int) : string =
  let file = if Sys.file_exists "/dev/urandom" then "/dev/urandom" else "/dev/random" in
  FS.with_open_in caps (fun (ch : Chan.i) -> really_input_string ch.ic n) (Fpath.v file)

(* The chains already checked in this program -- the host and the
   certificates' bytes -- until the first of them expires: a page's
   twenty pictures from one host are one chain checked, not twenty
   (three signatures each, 30 ms apiece). The handshake's own signature,
   CertificateVerify, is checked every time: it proves the server has
   the key now. (ix: no mutex, there being no threads.) *)
let verified : (string, float) Hashtbl.t = Hashtbl.create 16

let verify_cached ~(trust : X509.roots) ~(host : string) (chain : X509.t list) : (unit, string) result =
  let now = Unix.gettimeofday () in
  let key = host ^ "\000" ^ String.concat "" (List.map (fun (c : X509.t) -> c.der) chain) in
  let known = Hashtbl.find_opt verified key in
  match known with
  | Some until when now <= until -> Ok ()
  | _ ->
      let r = X509.verify ~trust ~now ~host chain in
      if r = Ok () then (
        let until = List.fold_left (fun t (c : X509.t) -> min t c.not_after) infinity chain in
        Hashtbl.replace verified key until);
      r

type t = {
  fd : Unix.file_descr;
  mutable machine : Tls13.t;
  mutable outbox : string; (* application data waiting for the handshake *)
  mutable eof : bool;
  mutable closed : bool;
}

let write (t : t) (bytes : string) : unit = if bytes <> "" && not t.closed then try Tcp.send_all t.fd bytes with Unix.Unix_error _ -> t.eof <- true

let connect (caps : < Cap.network; Cap.open_in; .. >) ~(trust : X509.roots) ~(host : string) ~(port : int) : (t, string) result =
  match Tcp.connect caps ~host ~port with
  | exception Unix.Unix_error (e, _, _) -> Error (Printf.sprintf "can't reach %s:%d: %s" host port (Unix.error_message e))
  | exception Failure why -> Error why
  | fd ->
      let r = random caps 96 in
      let verify chain = verify_cached ~trust ~host chain in
      let machine, hello = Tls13.client ~host ~random:(String.sub r 0 32) ~secret:(String.sub r 32 32) ~session_id:(String.sub r 64 32) ~verify in
      let t = { fd; machine; outbox = ""; eof = false; closed = false } in
      write t hello;
      Ok t

(* the handshake done: what was queued, written *)
let flush (t : t) : unit =
  if Tls13.state t.machine = Open && t.outbox <> "" then begin
    let m, records = Tls13.write t.machine t.outbox in
    t.machine <- m;
    t.outbox <- "";
    write t records
  end

let step (t : t) : unit =
  if not (t.eof || t.closed) then begin
    (* old: a read that does not block here (Unix.set_nonblock at connect, EAGAIN): Tcp.arrived's now, which Plan 9 has another of *)
    let bytes = match Tcp.arrived t.fd with Some b -> b | None -> t.eof <- true; "" in
    if bytes <> "" then begin
      let m, answer = Tls13.received t.machine bytes in
      t.machine <- m;
      write t answer
    end;
    flush t
  end

let state (t : t) : Tls13.state =
  match Tls13.state t.machine with Handshaking when t.eof -> Failed "the connection closed during the handshake" | s -> s

let machine (t : t) : Tls13.t = t.machine

(* (on a connection open, the request written at once: step reads
 * first, and a read waits on Plan 9 (Tcp.arrived) -- on a kept
 * connection, whose server says nothing until it is asked, for all of
 * Tcp.timeout, then the connection taken as lost: each request after
 * a page's first 30 s and a new handshake, mini-netscape on mini-9pi.
 * old: step t, whatever the state) *)
let send (t : t) (data : string) : unit =
  t.outbox <- t.outbox ^ data;
  if Tls13.state t.machine = Open then flush t else step t

let receive (t : t) : string =
  step t;
  let m, data = Tls13.read t.machine in
  t.machine <- m;
  data

let ended (t : t) : bool = t.eof || t.closed
let wait (t : t) (seconds : float) : unit = if not t.closed then Tcp.wait t.fd seconds

let close (t : t) : unit =
  if not t.closed then begin
    let m, alert = Tls13.close t.machine in
    t.machine <- m;
    write t alert;
    t.closed <- true;
    try Unix.close t.fd with Unix.Unix_error _ -> ()
  end

let exchange (caps : < Cap.network; Cap.open_in; .. >) ~(trust : X509.roots) ~(host : string) ~(port : int) (request : string) : (string, string) result =
  let timeout = Tcp.timeout in
  match connect caps ~trust ~host ~port with
  | Error e -> Error e
  | Ok t ->
      send t request;
      let answer = Buffer.create 65536 in
      let rec wait silent =
        match state t with
        | Failed why -> Error why
        | Closed -> Ok ()
        | _ when t.eof -> Ok ()
        | _ when silent > timeout -> Error (Printf.sprintf "%s: no answer in %.0f s" host timeout)
        | _ ->
            let got = receive t in
            Buffer.add_string answer got;
            if got = "" then (
              Tcp.wait t.fd 0.05;
              wait (silent +. 0.05))
            else wait 0.
      in
      let r = wait 0. in
      Buffer.add_string answer (receive t);
      close t;
      Result.map (fun () -> Buffer.contents answer) r
