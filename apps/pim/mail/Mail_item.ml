(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Mail_item.mli *)

let id (s : Imap.summary) : string =
  "mail:" ^ if s.msgid <> "" then s.msgid else string_of_int s.uid

(* the headers kept, those Imap.summaries asks *)
let headers =
  [
    "from";
    "to";
    "cc";
    "subject";
    "date";
    "message-id";
    "in-reply-to";
    "references";
  ]

(* "INBOX 12" -> "INBOX"; "[Gmail]/All Mail 345" -> "[Gmail]/All Mail" *)
let in_mailbox (v : string) : string =
  match String.rindex_opt v ' ' with Some i -> String.sub v 0 i | None -> v

let uid_in (item : Item.t) (mailbox : string) : int option =
  List.find_map
    (fun v ->
      let v = String.trim v in
      match String.rindex_opt v ' ' with
      | Some i when String.sub v 0 i = mailbox ->
          int_of_string_opt (String.sub v (i + 1) (String.length v - i - 1))
      | _ -> None)
    (Mail.get_all item "in")

let update ~(account : string) ~(mailbox : string) (s : Imap.summary)
    (old : Item.t option) : Item.t =
  let item =
    match old with
    | Some item -> item
    | None -> Item.make ~id:(id s) ~stamps:[ "message" ] [] ""
  in
  let item =
    if Item.has_stamp item "message" then item
    else
      Mail.set "stamp" (String.concat " " ("message" :: Item.stamps item)) item
  in
  let header name =
    match Mail.get s.headers name with Some v -> v | None -> ""
  in
  let fields =
    [
      ("account", account);
      ("mailbox", mailbox);
      ("uid", string_of_int s.uid);
      ("thread", s.thread);
      ("labels", Imap.list s.labels);
      ("flags", Imap.list s.flags);
    ]
    @ List.map (fun h -> (h, header h)) headers
  in
  let item =
    List.fold_left
      (fun item (name, value) ->
        if value = "" then Mail.remove name item else Mail.set name value item)
      item fields
  in
  (* its UID in each mailbox it was listed in (a UID is a mailbox's):
   * this one's line replaced, the others' kept *)
  let others =
    List.filter
      (fun (f : Mail.field) ->
        not
          (String.lowercase_ascii f.name = "in"
          && in_mailbox (String.trim f.raw) = mailbox))
      item.fields
  in
  { item with
    fields =
      others
      @ [ { Mail.name = "in"; raw = Printf.sprintf " %s %d" mailbox s.uid } ] }

let summary (item : Item.t) : Imap.summary =
  let list name =
    match Imap.values (Item.field item name) with
    | [ l ] -> Imap.texts l
    | _ -> []
  in
  let id = Item.id item in
  {
    uid =
      (match int_of_string_opt (Item.field item "uid") with
      | Some u -> u
      | None -> 0);
    flags = list "flags";
    labels = list "labels";
    thread = Item.field item "thread";
    msgid =
      (match String.index_opt id ':' with
      | Some i -> String.sub id (i + 1) (String.length id - i - 1)
      | None -> id);
    headers =
      Mail.make
        (List.filter_map
           (fun h ->
             match Mail.get item h with Some v -> Some (h, v) | None -> None)
           headers)
        "";
  }

let listed (items : Item.t list) ~(account : string) ~(mailbox : string) :
    Imap.summary list =
  (* (listed there once: its UID there, whatever was listed since) *)
  let l =
    List.filter_map
      (fun item ->
        if
          (not (Item.has_stamp item "message"))
          || Item.field item "account" <> account
        then None
        else
          match uid_in item mailbox with
          | Some uid -> Some { (summary item) with uid }
          | None when Item.field item "mailbox" = mailbox ->
              Some (summary item)
          | None -> None)
      items
  in
  let l =
    if mailbox = "INBOX" then
      List.filter (fun (s : Imap.summary) -> List.mem "\\Inbox" s.labels) l
    else l
  in
  List.sort (fun (a : Imap.summary) (b : Imap.summary) -> compare a.uid b.uid) l

let key (item : Item.t) : string = (summary item).msgid

let gone (item : Item.t) ~(mailbox : string) : Item.t =
  let item =
    { item with
      fields =
        List.filter
          (fun (f : Mail.field) ->
            not
              (String.lowercase_ascii f.name = "in"
              && in_mailbox (String.trim f.raw) = mailbox))
          item.fields }
  in
  if mailbox <> "INBOX" then item
  else
    let labels = List.filter (fun l -> l <> "\\Inbox") (summary item).labels in
    Mail.set "labels" (Imap.list labels) item

