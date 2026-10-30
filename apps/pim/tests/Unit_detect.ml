(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Unit_detect.mli *)

(* a Thursday *)
let today : Civil.date = { year = 2026; month = 10; day = 29 }

let show (f : Detect.found) : string =
  match f.kind with
  | Day (d, t) ->
      Printf.sprintf "day %s %s [%s]" (Civil.to_string d)
        (match t with Some t -> Events.clock t | None -> "-")
        f.said
  | Amount c -> Printf.sprintf "amount %d [%s]" c f.said
  | Address (name, a) -> Printf.sprintf "address %s <%s> [%s]" name a f.said

let found (text : string) : string list =
  List.map show (Detect.find ~today text)

let check = Alcotest.(check (list string))

let tests =
  [
    Testo.create "days, amounts, addresses in a message" (fun () ->
        check "the mli's example"
          [ "day 2026-11-03 12:30 [tuesday at 12:30]";
            "amount 2450 [24,50 €]";
            "address Dan Brown <dan@ix> [dan@ix]" ]
          (found
             "Lunch on tuesday at 12:30? It's 24,50 € a head.\n\
              Dan Brown <dan@ix> comes too.");
        check "dates written other ways"
          [ "day 2026-11-05 16:00 [nov 5 at 4pm]";
            "day 2026-11-01 - [in 3 days]";
            "day 2026-12-24 - [2026-12-24]" ]
          (found "The dentist, nov 5 at 4pm. Or in 3 days; or 2026-12-24.");
        check "French"
          [ "day 2026-11-03 12:30 [mardi 12h30]"; "amount 6240 [62,40€]" ]
          (found "Déjeuner mardi 12h30, l'addition 62,40€.");
        check "amounts"
          [ "amount 6240 [$62.40]"; "amount 193760 [1,937.60 USD]";
            "amount 1200 [EUR 12]"; "amount 3000 [30 dollars]" ]
          (found "Paid $62.40, then 1,937.60 USD, EUR 12 and 30 dollars.");
        check "no day: a month or a word alone" []
          (found "It may rain; the sun is out. Mon dieu. 12 apples.");
        check "once each" [ "day 2026-10-30 - [tomorrow]" ]
          (found "tomorrow\nsee you tomorrow"));
    Testo.create "a number's cents" (fun () ->
        let c = Alcotest.(check (option int)) in
        c "dot" (Some 6240) (Detect.cents_of "62.40");
        c "comma" (Some 6240) (Detect.cents_of "62,40");
        c "thousands" (Some 193760) (Detect.cents_of "1,937.60");
        c "French thousands" (Some 100050) (Detect.cents_of "1.000,50");
        c "whole" (Some 1200) (Detect.cents_of "12");
        c "no number" None (Detect.cents_of "a12"));
  ]
