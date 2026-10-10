(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: after the author's playground's libs/networking/unix/Tcp.ml; no optional timeout, a read's by select (lib_core's Unix has no SO_RCVTIMEO), a name asked of Dns when getaddrinfo knows none (docs/plans/plan_browser.md) *)

(* See Tcp.mli *)

let timeout = 30.

let connect (caps : < Cap.network; Cap.open_in; .. >) ~(host : string) ~(port : int) : Unix.file_descr =
  let addresses =
    match Unix.getaddrinfo host (string_of_int port) [ Unix.AI_SOCKTYPE Unix.SOCK_STREAM ] with
    | [] -> List.map (fun a -> (Unix.PF_INET, Unix.ADDR_INET (a, port))) (Dns.resolve caps host)
    | l -> List.map (fun (a : Unix.addr_info) -> (a.ai_family, a.ai_addr)) l
  in
  if addresses = [] then failwith (Printf.sprintf "Tcp.connect: can't resolve %S" host);
  (* each address in turn, the last one's error raised *)
  let rec try_ = function
    | [] -> assert false
    | (family, addr) :: others -> (
        let fd = Unix.socket family Unix.SOCK_STREAM 0 in
        try
          Unix.connect fd addr;
          fd
        with Unix.Unix_error _ as e ->
          Unix.close fd;
          if others = [] then raise e else try_ others)
  in
  try_ addresses

let send_all (fd : Unix.file_descr) (s : string) : unit =
  let rec go pos = if pos < String.length s then go (pos + Unix.write_substring fd s pos (String.length s - pos)) in
  go 0

let receive_all (fd : Unix.file_descr) : string =
  let b = Buffer.create 65536 in
  let chunk = Bytes.create 65536 in
  let rec go () =
    (match Unix.select [ fd ] [] [] timeout with [], _, _ -> failwith (Printf.sprintf "no answer in %.0f s" timeout) | _ -> ());
    match Unix.read fd chunk 0 (Bytes.length chunk) with
    | 0 -> Buffer.contents b
    | n ->
        Buffer.add_subbytes b chunk 0 n;
        go ()
  in
  go ()

let exchange (caps : < Cap.network; Cap.open_in; .. >) ~(host : string) ~(port : int) (s : string) : string =
  let fd = connect caps ~host ~port in
  Fun.protect
    ~finally:(fun () -> Unix.close fd)
    (fun () ->
      send_all fd s;
      receive_all fd)
