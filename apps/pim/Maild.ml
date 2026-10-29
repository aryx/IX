(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-maild: mail taken by SMTP, kept a file a message, and read by
 * IMAP, on this machine only (127.0.0.1): the other end of mini-pim's
 * mail for its tests, so that they never talk to Gmail
 * (docs/plans/plan_mail.md). After the author's playground's
 * tiny_maild, whose Mail_server it runs the SMTP half of (Smtp_server),
 * with IMAP for its POP3 (Imap_server).
 *
 *     mini-pim send ---SMTP---> mini-maild ----> spool/bob/1
 *                                          ----> spool/bob/2
 *     mini-pim list <--IMAP---- (flags and labels in the process)
 *
 * One client at a time, as mini-httpd, on either port; any user and
 * password (a test's server); mail for its domain only (-d, "ix"). A
 * message is a file, numbered in its user's directory as it comes, the
 * number its UID, the bytes Smtp_server made of it, its Received: line
 * on top. Its flags and labels (\Inbox when it comes) are kept while
 * mini-maild runs, not written. Each message taken is a line on
 * standard output: the user, its number, its subject. *)

type caps = < Cap.network; Cap.open_in; Cap.open_out; Cap.readdir;
              Cap.stdout; Cap.stderr >

let usage = "usage: mini-maild [-p port] [-i port] [-d domain] [-a name] spool
  -p  SMTP's port (2525; 0: one the system chooses, said on the first line)
  -i  IMAP's port (1143; 0 as for -p)
  -d  the domain taken mail for (ix)
  -a  All Mail's name ([Gmail]/All Mail; a French Gmail's:
      '[Gmail]/Tous les messages')"

let say (caps : < Cap.stdout; .. >) (line : string) : unit =
  Console.print caps (line ^ "\n");
  flush (Console.stdout caps)

