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
  List.fold_left
    (fun item (name, value) ->
      if value = "" then Mail.remove name item else Mail.set name value item)
    item fields

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
  let mine item =
    Item.has_stamp item "message"
    && Item.field item "account" = account
    && Item.field item "mailbox" = mailbox
  in
  let l = List.map summary (List.filter mine items) in
  let l =
    if mailbox = "INBOX" then
      List.filter (fun (s : Imap.summary) -> List.mem "\\Inbox" s.labels) l
    else l
  in
  List.sort (fun (a : Imap.summary) (b : Imap.summary) -> compare a.uid b.uid) l

let key (item : Item.t) : string = (summary item).msgid
