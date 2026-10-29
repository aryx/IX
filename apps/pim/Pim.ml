(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-pim from a terminal (docs/plans/plan_pim.md: "the same store
 * from a terminal, for real use and for the tests"). Its mail, of
 * plan_mail.md's stages 2 and 3:
 *
 *     mini-pim send file               the message sent by SMTP
 *     mini-pim list [-n 20] [-q search] [-m mailbox]
 *                                      the newest conversations
 *     mini-pim read uid                a message, marked read
 *     mini-pim archive uid...          out of the Inbox, kept
 *
 * By default to Gmail (smtp.gmail.com:465 to send, imap.gmail.com:993
 * to read, TLS from the first byte), as -u, the whole address, with an
 * app password (plan_mail.md: Google's one exception to OAuth), read
 * from the first line of standard input and never written anywhere.
 * -s host:port and -plain (no TLS): mini-maild on this machine.
 *
 * send: to whom the message's To:, Cc: and Bcc: say (Smtp.envelope),
 * from its From:; each message's outcome a line. list: a line a
 * conversation (Gmail's X-GM-THRID), the newest first: its newest
 * message's UID, "*" if any of it is unread, the date, who sent it, how
 * many messages, the subject. -q: Gmail's search syntax, done by Gmail
 * (X-GM-RAW). read: the headers to read and the text (Mime.text);
 * archive: Gmail's gesture, the \Inbox label taken off. *)

type caps = < Cap.network ; Cap.open_in ; Cap.stdin ; Cap.stdout ; Cap.stderr >

let usage =
  "usage: mini-pim [-s host:port] [-plain] [-u user] command\n\
  \  send file                         a message sent\n\
  \  list [-n 20] [-q search] [-m mailbox]\n\
  \                                    the newest conversations\n\
  \  read uid                          a message, marked read\n\
  \  archive uid...                    out of the Inbox\n\
  \  -s      the server (smtp.gmail.com:465 to send, imap.gmail.com:993 else)\n\
  \  -plain  no TLS (mini-maild, on this machine)\n\
  \  -u      log in as that user, the password the first line of stdin"

type options = {
  server : (string * int) option;
  plain : bool;
  user : string option;
  count : int;
  query : string option;
  mailbox : string;
  args : string list; (* the command and its arguments *)
}

let rec options (o : options) (args : string list) : options option =
  match args with
  | [] -> if o.args = [] then None else Some { o with args = List.rev o.args }
  | "-s" :: hp :: rest -> (
      match String.rindex_opt hp ':' with
      | Some i -> (
          let port = String.sub hp (i + 1) (String.length hp - i - 1) in
          match int_of_string_opt port with
          | Some port ->
              options { o with server = Some (String.sub hp 0 i, port) } rest
          | None -> None)
      | None -> None)
  | "-plain" :: rest -> options { o with plain = true } rest
  | "-u" :: u :: rest -> options { o with user = Some u } rest
  | "-n" :: n :: rest -> (
      match int_of_string_opt n with
      | Some n -> options { o with count = n } rest
      | None -> None)
  | "-q" :: q :: rest -> options { o with query = Some q } rest
  | "-m" :: m :: rest -> options { o with mailbox = m } rest
  | flag :: _ when String.length flag > 1 && flag.[0] = '-' -> None
  | a :: rest -> options { o with args = a :: o.args } rest

let fail (caps : < Cap.stderr ; .. >) (why : string) : Exit.t =
  Console.eprint caps (why ^ "\n");
  Exit.Err why

let password (caps : < Cap.stdin ; .. >) : string option =
  match In_channel.input_line (Console.stdin caps) with
  | Some p -> Some (String.trim p)
  | None -> None

let connect (caps : < caps ; .. >) (o : options) (default : string * int) :
    (Lines.t, string) result =
  let host, port = match o.server with Some s -> s | None -> default in
  let conn =
    if o.plain then Lines.plain caps ~host ~port
    else Lines.tls caps ~trust:(Tls_client.system_roots caps) ~host ~port
  in
  match conn with
  | Ok c -> Ok c
  | Error why -> Error (Printf.sprintf "%s:%d: %s" host port why)

(*****************************************************************************)
(* Sending *)
(*****************************************************************************)

let send (caps : < caps ; .. >) (o : options) (file : string) : Exit.t =
  let mail = Mail.parse (FS.read caps (Fpath.v file)) in
  let sender =
    match Option.bind (Mail.get mail "from") Mail.address with
    | Some a -> a.mailbox
    | None -> ( match o.user with Some u -> u | None -> "")
  in
  let auth =
    match o.user with
    | None -> None
    | Some u -> Option.map (fun p -> (u, p)) (password caps)
  in
  match connect caps o ("smtp.gmail.com", 465) with
  | Error why -> fail caps why
  | Ok conn -> (
      let c =
        Smtp.client ~hello:"mini-pim" ~auth [ Smtp.envelope ~sender mail ]
      in
      let c = Lines.talk conn Smtp.step c (fun c -> Smtp.finished c <> None) in
      let why = Lines.why conn in
      Lines.close conn;
      match Smtp.finished c with
      | Some (Ok outcomes) ->
          List.iter
            (fun o ->
              Console.print caps
                (match (o : Smtp.outcome) with
                | Sent (n, []) -> Printf.sprintf "sent to %d\n" n
                | Sent (n, refused) ->
                    Printf.sprintf "sent to %d, refused: %s\n" n
                      (String.concat "; " refused)
                | Refused why -> "refused: " ^ why ^ "\n"))
            outcomes;
          if List.for_all (function Smtp.Sent _ -> true | _ -> false) outcomes
          then Exit.OK
          else Exit.Err "refused"
      | Some (Error said) -> fail caps ("the server: " ^ said)
      | None ->
          fail caps
            (match why with Some w -> w | None -> "the connection ended"))

(*****************************************************************************)
(* Reading *)
(*****************************************************************************)

(* [f] with the mailbox selected, logged in; logged out after *)
let with_imap (caps : < caps ; .. >) (o : options)
    (f : Imap.t -> (unit, string) result) : Exit.t =
  match (o.user, connect caps o ("imap.gmail.com", 993)) with
  | None, _ -> fail caps "-u: the user to log in as"
  | _, Error why -> fail caps why
  | Some user, Ok conn -> (
      let ( let* ) r f = match r with Ok x -> f x | Error e -> Error e in
      let session =
        let* t = Imap.connect conn in
        let* () =
          match password caps with
          | Some password -> Imap.login t ~user ~password
          | None -> Error "no password on standard input"
        in
        let* _ = Imap.select t o.mailbox in
        let r = f t in
        Imap.logout t;
        r
      in
      match session with
      | Ok () -> Exit.OK
      | Error e ->
          Lines.close conn;
          fail caps e)

(* "2026-10-29", or "" *)
let day (m : Mail.t) : string =
  match Option.bind (Mail.get m "date") Mail.date with
  | Some d -> Printf.sprintf "%04d-%02d-%02d" d.day.year d.day.month d.day.day
  | None -> ""

let header (m : Mail.t) (name : string) : string =
  match Mail.get m name with Some v -> Mime.decode_words v | None -> ""

let who (m : Mail.t) : string =
  match Mail.address (header m "from") with
  | Some a -> Mail.who a
  | None -> header m "from"

(* the summaries as conversations: each with its messages, the newest
 * conversation first *)
let conversations (l : Imap.summary list) : Imap.summary list list =
  let key (s : Imap.summary) =
    if s.thread = "" then string_of_int s.uid else s.thread
  in
  let rec group (acc : (string * Imap.summary list) list) l =
    match l with
    | [] -> acc
    | s :: rest ->
        let k = key s in
        let acc =
          match List.assoc_opt k acc with
          | Some ms -> (k, s :: ms) :: List.remove_assoc k acc
          | None -> (k, [ s ]) :: acc
        in
        group acc rest
  in
  (* (oldest first in: the newest message's conversation ends on top) *)
  List.map snd (group [] l)

let list (caps : < caps ; .. >) (o : options) : Exit.t =
  with_imap caps o (fun t ->
      let query =
        match o.query with
        | Some q -> "X-GM-RAW " ^ Imap.quote q
        | None -> "ALL"
      in
      match Imap.search t query with
      | Error e -> Error e
      | Ok uids -> (
          let n = List.length uids in
          let newest = List.filteri (fun i _ -> i >= n - o.count) uids in
          match Imap.summaries t newest with
          | Error e -> Error e
          | Ok l ->
              List.iter
                (fun (c : Imap.summary list) ->
                  let s = List.hd c in
                  let unread =
                    List.exists
                      (fun (s : Imap.summary) ->
                        not (List.mem "\\Seen" s.flags))
                      c
                  in
                  let many =
                    if List.length c > 1 then
                      Printf.sprintf " (%d)" (List.length c)
                    else ""
                  in
                  Console.print caps
                    (Printf.sprintf "%5d %s %-10s %-20s %s\n" s.uid
                       (if unread then "*" else " ")
                       (day s.headers)
                       (who s.headers ^ many)
                       (header s.headers "subject")))
                (conversations l);
              Ok ()))

let read (caps : < caps ; .. >) (o : options) (uid : int) : Exit.t =
  with_imap caps o (fun t ->
      match Imap.message t uid with
      | Error e -> Error e
      | Ok text ->
          let m = Mail.parse text in
          List.iter
            (fun name ->
              let v = header m name in
              if v <> "" then
                Console.print caps
                  (String.capitalize_ascii name ^ ": " ^ v ^ "\n"))
            [ "from"; "to"; "cc"; "date"; "subject" ];
          Console.print caps ("\n" ^ Mime.text m);
          Ok ())

let archive (caps : < caps ; .. >) (o : options) (uids : int list) : Exit.t =
  with_imap caps o (fun t -> Imap.store t uids "-X-GM-LABELS (\\Inbox)")

let main (caps : < caps ; .. >) (argv : string array) : Exit.t =
  let default =
    {
      server = None;
      plain = false;
      user = None;
      count = 20;
      query = None;
      mailbox = "INBOX";
      args = [];
    }
  in
  let uids l = List.filter_map int_of_string_opt l in
  match options default (List.tl (Array.to_list argv)) with
  | Some ({ args = [ "send"; file ]; _ } as o) -> send caps o file
  | Some ({ args = [ "list" ]; _ } as o) -> list caps o
  | Some ({ args = [ "read"; uid ]; _ } as o) when uids [ uid ] <> [] ->
      read caps o (int_of_string uid)
  | Some ({ args = "archive" :: (_ :: _ as l); _ } as o)
    when List.length (uids l) = List.length l ->
      archive caps o (uids l)
  | _ ->
      Console.eprint caps (usage ^ "\n");
      Exit.Err "usage"

let () =
  Cap.main (fun caps ->
      Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
