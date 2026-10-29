(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Mail_sync.mli *)

type server = { host : string; port : int; plain : bool }

let gmail = { host = "imap.gmail.com"; port = 993; plain = false }
let gmail_smtp = { host = "smtp.gmail.com"; port = 465; plain = false }

let connect (caps : < Cap.network ; Cap.open_in ; .. >) (s : server) :
    (Lines.t, string) result =
  let conn =
    if s.plain then Lines.plain caps ~host:s.host ~port:s.port
    else
      Lines.tls caps ~trust:(Tls_client.system_roots caps) ~host:s.host
        ~port:s.port
  in
  match conn with
  | Ok c -> Ok c
  | Error why -> Error (Printf.sprintf "%s:%d: %s" s.host s.port why)

let all_mail = "[Gmail]/All Mail"

(* the server's name of [mailbox]: All Mail's is found by its \All *)
let named (t : Imap.t) (mailbox : string) : (string, string) result =
  if mailbox <> all_mail then Ok mailbox
  else
    match Imap.mailboxes t with
    | Error e -> Error e
    | Ok l -> (
        let all (attributes, _) =
          List.exists (fun a -> String.lowercase_ascii a = "\\all") attributes
        in
        match List.find_opt all l with
        | Some (_, name) -> Ok name
        | None -> Ok mailbox)

