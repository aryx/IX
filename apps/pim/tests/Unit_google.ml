(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Unit_google.mli *)

(* what Google's "Secret address in iCal format" sends, trimmed: a
 * weekly standup, its 2026-11-09 moved to 10:00, its 2026-11-16 taken
 * off; a lunch in UTC; a cancelled meeting *)
let ics =
  "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//Google Inc//Google Calendar 70.9054//EN\r\n\
   BEGIN:VEVENT\r\nDTSTART;TZID=Europe/Rome:20261102T093000\r\n\
   RRULE:FREQ=WEEKLY;BYDAY=MO\r\nEXDATE;TZID=Europe/Rome:20261116T093000\r\n\
   UID:standup@google.com\r\nSUMMARY:standup\r\nEND:VEVENT\r\n\
   BEGIN:VEVENT\r\nDTSTART;TZID=Europe/Rome:20261109T100000\r\n\
   RECURRENCE-ID;TZID=Europe/Rome:20261109T093000\r\n\
   UID:standup@google.com\r\nSUMMARY:standup\\, later\r\nEND:VEVENT\r\n\
   BEGIN:VEVENT\r\nDTSTART:20261103T113000Z\r\nDTEND:20261103T123000Z\r\n\
   UID:lunch@google.com\r\nSUMMARY:lunch\r\nEND:VEVENT\r\n\
   BEGIN:VEVENT\r\nDTSTART:20261104T090000Z\r\nSTATUS:CANCELLED\r\n\
   UID:gone@google.com\r\nSUMMARY:meeting\r\nEND:VEVENT\r\n\
   END:VCALENDAR\r\n"

let rome =
  match Zone.of_plan9 "CET 3600 CEST 7200\n" with
  | Some z -> z
  | None -> Alcotest.fail "zone"

let check = Alcotest.(check string)

