(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Unit_today.mli *)

let today : Civil.date = { year = 2026; month = 10; day = 29 }

let task id fields = Item.make ~id ~stamps:[ "task" ] fields ""

let tests =
  [
    Testo.create "someday, and a bill again" (fun () ->
        let items =
          [ task "task:a" [ ("title", "a"); ("due", "2026-10-29") ];
            task "task:b" [ ("title", "b"); ("someday", "yes") ];
            task "task:c" [ ("title", "c") ] ]
        in
        Alcotest.(check (list string)) "to do: not someday's"
          [ "task:a"; "task:c" ]
          (List.map Item.id (Today.to_do items today));
        let rent =
          task "task:rent"
            [ ("title", "rent"); ("due", "2026-11-05");
              ("repeat", "FREQ=MONTHLY;BYMONTHDAY=5"); ("done", "2026-11-04");
              ("posting", "Expenses:Rent  900.00");
              ("posting", "Assets:Checking") ]
        in
        match Today.again rent with
        | Some next -> (
            Alcotest.(check string) "its id" "task:rent.2026-12-05" (Item.id next);
            Alcotest.(check string) "due" "2026-12-05" (Item.field next "due");
            Alcotest.(check string) "not done" "" (Item.field next "done");
            Alcotest.(check int) "its postings" 2
              (List.length (Books.postings next));
            match Today.again next with
            | Some n ->
                Alcotest.(check string) "the next's next, its id"
                  "task:rent.2027-01-05" (Item.id n)
            | None -> Alcotest.fail "no next's next")
        | None -> Alcotest.fail "no next");
  ]
