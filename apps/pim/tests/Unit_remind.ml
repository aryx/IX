(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Unit_remind.mli *)

let item id stamp fields = Item.make ~id ~stamps:[ stamp ] fields ""

let items =
  [ item "event:lunch" "event" [ ("title", "lunch"); ("when", "2026-11-03 12:30") ];
    item "event:call" "event"
      [ ("title", "call"); ("when", "2026-11-03 15:00"); ("remind", "0") ];
    item "event:gym" "event"
      [ ("title", "gym"); ("when", "2026-11-03 18:00"); ("remind", "no") ];
    item "event:night" "event"
      [ ("title", "night train"); ("when", "2026-11-04 0:05") ];
    item "task:bank" "task"
      [ ("title", "call the bank"); ("remind", "2026-11-03 9:00") ];
    item "task:old" "task"
      [ ("title", "done already"); ("remind", "2026-11-03 9:00");
        ("done", "2026-11-02") ] ]

let tue : Civil.date = { year = 2026; month = 11; day = 3 }

let said ~from ~upto =
  List.map
    (fun (m, i) -> Printf.sprintf "%s %s" (Events.clock (m mod 1440)) (Remind.say i))
    (Remind.due items tue ~from ~upto)

let tests =
  [
    Testo.create "a day's reminders" (fun () ->
        Alcotest.(check (list string)) "the whole day"
          [ "9:00 call the bank"; "12:20 lunch at 12:30"; "15:00 call at 15:00";
            "23:55 night train at 0:05" ]
          (said ~from:0 ~upto:1440);
        Alcotest.(check (list string)) "one minute, the one asked" []
          (said ~from:741 ~upto:742);
        Alcotest.(check (list string)) "12:20 alone" [ "12:20 lunch at 12:30" ]
          (said ~from:740 ~upto:741));
  ]
