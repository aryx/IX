(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Lines.mli *)

(* what the two kinds of connection have to do: send bytes, take what
 * has come (None: closed), wait for more, close; and why it ended, if
 * not by a close *)
type way = {
  send : string -> unit;
  arrived : unit -> string option;
  wait : float -> unit;
  stop : unit -> unit;
  why : unit -> string option;
}

(* [pending]: the bytes come and not yet a whole line *)
type t = { way : way; mutable pending : string; mutable ended : bool }

let make (way : way) : t = { way; pending = ""; ended = false }

let of_fd (fd : Unix.file_descr) : t =
  make
    {
      send = Tcp.send_all fd;
      arrived = (fun () -> Tcp.arrived fd);
      wait = Tcp.wait fd;
      stop = (fun () -> try Unix.close fd with Unix.Unix_error _ -> ());
      why = (fun () -> None);
    }

let plain (caps : < Cap.network; Cap.open_in; .. >) ~(host : string)
    ~(port : int) : (t, string) result =
  match Tcp.connect caps ~host ~port with
  | fd -> Ok (of_fd fd)
  | exception Unix.Unix_error (e, _, _) -> Error (Unix.error_message e)
  | exception Failure why -> Error why

let tls (caps : < Cap.network; Cap.open_in; .. >) ~(trust : X509.roots)
    ~(host : string) ~(port : int) : (t, string) result =
  match Tls_client.connect caps ~trust ~host ~port with
  | Error why -> Error why
  | Ok c ->
      (* (the TLS machine's own failure, a certificate refused, is an
       * end of the connection, its reason kept) *)
      let why () =
        match Tls_client.state c with Tls13.Failed w -> Some w | _ -> None
      in
      let arrived () =
        let data = Tls_client.receive c in
        if why () <> None || (data = "" && Tls_client.ended c) then None
        else Some data
      in
      Ok
        (make
           {
             send = Tls_client.send c;
             arrived;
             wait = Tls_client.wait c;
             stop = (fun () -> Tls_client.close c);
             why;
           })

let send_line (t : t) (line : string) : unit = t.way.send (line ^ "\r\n")

(* a whole line in [pending], taken *)
let take (t : t) : string option =
  match String.index_opt t.pending '\n' with
  | None -> None
  | Some i ->
      let line = String.sub t.pending 0 i in
      t.pending <-
        String.sub t.pending (i + 1) (String.length t.pending - i - 1);
      let n = String.length line in
      Some (if n > 0 && line.[n - 1] = '\r' then String.sub line 0 (n - 1)
            else line)


(* more of what comes, waited for until [deadline]; false when there is
 * no more *)
let more (t : t) (deadline : float) : bool =
  let rec go () =
    if t.ended then false
    else
      match t.way.arrived () with
      | None -> t.ended <- true; false
      | Some "" ->
          let left = deadline -. Unix.gettimeofday () in
          if left <= 0. then false else begin t.way.wait left; go () end
      | Some data -> t.pending <- t.pending ^ data; true
  in
  go ()

let bytes (t : t) (n : int) : string option =
  let deadline = Unix.gettimeofday () +. Tcp.timeout in
  let rec go () =
    if String.length t.pending >= n then begin
      let b = String.sub t.pending 0 n in
      t.pending <- String.sub t.pending n (String.length t.pending - n);
      Some b
    end
    else if more t deadline then go ()
    else None
  in
  go ()

let line (t : t) : string option =
  let deadline = Unix.gettimeofday () +. Tcp.timeout in
  let rec go () =
    match take t with
    | Some l -> Some l
    | None -> if more t deadline then go () else None
  in
  go ()

let talk (t : t) (step : 'm -> string -> 'm * string list) (machine : 'm)
    (finished : 'm -> bool) : 'm =
  let rec go (m : 'm) : 'm =
    if finished m then m
    else
      match line t with
      | None -> m
      | Some l ->
          let m, answer = step m l in
          List.iter (send_line t) answer;
          go m
  in
  go machine

let why (t : t) : string option = t.way.why ()

let close (t : t) : unit = t.way.stop ()