let tests =
  [
    Testo.create "a Google calendar's export" (fun () ->
        let items = Events.of_ics rome ~message:"" ics in
        Alcotest.(check (list string)) "the items, the cancelled one left"
          [ "event:standup@google.com"; "event:standup@google.com@2026-11-09";
            "event:lunch@google.com" ]
          (List.map Item.id items);
        let lunch = List.nth items 2 in
        check "UTC at Rome's clock" "2026-11-03 12:30" (Item.field lunch "when");
        check "its end too" "13:30" (Item.field lunch "end");
        check "the series' days skipped" "2026-11-16 2026-11-09"
          (Item.field (List.hd items) "except");
        let days =
          List.map
            (fun (d, t, i) ->
              Printf.sprintf "%s %s %s" (Civil.to_string d)
                (match t with Some t -> Events.clock t | None -> "-")
                (Item.field i "title"))
            (Events.between items ~from:{ year = 2026; month = 11; day = 2 }
               ~upto:{ year = 2026; month = 11; day = 23 })
        in
        Alcotest.(check (list string)) "the Mondays, one moved, one off"
          [ "2026-11-02 9:30 standup"; "2026-11-03 12:30 lunch";
            "2026-11-09 10:00 standup, later"; "2026-11-23 9:30 standup" ]
          days);
    Testo.create "an event of several days" (fun () ->
        let ics =
          "BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nUID:roma@g\r\n\
           DTSTART;VALUE=DATE:20261103\r\nDTEND;VALUE=DATE:20261108\r\n\
           SUMMARY:Roma\r\nEND:VEVENT\r\nBEGIN:VEVENT\r\nUID:night@g\r\n\
           DTSTART:20261110T220000\r\nDTEND:20261111T020000\r\n\
           SUMMARY:night train\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n"
        in
        let items = Events.of_ics Zone.utc ~message:"" ics in
        let roma = List.hd items in
        check "its last day: DTEND's the day after" "2026-11-07"
          (Item.field roma "ends");
        Alcotest.(check int) "five days" 5 (Events.length roma);
        check "a night: its last day the morning's" "2026-11-11"
          (Item.field (List.nth items 1) "ends");
        let days =
          List.map
            (fun (d, t, i) ->
              Printf.sprintf "%s %s %s" (Civil.to_string d)
                (match t with Some t -> Events.clock t | None -> "-")
                (Item.field i "title"))
            (Events.between items ~from:{ year = 2026; month = 11; day = 5 }
               ~upto:{ year = 2026; month = 11; day = 11 })
        in
        Alcotest.(check (list string)) "each day it covers, begun before"
          [ "2026-11-05 - Roma"; "2026-11-06 - Roma"; "2026-11-07 - Roma";
            "2026-11-10 22:00 night train"; "2026-11-11 - night train" ]
          days;
        Alcotest.(check int) "a week's bars: Roma, the night" 2
          (List.length
             (Events.spans items ~from:{ year = 2026; month = 11; day = 2 }
                ~upto:{ year = 2026; month = 11; day = 15 })));
    Testo.create "a calendar merged again" (fun () ->
        let ev id title =
          Item.make ~id ~stamps:[ "event" ]
            [ ("title", title); ("when", "2026-11-03") ] ""
        in
        let store =
          List.map (Mail.set "calendar" "me")
            [ ev "event:a" "a"; ev "event:b" "b"; ev "event:c" "c" ]
          @ [ ev "event:mine" "of the suite's own" ]
        in
        let changed, gone =
          Calendars.merge store "me" [ ev "event:a" "a"; ev "event:b" "B!" ]
        in
        Alcotest.(check (list string)) "only what changed written" [ "event:b" ]
          (List.map Item.id changed);
        Alcotest.(check (list string)) "what went removed, not the suite's"
          [ "event:c" ] gone);
    Testo.create "a vCard export" (fun () ->
        let vcf =
          "BEGIN:VCARD\r\nVERSION:3.0\r\nFN:Alice Martin\r\nN:Martin;Alice;;;\r\n\
           EMAIL;TYPE=INTERNET;TYPE=HOME:Alice@ix\r\n\
           item1.EMAIL;TYPE=INTERNET:alice@work.example\r\n\
           TEL;TYPE=CELL:+33 6 12 34 56 78\r\nBDAY:1980-03-15\r\n\
           NOTE:met at the\r\n  conference\r\nEND:VCARD\r\n\
           BEGIN:VCARD\r\nVERSION:3.0\r\nN:Brown;Dan;;;\r\nBDAY:--0704\r\n\
           EMAIL:dan@ix\r\nEND:VCARD\r\n\
           BEGIN:VCARD\r\nVERSION:3.0\r\nFN:Jean Dupont\r\n\
           TEL:+33 6 00 00 00 00\r\nEND:VCARD\r\n\
           BEGIN:VCARD\r\nVERSION:3.0\r\nNOTE:nothing\r\nEND:VCARD\r\n"
        in
        let cards = Vcard.of_string vcf in
        Alcotest.(check int) "four cards" 4 (List.length cards);
        match List.filter_map Vcard.to_item cards with
        | [ a; d; j ] ->
            check "no address: its name's id" "contact:jean-dupont" (Item.id j);
            check "its phone" "+33 6 00 00 00 00" (Item.field j "phone");
            check "her id, her first address" "contact:alice@ix" (Item.id a);
            Alcotest.(check (list string)) "both addresses"
              [ "alice@ix"; "alice@work.example" ] (People.emails a);
            check "a phone" "+33 6 12 34 56 78" (Item.field a "phone");
            check "a birthday" "1980-03-15" (Item.field a "birthday");
            check "the note, unfolded" "met at the conference"
              (String.trim a.body);
            check "N's names" "Dan Brown" (Item.field d "name");
            check "a birthday without a year" "--07-04"
              (Item.field d "birthday")
        | l -> Alcotest.failf "%d contacts" (List.length l));
  ]
