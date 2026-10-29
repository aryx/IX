(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Unit_items.mli *)

type caps = < Cap.env ; Cap.open_in ; Cap.open_out ; Cap.readdir >

let str = Alcotest.(check string)
let strs = Alcotest.(check (list string))

(* a directory of the test's, named in $PIM_STORE, not yet made *)
let fresh () : string =
  let d =
    Filename.concat
      (Filename.get_temp_dir_name ())
      (Printf.sprintf "ix-pim-%d-%d" (Unix.getpid ()) (Random.bits ()))
  in
  Unix.mkdir d 0o755;
  let dir = Filename.concat d "store" in
  Unix.putenv "PIM_STORE" dir;
  dir

let summary ?(labels = [ "\\Inbox" ]) ?(flags = []) uid subject : Imap.summary =
  {
    uid;
    flags;
    labels;
    thread = "7";
    msgid = string_of_int (100 + uid);
    headers =
      Mail.make [ ("From", "Alice <alice@ix>"); ("Subject", subject) ] "";
  }

let tests (caps : caps) =
  Testo.categorize "Items"
    [
      Testo.create "the store: saved, found, all, saved over, the cache"
        (fun () ->
          let dir = fresh () in
          str "the place $PIM_STORE says" dir (Items.place caps);
          let store = Items.at dir in
          Alcotest.(check int)
            "nothing yet" 0
            (List.length (Items.all caps store));
          let note =
            Item.make ~id:"note:a" ~stamps:[ "note" ]
              [ ("title", "a") ]
              "text\n"
          in
          Items.save caps store note;
          Items.save caps store
            (Item.make ~id:"contact:b" ~stamps:[ "contact" ] [] "");
          strs "all, by id" [ "contact:b"; "note:a" ]
            (List.map Item.id (Items.all caps store));
          (match Items.find caps store "note:a" with
          | Some n ->
              str "its text" "text\n" n.body;
              strs "its stamps" [ "note" ] (Item.stamps n)
          | None -> Alcotest.fail "not found");
          Items.save caps store (Mail.set "title" "b" note);
          str "saved over" "b"
            (match Items.find caps store "note:a" with
            | Some n -> Item.field n "title"
            | None -> "");
          str "a plain file" "id: note:a\nstamp: note\ntitle: b\n\ntext\n"
            (In_channel.with_open_bin
               (Filename.concat (Filename.concat dir "items") "note:a")
               In_channel.input_all);
          Alcotest.(check (option string))
            "not cached" None
            (Items.cached caps store "101");
          Items.cache caps store "101" "Subject: x\n\nbody\n";
          Alcotest.(check (option string))
            "cached" (Some "Subject: x\n\nbody\n")
            (Items.cached caps store "101"));
      Testo.create
        "a message's item: the server's fields replaced, a person's kept"
        (fun () ->
          let item =
            Mail_item.update ~account:"bob" ~mailbox:"INBOX" (summary 1 "lunch")
              None
          in
          str "its id, Gmail's X-GM-MSGID" "mail:101" (Item.id item);
          (* a person makes it a task, due Friday *)
          let item =
            Mail.set "stamp" "message task" (Mail.set "due" "2026-10-30" item)
          in
          let item =
            Mail_item.update ~account:"bob" ~mailbox:"INBOX"
              (summary ~flags:[ "\\Seen" ] ~labels:[ "\\Inbox"; "my trips" ] 1
                 "lunch")
              (Some item)
          in
          strs "still a task" [ "message"; "task" ] (Item.stamps item);
          str "still due" "2026-10-30" (Item.field item "due");
          str "labels, one with a space" "(\\Inbox \"my trips\")"
            (Item.field item "labels");
          let s = Mail_item.summary item in
          strs "read back" [ "\\Inbox"; "my trips" ] s.labels;
          strs "flags" [ "\\Seen" ] s.flags;
          str "the headers" "lunch" (Item.field s.headers "subject");
          str "the cache's key" "101" (Mail_item.key item));
      Testo.create "listed: the mailbox's, by UID, INBOX's still in it"
        (fun () ->
          let items =
            List.map
              (fun s -> Mail_item.update ~account:"bob" ~mailbox:"INBOX" s None)
              [ summary 3 "c"; summary 1 "a"; summary ~labels:[] 2 "archived" ]
            @ [
                Mail_item.update ~account:"eve" ~mailbox:"INBOX" (summary 4 "d")
                  None;
              ]
          in
          Alcotest.(check (list int))
            "bob's, in the Inbox" [ 1; 3 ]
            (List.map
               (fun (s : Imap.summary) -> s.uid)
               (Mail_item.listed items ~account:"bob" ~mailbox:"INBOX")));
    ]
