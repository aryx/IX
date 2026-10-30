(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Unit_capture.mli *)

(* a Thursday *)
let today : Civil.date = { year = 2026; month = 10; day = 29 }

let alice =
  Item.make ~id:"contact:alice@ix" ~stamps:[ "contact" ]
    [ ("name", "Alice Martin"); ("email", "alice@ix") ]
    ""

(* an event as "title|day|time|repeat|with" *)
let said (line : string) : string =
  let e = Capture.event ~today ~people:[ alice ] line in
  String.concat "|"
    [ e.title; Civil.to_string e.day;
      (match e.time with Some t -> Events.clock t | None -> "-");
      e.repeat; String.concat " " e.with_ ]

let check = Alcotest.(check string)

let event id when_ more =
  Item.make ~id ~stamps:[ "event" ] ([ ("title", id); ("when", when_) ] @ more) ""

let tests =
  [
    Testo.create "a line made an event" (fun () ->
        check "the plan's example"
          "lunch with alice|2026-11-03|12:30||contact:alice@ix"
          (said "lunch with alice tue 12:30");
        check "a repeat, 9h30" "standup|2026-11-02|9:30|FREQ=WEEKLY;BYDAY=MO|"
          (said "standup every monday 9h30");
        check "at 4pm, nov 5" "dentist|2026-11-05|16:00||"
          (said "dentist nov 5 at 4pm");
        check "French" "déjeuner avec alice|2026-11-03|12:30||contact:alice@ix"
          (said "déjeuner avec alice mardi 12h30");
        check "no day: today, no time" "call the bank|2026-10-29|-||"
          (said "call the bank");
        check "every thursday: today is one"
          "yoga|2026-10-29|-|FREQ=WEEKLY;BYDAY=TH|" (said "yoga every thursday");
        check "an unknown with" "tea with bob|2026-10-30|-||"
          (said "tea with bob tomorrow"));
    Testo.create "a week's occurrences" (fun () ->
        let items =
          [ event "lunch" "2026-11-03 12:30" [];
            event "standup" "2026-10-26 9:30"
              [ ("repeat", "FREQ=WEEKLY;BYDAY=MO,WE") ];
            event "holiday" "2026-11-04" [];
            event "later" "2026-12-01" [] ]
        in
        let got =
          List.map
            (fun (d, t, i) ->
              Printf.sprintf "%s %s %s" (Civil.to_string d)
                (match t with Some t -> Events.clock t | None -> "-")
                (Item.field i "title"))
            (Events.between items ~from:{ today with day = 30 }
               ~upto:{ year = 2026; month = 11; day = 5 })
        in
        Alcotest.(check (list string)) "by day, then the day's, then by time"
          [ "2026-11-02 9:30 standup"; "2026-11-03 12:30 lunch";
            "2026-11-04 - holiday"; "2026-11-04 9:30 standup" ]
          got);
    Testo.create "an invitation's iCalendar" (fun () ->
        let ics =
          "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nMETHOD:REQUEST\r\n\
           BEGIN:VEVENT\r\nUID:abc/1@google.com\r\n\
           DTSTART:20261103T123000\r\nDTEND:20261103T133000\r\n\
           SUMMARY:Lunch\\, then a walk\r\nLOCATION:the canteen\r\n\
           END:VEVENT\r\nEND:VCALENDAR\r\n"
        in
        match Events.of_ics ~message:"mail:7" ics with
        | [ e ] ->
            check "its id" "event:abc-1@google.com" (Item.id e);
            check "its title" "Lunch, then a walk" (Item.field e "title");
            check "when" "2026-11-03 12:30" (Item.field e "when");
            check "end" "13:30" (Item.field e "end");
            check "where" "the canteen" (Item.field e "where");
            check "the mail it came in" "mail:7" (Item.field e "re")
        | l -> Alcotest.failf "%d events" (List.length l));
  ]
