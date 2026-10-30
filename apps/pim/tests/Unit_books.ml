(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Unit_books.mli *)

let d day : Civil.date = { year = 2026; month = 10; day }

let money id date payee postings =
  Item.make ~id ~stamps:[ "money" ]
    ([ ("date", date); ("payee", payee) ]
    @ List.map (fun p -> ("posting", p)) postings)
    ""

let items =
  [ money "money:1" "2026-10-01" "Acme"
      [ "Assets:Checking  2,000.00"; "Income:Salary" ];
    money "money:2" "2026-10-05" "EDF"
      [ "Expenses:Utilities  62.40"; "Assets:Checking" ];
    money "money:3" "2026-10-09" "Safeway"
      [ "Expenses:Groceries  42.17"; "Assets:Checking" ];
    money "money:4" "2026-10-12" "savings"
      [ "Assets:Savings  500.00"; "Assets:Checking" ];
    (* a bill not paid yet: not in the books *)
    Item.make ~id:"task:rent" ~stamps:[ "task"; "money" ]
      [ ("title", "rent"); ("due", "2026-11-01");
        ("posting", "Expenses:Rent  900.00"); ("posting", "Assets:Checking") ]
      "" ]

let lines account =
  List.map
    (fun ((_ : Item.t), (t : Ledger.txn)) ->
      Printf.sprintf "%s %s %s %s" (Civil.to_string t.date) t.payee t.category
        (Money.to_string t.amount))
    (Books.register items account)

let check = Alcotest.(check string)

let tests =
  [
    Testo.create "the register, read from postings" (fun () ->
        Alcotest.(check (list string)) "Checking's lines, each its category"
          [ "2026-10-01 Acme Salary 2,000.00";
            "2026-10-05 EDF Utilities -62.40";
            "2026-10-09 Safeway Groceries -42.17";
            "2026-10-12 savings [Assets:Savings] -500.00" ]
          (lines "Assets:Checking");
        check "its balance" "1,395.43"
          (Money.to_string (Books.balance items "Assets:Checking"));
        check "a transfer's other side" "500.00"
          (Money.to_string (Books.balance items "Assets:Savings"));
        Alcotest.(check (list string)) "the accounts"
          [ "Assets:Checking"; "Assets:Savings"; "Expenses:Groceries";
            "Expenses:Utilities"; "Income:Salary" ]
          (Books.accounts items));
    Testo.create "a register's line, an item and back" (fun () ->
        let t : Ledger.txn =
          { date = d 20; num = "102"; payee = "Safeway"; category = "Groceries";
            memo = ""; amount = -1999; status = Cleared }
        in
        let i = Books.of_txn ~id:"money:5" ~account:"Assets:Checking" t in
        check "its postings" "Expenses:Groceries  19.99|Assets:Checking"
          (String.concat "|" (Mail.get_all i "posting"));
        check "cleared" "*" (Item.field i "cleared");
        match Books.register [ i ] "Assets:Checking" with
        | [ (_, back) ] -> Alcotest.(check bool) "the same line" true (back = t)
        | _ -> Alcotest.fail "one line");
    Testo.create "a bill, in the books once done" (fun () ->
        let paid =
          List.map
            (fun i ->
              if Item.id i = "task:rent" then Mail.set "done" "2026-10-30" i
              else i)
            items
        in
        check "before" "1,395.43"
          (Money.to_string (Books.balance items "Assets:Checking"));
        check "after: on the day it was done" "495.43"
          (Money.to_string (Books.balance paid "Assets:Checking")));
    Testo.create "a bank's file matched to the register" (fun () ->
        let register = List.map snd (Books.register items "Assets:Checking") in
        let line day payee amount : Ledger.txn =
          { date = d day; num = ""; payee; category = ""; memo = ""; amount;
            status = Open }
        in
        let file =
          [ line 6 "EDF SA" (-6240); (* the bank's day after ours *)
            line 9 "SAFEWAY 123" (-4217); line 21 "SHELL" (-5500) ]
        in
        Alcotest.(check (list string)) "only the new"
          [ "SHELL" ]
          (List.map (fun (t : Ledger.txn) -> t.payee) (Books.fresh register file)));
    Testo.create "a month's report" (fun () ->
        Alcotest.(check (list (pair string string))) "expenses and income"
          [ ("Expenses:Groceries", "42.17"); ("Expenses:Utilities", "62.40");
            ("Income:Salary", "-2,000.00") ]
          (List.map
             (fun (a, c) -> (a, Money.to_string c))
             (Books.report items ~year:2026 ~month:10)));
  ]
