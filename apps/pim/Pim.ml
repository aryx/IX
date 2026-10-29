(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-pim (docs/plans/plan_pim.md): with no command, its window
 * (Mail_window: the mail, plan_mail.md's stage 5); with one, from a
 * terminal ("the same store from a terminal, for real use and for the
 * tests"), its mail, of plan_mail.md's stages 2 to 4:
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
 * from the store's file password if the author made one (mode 600,
 * Mail_sync.saved_password), else from the first line of standard
 * input; never written by mini-pim.
 * -s host:port and -plain (no TLS): mini-maild on this machine.
 *
 * send: to whom the message's To:, Cc: and Bcc: say (Smtp.envelope),
 * from its From:; each message's outcome a line. list: a line a
 * conversation (Gmail's X-GM-THRID), the newest first: its newest
 * message's UID, "*" if any of it is unread, the date, who sent it, how
 * many messages, the subject. -q: Gmail's search syntax, done by Gmail
 * (X-GM-RAW). read: the headers to read and the text (Mime.text);
 * archive: Gmail's gesture, the \Inbox label taken off.
 *
 * What list and read fetch is kept in mini-pim's store (Items.mli): a
 * message's item, its headers and labels, written by each list; its
 * bytes in the cache once read. -offline: list and read from the store
 * alone, what the last list and the reads kept, no server. *)

type caps =
  < Cap.network
  ; Cap.open_in
  ; Cap.open_out
  ; Cap.readdir
  ; Cap.env
  ; Cap.stdin
  ; Cap.stdout
  ; Cap.stderr >

let usage =
  "usage: mini-pim [-s host:port] [-plain] [-u user] command\n\
  \  send file                         a message sent\n\
  \  list [-n 20] [-q search] [-m mailbox]\n\
  \                                    the newest conversations\n\
  \  read uid                          a message, marked read\n\
  \  archive uid...                    out of the Inbox\n\
  \  -s      the server (smtp.gmail.com:465 to send, imap.gmail.com:993 else)\n\
  \  -plain  no TLS (mini-maild, on this machine)\n\
  \  -offline  list and read what the store has, no server\n\
  \  -u      the account: log in as that user, the password the store's\n\
  \          file (~/.ix-pim/password, mode 600) or the first line of stdin\n\
  with no command, the window: mini-pim user=... [server=host:port] [plain]"

type options = {
  server : (string * int) option;
  plain : bool;
  user : string option;
  count : int;
  query : string option;
  mailbox : string;
  offline : bool;
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
  | "-offline" :: rest -> options { o with offline = true } rest
  | flag :: _ when String.length flag > 1 && flag.[0] = '-' -> None
  | a :: rest -> options { o with args = a :: o.args } rest

let fail (caps : < Cap.stderr ; .. >) (why : string) : Exit.t =
  Console.eprint caps (why ^ "\n");
  Exit.Err why

(* the store's password file (Mail_sync.saved_password), else the first
 * line of standard input *)
let password (caps : < Cap.env ; Cap.open_in ; Cap.stdin ; .. >) :
    (string, string) result =
  match Mail_sync.saved_password caps with
  | Error e -> Error e
  | Ok (Some p) -> Ok p
  | Ok None -> (
      match In_channel.input_line (Console.stdin caps) with
      | Some p -> Ok (String.trim p)
      | None -> Error "no password: ~/.ix-pim/password, or standard input")

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
    | None -> Ok None
    | Some u -> Result.map (fun p -> Some (u, p)) (password caps)
  in
  match (auth, connect caps o ("smtp.gmail.com", 465)) with
  | Error why, _ | _, Error why -> fail caps why
  | Ok auth, Ok conn -> (
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

(* the store, and the account (-u): the online commands' and the
 * offline ones'; then [online] in a session or [offline] *)
let reading (caps : < caps ; .. >) (o : options)
    ~(online : Items.t -> string -> Imap.t -> (unit, string) result)
    ~(offline : Items.t -> string -> (unit, string) result) : Exit.t =
  let store = Items.at (Items.place caps) in
  let server =
    match o.server with
    | Some (host, port) -> { Mail_sync.host; port; plain = o.plain }
    | None -> { Mail_sync.gmail with plain = o.plain }
  in
  match o.user with
  | None -> fail caps "-u: the user (the account)"
  | Some user -> (
      let r =
        if o.offline then offline store user
        else
          match password caps with
          | Error e -> Error e
          | Ok password ->
              Mail_sync.session caps server ~user ~password ~mailbox:o.mailbox
                (online store user)
      in
      match r with Ok () -> Exit.OK | Error e -> fail caps e)

(* a line a conversation *)
let show (caps : < Cap.stdout ; .. >) (l : Imap.summary list) : unit =
  List.iter
    (fun (c : Imap.summary list) ->
      let s = List.hd c in
      let many =
        if List.length c > 1 then Printf.sprintf " (%d)" (List.length c) else ""
      in
      Console.print caps
        (Printf.sprintf "%5d %s %-10s %-20s %s\n" s.uid
           (if Conversations.unread c then "*" else " ")
           (Conversations.day s.headers)
           (Conversations.who s.headers ^ many)
           (Conversations.header s.headers "subject")))
    (Conversations.group l)

let list (caps : < caps ; .. >) (o : options) : Exit.t =
  reading caps o
    ~online:(fun store account t ->
      match
        Mail_sync.list caps store t ~account ~mailbox:o.mailbox ~query:o.query
          o.count
      with
      | Error e -> Error e
      | Ok l -> show caps l; Ok ())
    ~offline:(fun store account ->
      if o.query <> None then Error "-q: a search is the server's"
      else
        let items = Items.all caps store in
        show caps
          (Mail_sync.newest o.count
             (Mail_item.listed items ~account ~mailbox:o.mailbox));
        Ok ())

let print (caps : < Cap.stdout ; .. >) (text : string) : unit =
  let m = Mail.parse text in
  List.iter
    (fun name ->
      let v = Conversations.header m name in
      if v <> "" then
        Console.print caps (String.capitalize_ascii name ^ ": " ^ v ^ "\n"))
    [ "from"; "to"; "cc"; "date"; "subject" ];
  Console.print caps ("\n" ^ Mime.text m)

(* read: from the cache when it is there, from the server and into the
 * cache else; marked read on the server and in its item *)
let read (caps : < caps ; .. >) (o : options) (uid : int) : Exit.t =
  let mailbox = o.mailbox in
  reading caps o
    ~online:(fun store account t ->
      match Mail_sync.message caps store t ~account ~mailbox uid with
      | Error e -> Error e
      | Ok text -> print caps text; Ok ())
    ~offline:(fun store account ->
      match Mail_sync.item_of caps store ~account ~mailbox uid with
      | None -> Error (Printf.sprintf "no message %d in %s here" uid mailbox)
      | Some item -> (
          match Items.cached caps store (Mail_item.key item) with
          | Some text -> print caps text; Ok ()
          | None -> Error (Printf.sprintf "message %d not read yet" uid)))

(* archive: Gmail's gesture, on the server and in the items *)
let archive (caps : < caps ; .. >) (o : options) (uids : int list) : Exit.t =
  reading caps o
    ~online:(fun store account t ->
      Mail_sync.archive caps store t ~account ~mailbox:o.mailbox uids)
    ~offline:(fun _ _ -> Error "archive: the server's, not -offline")

let main (caps : < caps ; .. >) (argv : string array) : Exit.t =
  let default =
    {
      server = None;
      plain = false;
      user = None;
      count = 20;
      query = None;
      mailbox = "INBOX";
      offline = false;
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

(* the window (Mail_window), its screen the window's; the platform's
 * words on the command line, and the window's flags *)
let window (caps : < caps ; Cap.argv ; .. >) : Exit.t =
  let flags = ("window", "") :: Playground_platform.flags caps in
  let wcaps = (caps :> Mail_window.caps) in
  Playground_platform.run_app caps flags
    (Playground.game Mail_window.view (Mail_window.update wcaps)
       (Mail_window.initial wcaps flags));
  Exit.OK

let commands = [ "send"; "list"; "read"; "archive" ]

let () =
  Cap.main (fun caps ->
      Exit.exit caps
        (Exit.catch (fun () ->
             let argv = CapSys.argv caps in
             (* a command: the command line; else the window *)
             if List.exists (fun a -> List.mem a commands) (Array.to_list argv)
             then main caps argv
             else window caps)))
