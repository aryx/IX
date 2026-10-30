(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Unit_envelopes.mli *)

let day : Civil.date = { year = 2026; month = 11; day = 1 }

let line id payee category amount =
  Item.make ~id ~stamps:[ "money" ]
    [ ("date", "2026-11-02"); ("payee", payee);
      ("posting", category ^ "  " ^ amount); ("posting", "Assets:Checking") ]
    ""

let tests =
  [
    Testo.create "envelopes" (fun () ->
        let items =
          [ Item.make ~id:"money:pay" ~stamps:[ "money" ]
              [ ("date", "2026-11-01"); ("payee", "Acme");
                ("posting", "Assets:Checking  2000.00");
                ("posting", "Income:Salary") ]
              "";
            line "money:food" "Safeway" "Expenses:Groceries" "42.17";
            line "money:edf" "EDF" "Expenses:Utilities" "62.40";
            Envelopes.assign ~id:"budget:1" day "Groceries" 40000;
            Envelopes.assign ~id:"budget:2" day "Utilities" 5000;
            Envelopes.assign ~id:"budget:3" day "Rent" 90000;
            (* (100 moved from Rent to Groceries) *)
            Envelopes.assign ~id:"budget:4" day "Rent" (-10000);
            Envelopes.assign ~id:"budget:5" day "Groceries" 10000 ]
        in
        Alcotest.(check (list string)) "assigned, spent, available"
          [ "Expenses:Groceries 50000 4217 45783";
            "Expenses:Rent 80000 0 80000";
            "Expenses:Utilities 5000 6240 -1240" ]
          (List.map
             (fun (e : Envelopes.envelope) ->
               Printf.sprintf "%s %d %d %d" e.account e.assigned e.spent
                 e.available)
             (Envelopes.envelopes items));
        (* the cash, 2000 - 42.17 - 62.40, less 457.83 and 800 *)
        Alcotest.(check int) "to assign" 63760 (Envelopes.to_assign items));
  ]