let session (caps : < Cap.network ; Cap.open_in ; .. >) (s : server)
    ~(user : string) ~(password : string) ~(mailbox : string)
    (f : Imap.t -> ('a, string) result) : ('a, string) result =
  match connect caps s with
  | Error why -> Error why
  | Ok conn -> (
      let ( let* ) r f = match r with Ok x -> f x | Error e -> Error e in
      let r =
        let* t = Imap.connect conn in
        let* () = Imap.login t ~user ~password in
        let* name = named t mailbox in
        let* _ = Imap.select t name in
        let r = f t in
        Imap.logout t;
        r
      in
      match r with
      | Ok x -> Ok x
      | Error e -> Lines.close conn; Error e)

let saved_password (caps : < Cap.env ; Cap.open_in ; .. >) :
    (string option, string) result =
  let file = Filename.concat (Items.place caps) "password" in
  match Unix.stat file with
  | exception Unix.Unix_error _ -> Ok None
  | st when st.st_perm land 0o077 <> 0 ->
      Error
        (Printf.sprintf "%s: others may read it (chmod 600 %s), not used"
           file file)
  | _ -> (
      match FS.read_opt caps (Fpath.v file) with
      | None -> Ok None
      | Some text -> (
          match String.trim (List.hd (String.split_on_char '\n' text)) with
          | "" -> Ok None
          | p -> Ok (Some p)))

let keep (caps : < Cap.open_in ; Cap.open_out ; .. >) (store : Items.t)
    ~(account : string) ~(mailbox : string) (l : Imap.summary list) : unit =
  List.iter
    (fun (s : Imap.summary) ->
      let old = Items.find caps store (Mail_item.id s) in
      Items.save caps store (Mail_item.update ~account ~mailbox s old))
    l

let newest (n : int) (l : 'a list) : 'a list =
  let k = List.length l in
  List.filteri (fun i _ -> i >= k - n) l

let list (caps : < Cap.open_in ; Cap.open_out ; .. >) (store : Items.t)
    (t : Imap.t) ~(account : string) ~(mailbox : string)
    ~(query : string option) (n : int) : (Imap.summary list, string) result =
  let q = match query with Some q -> "X-GM-RAW " ^ Imap.quote q | None -> "ALL" in
  match Imap.search t q with
  | Error e -> Error e
  | Ok uids -> (
      match Imap.summaries t (newest n uids) with
      | Error e -> Error e
      | Ok l -> keep caps store ~account ~mailbox l; Ok l)

let message (caps : < Cap.open_in ; Cap.open_out ; .. >) (store : Items.t)
    (t : Imap.t) ~(account : string) ~(mailbox : string) (uid : int) :
    (string, string) result =
  match Imap.summaries t [ uid ] with
  | Error e -> Error e
  | Ok [] -> Error (Printf.sprintf "no message %d in %s" uid mailbox)
  | Ok (s :: _) -> (
      let key = Mail_item.key (Mail_item.update ~account ~mailbox s None) in
      let text =
        match Items.cached caps store key with
        | Some text -> (
            match Imap.store t [ uid ] "+FLAGS (\\Seen)" with
            | Ok () -> Ok text
            | Error e -> Error e)
        | None -> (
            match Imap.message t uid with
            | Ok text -> Items.cache caps store key text; Ok text
            | Error e -> Error e)
      in
      match text with
      | Error e -> Error e
      | Ok text ->
          let seen =
            if List.mem "\\Seen" s.flags then s
            else { s with flags = s.flags @ [ "\\Seen" ] }
          in
          keep caps store ~account ~mailbox [ seen ];
          Ok text)

let item_of (caps : < Cap.open_in ; Cap.readdir ; .. >) (store : Items.t)
    ~(account : string) ~(mailbox : string) (uid : int) : Item.t option =
  let l = Mail_item.listed (Items.all caps store) ~account ~mailbox in
  match List.find_opt (fun (s : Imap.summary) -> s.uid = uid) l with
  | Some s -> Items.find caps store (Mail_item.id s)
  | None -> None

let archive (caps : < Cap.open_in ; Cap.open_out ; Cap.readdir ; .. >)
    (store : Items.t) (t : Imap.t) ~(account : string) ~(mailbox : string)
    (uids : int list) : (unit, string) result =
  match Imap.store t uids "-X-GM-LABELS (\\Inbox)" with
  | Error e -> Error e
  | Ok () ->
      List.iter
        (fun uid ->
          match item_of caps store ~account ~mailbox uid with
          | None -> ()
          | Some item ->
              let s = Mail_item.summary item in
              let labels = List.filter (fun l -> l <> "\\Inbox") s.labels in
              Items.save caps store (Mail.set "labels" (Imap.list labels) item))
        uids;
      Ok ()

(*****************************************************************************)
(* Sending *)
(*****************************************************************************)

let send (caps : < Cap.network ; Cap.open_in ; .. >) (s : server)
    ~(auth : (string * string) option) (mail : Mail.t) :
    (Smtp.outcome list, string) result =
  let sender =
    match Option.bind (Mail.get mail "from") Mail.address with
    | Some a -> a.mailbox
    | None -> ( match auth with Some (u, _) -> u | None -> "")
  in
  match connect caps s with
  | Error why -> Error why
  | Ok conn -> (
      let c =
        Smtp.client ~hello:"mini-pim" ~auth [ Smtp.envelope ~sender mail ]
      in
      let c = Lines.talk conn Smtp.step c (fun c -> Smtp.finished c <> None) in
      let why = Lines.why conn in
      Lines.close conn;
      match Smtp.finished c with
      | Some (Ok outcomes) -> Ok outcomes
      | Some (Error said) -> Error ("the server: " ^ said)
      | None ->
          Error (match why with Some w -> w | None -> "the connection ended"))

let said (o : Smtp.outcome) : string =
  match o with
  | Sent (n, []) -> Printf.sprintf "sent to %d" n
  | Sent (n, refused) ->
      Printf.sprintf "sent to %d, refused: %s" n (String.concat "; " refused)
  | Refused why -> "refused: " ^ why

(* now, at Greenwich: a Date: in +0000, which a reader shows in its own
 * zone (mini-ml's Unix has no localtime to know this place's) *)
let now () : float * int = (Unix.gettimeofday (), 0)

let sent = ref 0

(* a draft's files: those it names, and a forwarded message's *)
let files (caps : < Cap.open_in ; .. >) (store : Items.t)
    (d : Mail_compose.draft) : ((string * string) list, string) result =
  let named =
    List.filter (fun w -> w <> "") (String.split_on_char ' ' d.attach)
  in
  let read =
    List.map
      (fun f ->
        match FS.read_opt caps (Fpath.v f) with
        | Some bytes -> Ok (Filename.basename f, bytes)
        | None -> Error (f ^ ": cannot read it"))
      named
  in
  match List.find_opt Result.is_error read with
  | Some (Error e) -> Error e
  | _ ->
      let forwarded =
        match d.forward with
        | "" -> []
        | key -> (
            match Items.cached caps store key with
            | None -> []
            | Some text ->
                List.map
                  (fun (l : Mime.leaf) ->
                    ( (match l.filename with Some f -> f | None -> "attachment"),
                      l.data ))
                  (Mime.attachments (Mail.parse text)))
      in
      Ok (List.filter_map Result.to_option read @ forwarded)

let send_draft (caps : < Cap.network ; Cap.open_in ; Cap.open_out ; .. >)
    (store : Items.t) (s : server) ~(user : string) ~(password : string)
    (d : Mail_compose.draft) : (string, string) result =
  match files caps store d with
  | Error e -> Error e
  | Ok files -> (
      let date, offset = now () in
      incr sent;
      let msgid = Mail_compose.new_msgid ~from:user date !sent in
      let m = Mail_compose.message ~from:user ~date ~offset ~msgid ~files d in
      match send caps s ~auth:(Some (user, password)) m with
      | Error e -> Error e
      | Ok outcomes ->
          let taken (o : Smtp.outcome) =
            match o with Sent _ -> true | Refused _ -> false
          in
          let text = String.concat "; " (List.map said outcomes) in
          if List.for_all taken outcomes then begin
            if d.id <> "" then Items.remove caps store d.id;
            Ok text
          end
          else Error text)
