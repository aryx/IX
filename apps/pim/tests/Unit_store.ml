(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Unit_store.mli *)

let alice =
  Item.make ~id:"contact:alice" ~stamps:[ "contact" ]
    [ ("name", "Alice"); ("email", "alice@ix") ]
    ""

let task =
  Item.make ~id:"task:answer" ~stamps:[ "task" ]
    [
      ("title", "answer Alice");
      ("due", "2026-11-05");
      ("with", "contact:alice");
      ("re", "mail:7, mail:8");
    ]
    ""

let mail =
  Item.make ~id:"mail:7" ~stamps:[ "message"; "task" ]
    [
      ("from", "Carol <carol@ix>");
      ("subject", "the plan");
      ("date", "Thu, 29 Oct 2026 23:30:00 -0500");
      ("labels", "(\\Inbox travel)");
      ("flags", "()");
    ]
    ""

let note =
  Item.make ~id:"note:lunch" ~stamps:[ "note" ] []
    "Lunch with Alice at the usual place.\n"

let items = [ alice; task; mail; note ]
let ids (l : Item.t list) : string list = List.map Item.id l
let found q = ids (Search.search q items)
let check = Alcotest.(check (list string))

let tests =
  [
    Testo.create "search: words, fields, a phrase" (fun () ->
        check "a word anywhere, any case"
          [ "contact:alice"; "task:answer"; "note:lunch" ]
          (found "ALICE");
        check "two words, both" [ "note:lunch" ] (found "alice lunch");
        check "a phrase" [ "note:lunch" ] (found "\"the usual place\"");
        check "a field" [ "mail:7" ] (found "from:carol");
        check "an id, a word: the item, and who names it"
          [ "contact:alice"; "task:answer" ]
          (found "contact:alice"));
    Testo.create "search: stamps, labels, unread, not" (fun () ->
        check "is:task" [ "task:answer"; "mail:7" ] (found "is:task");
        check "not a message" [ "task:answer" ] (found "is:task -is:message");
        check "a label" [ "mail:7" ] (found "label:travel");
        check "label:inbox" [ "mail:7" ] (found "label:inbox");
        check "unread" [ "mail:7" ] (found "is:unread"));
    Testo.create "search: the day, before and after" (fun () ->
        check "due before"
          [ "task:answer"; "mail:7" ]
          (found "before:2026-11-06 is:task");
        check "on the day is after" [ "task:answer" ]
          (found "after:2026/11/05 is:task");
        (* (the message's day is where it was written: the 29th) *)
        check "a message's date" [ "mail:7" ]
          (found "before:2026-10-30 after:2026-10-29");
        check "no day, never" [] (found "before:2100-01-01 is:note"));
    Testo.create "links both ways" (fun () ->
        let pairs l = List.map (fun (f, i) -> (f, Item.id i)) l in
        let check = Alcotest.(check (list (pair string string))) in
        check "the task names two"
          [ ("with", "contact:alice"); ("re", "mail:7") ]
          (pairs (Links.links items task));
        check "alice is named by the task"
          [ ("with", "task:answer") ]
          (pairs (Links.backlinks items alice));
        check "the mail too"
          [ ("re", "task:answer") ]
          (pairs (Links.backlinks items mail));
        check "the note by none" [] (pairs (Links.backlinks items note)));
    Testo.create "links in a text, [[ ]]" (fun () ->
        let pairs l = List.map (fun (f, i) -> (f, Item.id i)) l in
        let check = Alcotest.(check (list (pair string string))) in
        let day =
          Item.make ~id:"day:2026-10-29" ~stamps:[ "note" ] []
            "lunch with [[contact:alice]], then [[ mail:7 ]];\n\
             [[nothing:here]] and [[not\nclosed]]"
        in
        let items = day :: items in
        check "its text's links, those that are items"
          [ ("text", "contact:alice"); ("text", "mail:7") ]
          (pairs (Links.links items day));
        check "alice: the task, and the day"
          [ ("text", "day:2026-10-29"); ("with", "task:answer") ]
          (pairs (Links.backlinks items alice)));
  ]
