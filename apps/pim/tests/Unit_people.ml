(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Unit_people.mli *)

let message id from to_ date =
  Item.make ~id ~stamps:[ "message" ]
    [ ("from", from); ("to", to_); ("date", date) ]
    ""

let m1 =
  message "mail:1" "Alice <Alice@ix>" "erin@ix"
    "Mon, 26 Oct 2026 10:00:00 +0000"

let m2 =
  message "mail:2" "erin@ix" "bob@ix, alice@home.example"
    "Wed, 28 Oct 2026 10:00:00 +0000"

let m3 = message "mail:3" "bob@ix" "erin@ix" "Thu, 29 Oct 2026 10:00:00 +0000"
let check = Alcotest.(check (list string))

let tests =
  [
    Testo.create "a sender made a contact, and her mail" (fun () ->
        match People.of_sender m1 with
        | None -> Alcotest.fail "no contact"
        | Some c ->
            Alcotest.(check string) "its id" "contact:alice@ix" (Item.id c);
            Alcotest.(check string) "its name" "Alice" (Item.field c "name");
            let c =
              {
                c with
                fields =
                  c.fields @ [ { name = "email"; raw = " alice@home.example" } ];
              }
            in
            let items = [ m1; m2; m3; c ] in
            check "from her, to her other address; newest first"
              [ "mail:2"; "mail:1" ]
              (List.map Item.id (People.with_ items c));
            check "whose: any case" [ "contact:alice@ix" ]
              (List.filter_map
                 (fun a -> Option.map Item.id (People.who items a))
                 [ "ALICE@home.example"; "bob@ix" ]));
    Testo.create "the book, by name" (fun () ->
        let c name =
          Item.make ~id:("contact:" ^ name) ~stamps:[ "contact" ]
            [ ("name", name) ]
            ""
        in
        check "by name, any case"
          [ "contact:alice"; "contact:Bob"; "contact:carol" ]
          (List.map Item.id
             (People.contacts [ c "carol"; m1; c "Bob"; c "alice" ])));
  ]
