(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-maild: mail taken by SMTP and kept, a file a message, on this
 * machine only (127.0.0.1): the other end of mini-pim's mail for its
 * tests, so that they never talk to Gmail (docs/plans/plan_mail.md).
 * After the author's playground's tiny_maild, whose Mail_server it
 * runs the SMTP half of (Smtp_server); its IMAP side comes next.
 *
 *     mini-pim send ---SMTP---> mini-maild ----> spool/bob/1
 *                                          ----> spool/bob/2
 *
 * One client at a time, as mini-httpd; any user and password (a test's
 * server); mail for its domain only (-d, "ix"). A message is a file,
 * numbered in its user's directory as it comes (the number IMAP's UID
 * to be), the bytes Smtp_server made of it, its Received: line on top.
 * Each message taken is a line on standard output: the user, its
 * number, its subject. *)

type caps = < Cap.network; Cap.open_in; Cap.open_out; Cap.readdir;
              Cap.stdout; Cap.stderr >

let usage = "usage: mini-maild [-p port] [-d domain] spool
  -p  the port (2525; 0: one the system chooses, said on the first line)
  -d  the domain taken mail for (ix)"

let say (caps : < Cap.stdout; .. >) (line : string) : unit =
  Console.print caps (line ^ "\n");
  flush (Console.stdout caps)

(* the message into each user's directory, the next number *)
let keep (caps : < caps; .. >) ~(spool : string) (d : Smtp_server.delivery) :
    unit =
  List.iter
    (fun user ->
      let dir = Filename.concat spool user in
      if not (Sys.file_exists dir) then FS.mkdir caps dir 0o755;
      let n = Array.length (Sys.readdir dir) + 1 in
      FS.write caps (Fpath.v (Filename.concat dir (string_of_int n)))
        (Mail.to_string d.mail);
      let subject = match Mail.get d.mail "subject" with Some s -> s | None -> "" in
      say caps (Printf.sprintf "%s %d %s" user n subject))
    d.users

(* one client's session, until QUIT or it is gone *)
let session (caps : < caps; .. >) ~(spool : string) ~(domain : string)
    (conn : Lines.t) : unit =
  let s, greeting = Smtp_server.start ~domain in
  List.iter (Lines.send_line conn) greeting;
  let rec go s =
    if not (Smtp_server.ended s) then
      match Lines.line conn with
      | None -> ()
      | Some l ->
          let s, answer, delivered =
            Smtp_server.step s ~now:(Unix.gettimeofday ()) l
          in
          (match delivered with Some d -> keep caps ~spool d | None -> ());
          List.iter (Lines.send_line conn) answer;
          go s
  in
  go s

let listen (_caps : < Cap.network; .. >) (port : int) : Unix.file_descr * int =
  let sock = Unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
  Unix.setsockopt sock Unix.SO_REUSEADDR true;
  Unix.bind sock (Unix.ADDR_INET (Unix.inet_addr_loopback, port));
  Unix.listen sock 16;
  (sock, match Unix.getsockname sock with Unix.ADDR_INET (_, p) -> p | _ -> port)

let rec serve (caps : < caps; .. >) ~(spool : string) ~(domain : string)
    (sock : Unix.file_descr) : 'a =
  let fd, _ = Unix.accept sock in
  let conn = Lines.of_fd fd in
  (try session caps ~spool ~domain conn
   with Unix.Unix_error _ | Sys_error _ -> ());
  Lines.close conn;
  serve caps ~spool ~domain sock

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  let rec options port domain spool args =
    match args with
    | [] -> ( match spool with Some s -> Some (port, domain, s) | None -> None)
    | "-p" :: p :: rest -> (
        match int_of_string_opt p with
        | Some p -> options p domain spool rest
        | None -> None)
    | "-d" :: d :: rest -> options port d spool rest
    | flag :: _ when String.length flag > 1 && flag.[0] = '-' -> None
    | dir :: rest -> options port domain (Some dir) rest
  in
  match options 2525 "ix" None (List.tl (Array.to_list argv)) with
  | None -> Console.eprint caps (usage ^ "\n"); Exit.Err "usage"
  | Some (_, _, spool) when not (Sys.file_exists spool && Sys.is_directory spool) ->
      Console.eprint caps (spool ^ ": not a directory\n");
      Exit.Err "spool"
  | Some (port, domain, spool) -> (
      match listen caps port with
      | exception Unix.Unix_error (e, _, _) ->
          Console.eprint caps
            (Printf.sprintf "port %d: %s\n" port (Unix.error_message e));
          Exit.Err "port"
      | sock, port ->
          Sys.set_signal Sys.sigpipe Sys.Signal_ignore;
          say caps
            (Printf.sprintf "serving SMTP for %s on 127.0.0.1:%d" domain port);
          serve caps ~spool ~domain sock)

let () =
  Cap.main (fun caps ->
      Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
