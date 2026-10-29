(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-pim (docs/plans/plan_pim.md): with no command, its window
 * (Mail_window: the mail, plan_mail.md's stage 5); with one, from a
 * terminal ("the same store from a terminal, for real use and for the
 * tests"), its mail, of plan_mail.md's stages 2 to 4 and 7:
 *
 *     mini-pim send file               the message sent by SMTP
 *     mini-pim list [-n 20] [-q search] [-m mailbox]
 *                                      the newest conversations
 *     mini-pim read uid                a message, marked read
 *     mini-pim reply [-all] uid        the reply to edit, then send
 *     mini-pim forward uid             the forward to edit, then send
 *     mini-pim archive uid...          out of the Inbox, kept
 *     mini-pim snooze uid words        out of it until a day, back then
 *     mini-pim contact uid             its sender made a contact
 *     mini-pim people                  the address book
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
 * from its From:; each message's outcome a line. reply and forward
 * print a draft (Mail_compose: Re:, the thread's ids, the text quoted;
 * Fwd:), mutt's way: kept in a file, edited, then sent by send, which
 * sends a file with Attach: (files) or Forward: (the attachments of
 * the message forwarded, from the cache) as a draft, -u its From:. list: a line a
 * conversation (Gmail's X-GM-THRID), the newest first: its newest
 * message's UID, "*" if any of it is unread, the date, who sent it, how
 * many messages, the subject. -q: Gmail's search syntax, done by Gmail
 * (X-GM-RAW). read: the headers to read and the text (Mail_text);
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
  \  reply [-all] uid, forward uid     a draft to edit, then send\n\
  \  archive uid...                    out of the Inbox\n\
  \  snooze uid words                  out of it until a day: monday, in 3 days\n\
  \  search query                      the store's items: from:alice is:task\n\
  \                                    label:travel before:2026-12-01 -word\n\
  \  show id                           an item, its links both ways\n\
  \  contact uid, people               the sender a contact; the address book\n\
  \  add id [name=value...]            an item (task:pay-rent due=2026-11-05)\n\
  \  set id name=value...              its fields (name= takes one away)\n\
  \  -s      the server (smtp.gmail.com:465 to send, imap.gmail.com:993 else)\n\
  \  -plain  no TLS (mini-maild, on this machine)\n\
  \  -offline  list and read what the store has, no server\n\
  \  -u      the account: log in as that user, the password the store's\n\
  \          file (~/.ix-pim/password, mode 600) or the first line of stdin\n\
  with no command, the window: mini-pim user=... [server=host:port]\n\
  \                             [smtp=host:port] [plain]"

type options = {
  server : (string * int) option;
  plain : bool;
  user : string option;
  count : int;
  query : string option;
  mailbox : string;
  offline : bool;
  all : bool; (* reply to all *)
  today : Civil.date; (* -today, for the tests: else the clock's *)
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
  | "-all" :: rest -> options { o with all = true } rest
  | "-today" :: d :: rest -> (
      match Search.date d with
      | Some today -> options { o with today } rest
      | None -> None)
  (* (a search's words as they are: -is:message is a word, no flag) *)
  | "search" :: (_ :: _ as words) when o.args = [] ->
      Some { o with args = "search" :: words }
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

(*****************************************************************************)
(* Sending *)
(*****************************************************************************)

let server (o : options) (default : Mail_sync.server) : Mail_sync.server =
  match o.server with
  | Some (host, port) -> { Mail_sync.host; port; plain = o.plain }
  | None -> { default with plain = o.plain }

(* a message as written; or a draft (reply, forward: what has attach:
 * or forward:), made the message then *)
let send (caps : < caps ; .. >) (o : options) (file : string) : Exit.t =
  let mail = Mail.parse (FS.read caps (Fpath.v file)) in
  let s = server o Mail_sync.gmail_smtp in
  let draft = Mail.get mail "attach" <> None || Mail.get mail "forward" <> None in
  let auth =
    match o.user with
    | None -> Ok None
    | Some u -> Result.map (fun p -> Some (u, p)) (password caps)
  in
  match (auth, o.user) with
  | Error why, _ -> fail caps why
  | Ok (Some (user, password)), Some _ when draft -> (
      let store = Items.at (Items.place caps) in
      match
        Mail_sync.send_draft caps store s ~user ~password
          (Mail_compose.of_item mail)
      with
      | Ok said -> Console.print caps (said ^ "\n"); Exit.OK
      | Error why -> fail caps why)
  | Ok _, _ when draft -> fail caps "-u: a draft is sent as the user"
  | Ok auth, _ -> (
      (* (a reply's file has no From: yet: the user's) *)
      let mail =
        match (Mail.get mail "from", o.user) with
        | None, Some u -> Mail.set "From" u mail
        | _ -> mail
      in
      match Mail_sync.send caps s ~auth (Mail_compose.complete mail) with
      | Error why -> fail caps why
      | Ok outcomes ->
          List.iter
            (fun o -> Console.print caps (Mail_sync.said o ^ "\n"))
            outcomes;
          if List.for_all (function Smtp.Sent _ -> true | _ -> false) outcomes
          then Exit.OK
          else Exit.Err "refused")

(*****************************************************************************)
(* Reading *)
(*****************************************************************************)

(* the store, and the account (-u): the online commands' and the
 * offline ones'; then [online] in a session or [offline] *)
let reading (caps : < caps ; .. >) (o : options) ~(wake : bool)
    ~(online : Items.t -> string -> Imap.t -> (unit, string) result)
    ~(offline : Items.t -> string -> (unit, string) result) : Exit.t =
  let store = Items.at (Items.place caps) in
  let server = server o Mail_sync.gmail in
  match o.user with
  | None -> fail caps "-u: the user (the account)"
  | Some user -> (
      let r =
        if o.offline then offline store user
        else
          match password caps with
          | Error e -> Error e
          | Ok password -> (
              (* (the snoozed whose day has come back first: Mail_sync) *)
              let woken =
                if wake then
                  Mail_sync.wake caps store server ~user ~password
                    ~today:o.today
                else Ok 0
              in
              match woken with
              | Error e -> Error e
              | Ok _ ->
                  Mail_sync.session caps server ~user ~password
                    ~mailbox:o.mailbox (online store user))
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
  reading caps o ~wake:(o.mailbox = "INBOX")
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
  let t = Mail_text.text m in
  Console.print caps
    ("\n" ^ t ^ if String.ends_with ~suffix:"\n" t then "" else "\n")

(* [f] of a message's text and its key in the cache: from the cache
 * when it is there, from the server and into the cache else; marked
 * read on the server and in its item *)
let fetch (caps : < caps ; .. >) (o : options) (uid : int)
    (f : string -> Items.t -> string -> string -> unit) : Exit.t =
  let mailbox = o.mailbox in
  let key store account =
    match Mail_sync.item_of caps store ~account ~mailbox uid with
    | Some item -> Mail_item.key item
    | None -> ""
  in
  reading caps o ~wake:false
    ~online:(fun store account t ->
      match Mail_sync.message caps store t ~account ~mailbox uid with
      | Error e -> Error e
      | Ok text -> f text store account (key store account); Ok ())
    ~offline:(fun store account ->
      match Mail_sync.item_of caps store ~account ~mailbox uid with
      | None -> Error (Printf.sprintf "no message %d in %s here" uid mailbox)
      | Some item -> (
          let key = Mail_item.key item in
          match Items.cached caps store key with
          | Some text -> f text store account key; Ok ()
          | None -> Error (Printf.sprintf "message %d not read yet" uid)))

let read (caps : < caps ; .. >) (o : options) (uid : int) : Exit.t =
  fetch caps o uid (fun text _ _ _ -> print caps text)

(* reply, forward: the draft as a file's text, to edit and send *)
let draft (caps : < caps ; .. >) (o : options) (uid : int) ~(forward : bool) :
    Exit.t =
  fetch caps o uid (fun text _ account key ->
      let m = Mail.parse text in
      let d =
        if forward then Mail_compose.forward ~id:"" ~key m (Mail_text.text m)
        else Mail_compose.reply ~id:"" ~all:o.all ~me:account m (Mail_text.text m)
      in
      let item = Mail_compose.to_item d in
      (* (the item's id: and stamp: are the store's, not the file's) *)
      let fields =
        List.filter
          (fun (f : Mail.field) -> f.name <> "id" && f.name <> "stamp")
          item.fields
      in
      let fields =
        List.map
          (fun (f : Mail.field) ->
            (* in-reply-to is In-Reply-To *)
            let words = String.split_on_char '-' f.name in
            { f with
              name = String.concat "-" (List.map String.capitalize_ascii words) })
          fields
      in
      Console.print caps (Mail.to_string { item with fields }))

(* archive: Gmail's gesture, on the server and in the items *)
let archive (caps : < caps ; .. >) (o : options) (uids : int list) : Exit.t =
  reading caps o ~wake:false
    ~online:(fun store account t ->
      Mail_sync.archive caps store t ~account ~mailbox:o.mailbox uids)
    ~offline:(fun _ _ -> Error "archive: the server's, not -offline")

(*****************************************************************************)
(* The store *)
(*****************************************************************************)

(* what an item is called in a list: its subject, title or name, else
 * its text's first line *)
let title (item : Item.t) : string =
  let first =
    List.find_opt (fun v -> v <> "")
      (List.map (Item.field item) [ "subject"; "title"; "name" ])
  in
  match first with
  | Some v -> Mime.decode_words v
  | None -> (
      match String.split_on_char '\n' (String.trim item.body) with
      | l :: _ -> l
      | [] -> "")

let line (caps : < Cap.stdout ; .. >) (prefix : string) (item : Item.t) :
    unit =
  Console.print caps
    (Printf.sprintf "%s%-24s %-16s %s\n" prefix (Item.id item)
       (String.concat " " (Item.stamps item))
       (title item))

let search (caps : < caps ; .. >) (query : string) : Exit.t =
  let items = Items.all caps (Items.at (Items.place caps)) in
  List.iter (line caps "") (Search.search query items);
  Exit.OK

(* show: the item's file, and its links both ways *)
let show (caps : < caps ; .. >) (id : string) : Exit.t =
  let store = Items.at (Items.place caps) in
  match Items.find caps store id with
  | None -> fail caps (id ^ ": no such item")
  | Some item ->
      let items = Items.all caps store in
      Console.print caps (String.trim (Item.to_string item) ^ "\n");
      let say heading l =
        if l <> [] then begin
          Console.print caps ("\n" ^ heading ^ "\n");
          List.iter
            (fun (field, i) ->
              line caps (if field = "" then "  " else "  " ^ field ^ ": ") i)
            l
        end
      in
      (* (a person's page: the mail with them first, People) *)
      if Item.has_stamp item "contact" then
        say "mail:" (List.map (fun m -> ("", m)) (People.with_ items item));
      say "links:" (Links.links items item);
      say "linked from:" (Links.backlinks items item);
      Exit.OK

(* contact: the sender of a message listed made a contact, BBDB's
 * way; people: the address book *)
let contact (caps : < caps ; .. >) (o : options) (uid : int) : Exit.t =
  let store = Items.at (Items.place caps) in
  match o.user with
  | None -> fail caps "-u: the user (the account)"
  | Some account -> (
      match
        Option.bind
          (Mail_sync.item_of caps store ~account ~mailbox:o.mailbox uid)
          People.of_sender
      with
      | None -> fail caps (Printf.sprintf "no sender of %d here" uid)
      | Some c -> (
          match Items.find caps store (Item.id c) with
          | Some _ -> fail caps (Item.id c ^ ": already a contact")
          | None ->
              Items.save caps store c;
              Console.print caps (Item.id c ^ "\n");
              Exit.OK))

let people (caps : < caps ; .. >) : Exit.t =
  let items = Items.all caps (Items.at (Items.place caps)) in
  List.iter (line caps "") (People.contacts items);
  Exit.OK

(* "due=2026-11-05": a field's name and value *)
let assignments (l : string list) : (string * string) list option =
  let one a =
    match String.index_opt a '=' with
    | Some i when i > 0 ->
        Some (String.sub a 0 i, String.sub a (i + 1) (String.length a - i - 1))
    | _ -> None
  in
  let l' = List.filter_map one l in
  if List.length l' = List.length l then Some l' else None

(* due= and until= as words: "friday" is 2026-10-30 (When) *)
let days (today : Civil.date) (fields : (string * string) list) :
    ((string * string) list, string) result =
  List.fold_right
    (fun (name, v) acc ->
      match acc with
      | Error e -> Error e
      | Ok l ->
          if (name <> "due" && name <> "until") || v = "" then Ok ((name, v) :: l)
          else (
            match When.parse ~today v with
            | Some d -> Ok ((name, Mail_sync.day d) :: l)
            | None -> Error (v ^ ": not a day (friday, in 3 days, nov 5)")))
    fields (Ok [])

(* add: an item made, stamped its id's kind unless stamp= says; set: its
 * fields given, an empty value taking one away; written at once *)
let add (caps : < caps ; .. >) (id : string) (fields : (string * string) list)
    : Exit.t =
  let store = Items.at (Items.place caps) in
  match (Items.find caps store id, String.index_opt id ':') with
  | Some _, _ -> fail caps (id ^ ": already an item")
  | None, None -> fail caps (id ^ ": an id is kind:name (task:pay-rent)")
  | None, Some i ->
      let stamps =
        match List.assoc_opt "stamp" fields with
        | Some s -> String.split_on_char ' ' s
        | None -> [ String.sub id 0 i ]
      in
      let fields = List.filter (fun (n, _) -> n <> "stamp") fields in
      Items.save caps store (Item.make ~id ~stamps fields "");
      Exit.OK

let set (caps : < caps ; .. >) (id : string) (fields : (string * string) list)
    : Exit.t =
  let store = Items.at (Items.place caps) in
  match Items.find caps store id with
  | None -> fail caps (id ^ ": no such item")
  | Some _ when List.mem_assoc "id" fields -> fail caps "id: an item's name"
  | Some item ->
      let item =
        List.fold_left
          (fun item (name, v) ->
            if v = "" then Mail.remove name item else Mail.set name v item)
          item fields
      in
      Items.save caps store item;
      Exit.OK

(* snooze: the uid's conversation archived until the day the words say,
 * back in the Inbox that day (Mail_sync) *)
let snooze (caps : < caps ; .. >) (o : options) (uid : int) (words : string) :
    Exit.t =
  match When.parse ~today:o.today words with
  | None -> fail caps (words ^ ": not a day (monday, in 3 days, nov 5)")
  | Some until ->
      reading caps o ~wake:false
        ~online:(fun store account t ->
          let listed =
            Mail_item.listed (Items.all caps store) ~account ~mailbox:o.mailbox
          in
          let conversation =
            match
              List.find_opt
                (List.exists (fun (s : Imap.summary) -> s.uid = uid))
                (Conversations.group listed)
            with
            | Some c -> List.map (fun (s : Imap.summary) -> s.uid) c
            | None -> [ uid ]
          in
          match
            Mail_sync.snooze caps store t ~account ~mailbox:o.mailbox
              conversation ~until
          with
          | Error e -> Error e
          | Ok () ->
              Console.print caps ("until " ^ Mail_sync.day until ^ "\n");
              Ok ())
        ~offline:(fun _ _ -> Error "snooze: the server's, not -offline")

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
      all = false;
      today = When.today ();
      args = [];
    }
  in
  let uids l = List.filter_map int_of_string_opt l in
  match options default (List.tl (Array.to_list argv)) with
  | Some ({ args = [ "send"; file ]; _ } as o) -> send caps o file
  | Some ({ args = [ "list" ]; _ } as o) -> list caps o
  | Some ({ args = [ "read"; uid ]; _ } as o) when uids [ uid ] <> [] ->
      read caps o (int_of_string uid)
  | Some ({ args = [ "reply"; uid ]; _ } as o) when uids [ uid ] <> [] ->
      draft caps o (int_of_string uid) ~forward:false
  | Some ({ args = [ "forward"; uid ]; _ } as o) when uids [ uid ] <> [] ->
      draft caps o (int_of_string uid) ~forward:true
  | Some ({ args = "snooze" :: uid :: (_ :: _ as words); _ } as o)
    when uids [ uid ] <> [] ->
      snooze caps o (int_of_string uid) (String.concat " " words)
  | Some { args = "search" :: (_ :: _ as words); _ } ->
      search caps (String.concat " " words)
  | Some { args = [ "show"; id ]; _ } -> show caps id
  | Some ({ args = [ "contact"; uid ]; _ } as o) when uids [ uid ] <> [] ->
      contact caps o (int_of_string uid)
  | Some { args = [ "people" ]; _ } -> people caps
  | Some ({ args = "add" :: id :: l; _ } as o) when assignments l <> None -> (
      match days o.today (Option.get (assignments l)) with
      | Ok fields -> add caps id fields
      | Error e -> fail caps e)
  | Some ({ args = "set" :: id :: (_ :: _ as l); _ } as o)
    when assignments l <> None -> (
      match days o.today (Option.get (assignments l)) with
      | Ok fields -> set caps id fields
      | Error e -> fail caps e)
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

let commands =
  [ "send"; "list"; "read"; "reply"; "forward"; "archive"; "snooze"; "search";
    "show"; "add"; "set"; "contact"; "people" ]

let () =
  Cap.main (fun caps ->
      Exit.exit caps
        (Exit.catch (fun () ->
             let argv = CapSys.argv caps in
             (* a command: the command line; else the window *)
             if List.exists (fun a -> List.mem a commands) (Array.to_list argv)
             then main caps argv
             else window caps)))
