(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Unit_compose.mli *)

let str = Alcotest.(check string)

let question =
  Mail.parse
    "From: Carol <carol@ix>\n\
     To: erin@ix, Bob <bob@ix>\n\
     Cc: carol@ix, dave@ix, BOB@ix\n\
     Subject: RE: the plan\n\
     Date: Thu, 29 Oct 2026 11:00:00 +0100\n\
     Message-ID: <2@ix>\n\
     References: <1@ix>\n\
     \n\
     Noon?\n\
     \n\
     C.\n"

let tests =
  [
    Testo.create "a reply to all" (fun () ->
        let d =
          Mail_compose.reply ~id:"draft:1" ~all:true ~me:"Erin@ix" question
            "Noon?\n\nC.\n"
        in
        str "to the sender" "Carol <carol@ix>" d.to_;
        str "the others once, not me" "Bob <bob@ix>, dave@ix" d.cc;
        str "Re: once, whatever its case" "RE: the plan" d.subject;
        str "in reply to" "<2@ix>" d.in_reply_to;
        str "the thread's ids" "<1@ix> <2@ix>" d.references;
        str "quoted"
          "\n\nOn Thu, 29 Oct 2026 11:00:00 +0100, Carol <carol@ix> wrote:\n\
           > Noon?\n>\n> C.\n"
          d.text;
        let d = Mail_compose.reply ~id:"" ~all:false ~me:"erin@ix" question "" in
        str "to the sender alone" "" d.cc);
    Testo.create "Reply-To: is where a reply goes" (fun () ->
        let m = Mail.set "Reply-To" "list@ix" question in
        let d = Mail_compose.reply ~id:"" ~all:false ~me:"erin@ix" m "" in
        str "the list" "list@ix" d.to_);
    Testo.create "a forward" (fun () ->
        let d = Mail_compose.forward ~id:"" ~key:"77" question "Noon?" in
        str "Fwd:" "Fwd: RE: the plan" d.subject;
        str "no thread" "" d.in_reply_to;
        str "the message named" "77" d.forward;
        Alcotest.(check bool) "its headers then its text" true
          (String.ends_with ~suffix:"Cc: carol@ix, dave@ix, BOB@ix\n\nNoon?\n"
             d.text));
    Testo.create "a draft as an item and back" (fun () ->
        let d =
          { (Mail_compose.reply ~id:"draft:9" ~all:true ~me:"erin@ix" question
               "Noon?")
            with attach = "/tmp/a.png" }
        in
        let item = Item.parse (Item.to_string (Mail_compose.to_item d)) in
        Alcotest.(check (list string)) "stamped" [ "draft" ] (Item.stamps item);
        Alcotest.(check bool) "the same" true (Mail_compose.of_item item = d));
    Testo.create "the message sent: dated, a file attached" (fun () ->
        let d =
          { (Mail_compose.blank ~id:"") with
            to_ = "bob@ix"; subject = "café"; text = "un café\n" }
        in
        let msgid = Mail_compose.new_msgid ~from:"Erin <erin@ix>" 1e9 3 in
        str "its id" "<1000000000.3.mini-pim@ix>" msgid;
        let m =
          Mail_compose.message ~from:"erin@ix" ~date:1e9 ~offset:60 ~msgid
            ~files:[ ("a.png", "\137PNG") ] d
        in
        let m = Mail.parse (Mail.to_string m) in
        let h name = match Mail.get m name with Some v -> v | None -> "" in
        str "the date, an hour east" "Sun, 9 Sep 2001 02:46:40 +0100" (h "date");
        str "the subject" "café" (Mime.decode_words (h "subject"));
        str "the text (its last newline the boundary's)" "un café" (Mime.text m);
        match Mime.attachments m with
        | [ a ] ->
            Alcotest.(check (option string)) "its name" (Some "a.png") a.filename;
            str "its bytes" "\137PNG" a.data
        | l -> Alcotest.failf "%d attachments" (List.length l));
    Testo.create "a file sent as written: MIME when not ASCII" (fun () ->
        let m = Mail.parse "To: bob@ix\n\nsoon\n" in
        Alcotest.(check bool) "ASCII as it is" true (Mail_compose.complete m = m);
        let m = Mail_compose.complete (Mail.parse "To: bob@ix\n\nà midi\n") in
        str "UTF-8" "text/plain; charset=utf-8"
          (match Mail.get m "content-type" with Some v -> v | None -> "");
        str "read back" "à midi\n" (Mime.text m));
  ]
