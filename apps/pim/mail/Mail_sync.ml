(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Mail_sync.mli *)

type server = { host : string; port : int; plain : bool }

let gmail = { host = "imap.gmail.com"; port = 993; plain = false }

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
  let conn =
    if s.plain then Lines.plain caps ~host:s.host ~port:s.port
    else
      Lines.tls caps ~trust:(Tls_client.system_roots caps) ~host:s.host
        ~port:s.port
  in
  match conn with
  | Error why -> Error (Printf.sprintf "%s:%d: %s" s.host s.port why)
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