(* the numbers of a user's messages, in order *)
let numbers (_caps : < Cap.readdir; .. >) (dir : string) : int list =
  if not (Sys.file_exists dir) then []
  else
    List.sort compare
      (List.filter_map int_of_string_opt (Array.to_list (Sys.readdir dir)))

(* the message into each user's directory, the next number *)
let keep (caps : < caps; .. >) ~(spool : string) (d : Smtp_server.delivery) :
    unit =
  List.iter
    (fun user ->
      let dir = Filename.concat spool user in
      if not (Sys.file_exists dir) then FS.mkdir caps dir 0o755;
      let n = List.fold_left max 0 (numbers caps dir) + 1 in
      FS.write caps (Fpath.v (Filename.concat dir (string_of_int n)))
        (Mail.to_string d.mail);
      let subject =
        match Mail.get d.mail "subject" with Some s -> s | None -> ""
      in
      say caps (Printf.sprintf "%s %d %s" user n subject))
    d.users

(* IMAP's store: the files, and the flags and labels of each
 * (user, UID) changed since mini-maild started *)
let store (caps : < caps; .. >) ~(spool : string) ~(all_mail : string) :
    Imap_server.store =
  let marks : (string * int, string list * string list) Hashtbl.t =
    Hashtbl.create 16
  in
  let messages user =
    let dir = Filename.concat spool user in
    List.map
      (fun uid ->
        let flags, labels =
          match Hashtbl.find_opt marks (user, uid) with
          | Some m -> m
          | None -> ([], [ "\\Inbox" ])
        in
        { Imap_server.uid;
          text = FS.read caps (Fpath.v (Filename.concat dir (string_of_int uid)));
          flags; labels })
      (numbers caps dir)
  in
  { all_mail;
    messages;
    change = (fun user uid ~flags ~labels ->
      Hashtbl.replace marks (user, uid) (flags, labels)) }

(* a client's dialogue, its machine's greeting first, until it is done
 * or gone *)
let dialogue (conn : Lines.t) (greeting : string list)
    (step : 'm -> string -> 'm * string list) (machine : 'm)
    (ended : 'm -> bool) : unit =
  List.iter (Lines.send_line conn) greeting;
  let rec go m =
    if not (ended m) then
      match Lines.line conn with
      | None -> ()
      | Some l ->
          let m, answer = step m l in
          List.iter (Lines.send_line conn) answer;
          go m
  in
  go machine

let smtp (caps : < caps; .. >) ~(spool : string) ~(domain : string)
    (conn : Lines.t) : unit =
  let s, greeting = Smtp_server.start ~domain in
  let step s l =
    let s, answer, delivered =
      Smtp_server.step s ~now:(Unix.gettimeofday ()) l
    in
    (match delivered with Some d -> keep caps ~spool d | None -> ());
    (s, answer)
  in
  dialogue conn greeting step s Smtp_server.ended

let imap (store : Imap_server.store) (conn : Lines.t) : unit =
  let t, greeting = Imap_server.start () in
  dialogue conn greeting (Imap_server.step store) t Imap_server.ended

let listen (_caps : < Cap.network; .. >) (port : int) : Unix.file_descr * int =
  let sock = Unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
  Unix.setsockopt sock Unix.SO_REUSEADDR true;
  Unix.bind sock (Unix.ADDR_INET (Unix.inet_addr_loopback, port));
  Unix.listen sock 16;
  (sock, match Unix.getsockname sock with Unix.ADDR_INET (_, p) -> p | _ -> port)

(* the next client, on either socket, served to its end *)
let rec serve (sockets : (Unix.file_descr * (Lines.t -> unit)) list) : 'a =
  let ready, _, _ = Unix.select (List.map fst sockets) [] [] (-1.) in
  List.iter
    (fun sock ->
      let fd, _ = Unix.accept sock in
      let conn = Lines.of_fd fd in
      (try (List.assoc sock sockets) conn
       with Unix.Unix_error _ | Sys_error _ -> ());
      Lines.close conn)
    ready;
  serve sockets

type options = {
  port : int;
  imap_port : int;
  domain : string;
  all_mail : string;
  spool : string;
}

let rec options (o : options) (args : string list) : options option =
  let port p f = match int_of_string_opt p with Some p -> f p | None -> None in
  match args with
  | [] -> if o.spool = "" then None else Some o
  | "-p" :: p :: rest -> port p (fun p -> options { o with port = p } rest)
  | "-i" :: p :: rest -> port p (fun p -> options { o with imap_port = p } rest)
  | "-d" :: d :: rest -> options { o with domain = d } rest
  | "-a" :: a :: rest -> options { o with all_mail = a } rest
  | flag :: _ when String.length flag > 1 && flag.[0] = '-' -> None
  | dir :: rest -> options { o with spool = dir } rest

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  let default =
    { port = 2525; imap_port = 1143; domain = "ix";
      all_mail = "[Gmail]/All Mail"; spool = "" }
  in
  match options default (List.tl (Array.to_list argv)) with
  | None -> Console.eprint caps (usage ^ "\n"); Exit.Err "usage"
  | Some o when not (Sys.file_exists o.spool && Sys.is_directory o.spool) ->
      Console.eprint caps (o.spool ^ ": not a directory\n");
      Exit.Err "spool"
  | Some o -> (
      match (listen caps o.port, listen caps o.imap_port) with
      | exception Unix.Unix_error (e, _, _) ->
          Console.eprint caps (Unix.error_message e ^ "\n");
          Exit.Err "port"
      | (s, p), (i, q) ->
          Sys.set_signal Sys.sigpipe Sys.Signal_ignore;
          say caps
            (Printf.sprintf
               "serving %s: SMTP on 127.0.0.1:%d, IMAP on 127.0.0.1:%d"
               o.domain p q);
          let spool = o.spool in
          serve
            [ (s, smtp caps ~spool ~domain:o.domain);
              (i, imap (store caps ~spool ~all_mail:o.all_mail)) ])

let () =
  Cap.main (fun caps ->
      Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
