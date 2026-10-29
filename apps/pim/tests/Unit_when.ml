(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Unit_when.mli *)

(* a Thursday *)
let today : Civil.date = { year = 2026; month = 10; day = 29 }

let day (words : string) : string =
  match When.parse ~today words with
  | Some d -> Printf.sprintf "%04d-%02d-%02d" d.year d.month d.day
  | None -> "none"

let check = Alcotest.(check string)

let tests =
  [
    Testo.create "days as words" (fun () ->
        check "today" "2026-10-29" (day "today");
        check "tomorrow" "2026-10-30" (day "Tomorrow");
        check "monday, the next" "2026-11-02" (day "monday");
        check "thursday: never today" "2026-11-05" (day "thu");
        check "the weekend" "2026-10-31" (day "weekend");
        check "next week: Monday" "2026-11-02" (day "next week");
        check "next month" "2026-11-29" (day "next month");
        check "in 3 days" "2026-11-01" (day "in 3 days");
        check "2 weeks" "2026-11-12" (day "2 weeks");
        check "nov 5" "2026-11-05" (day "nov 5");
        check "5 november" "2026-11-05" (day "5 November");
        check "past: next year's" "2027-01-15" (day "jan 15");
        check "a date" "2026-12-01" (day "2026/12/01"));
    Testo.create "the author's French" (fun () ->
        check "demain" "2026-10-30" (day "demain");
        check "lundi" "2026-11-02" (day "lundi");
        check "dans 2 semaines" "2026-11-12" (day "dans 2 semaines");
        check "5 décembre" "2026-12-05" (day "5 décembre");
        check "la semaine prochaine" "2026-11-02" (day "la semaine prochaine"));
    Testo.create "not a day" (fun () ->
        check "words" "none" (day "someday");
        check "nothing" "none" (day "");
        check "feb 30" "none" (day "feb 30"));
  ]
