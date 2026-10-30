(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Unit_screen.mli *)

let message (from : string) (date : string) : Imap.summary =
  { uid = 1; flags = []; labels = []; thread = ""; msgid = "";
    headers = Mail.make [ ("From", from); ("Date", date) ] "" }

let today : Civil.date = { year = 2026; month = 10; day = 29 }
let new_ = "Thu, 29 Oct 2026 10:00:00 +0000"
let old = "Mon, 26 Oct 2026 10:00:00 +0000"

let show (p : Screen.place) : string =
  match p with
  | Imbox -> "imbox"
  | Screener -> "screener"
  | Feed -> "feed"
  | Paper -> "paper"
  | Out -> "out"

let tests =
  [
    Testo.create "where a conversation goes" (fun () ->
        let place items c = show (Screen.place items ~account:"erin@ix" c) in
        let check = Alcotest.(check string) in
        let c = [ message "Bob <bob@ix>" new_ ] in
        check "the Screener off: the Imbox" "imbox" (place [] c);
        let on = [ Screen.turn_on today ] in
        check "on: a new sender waits" "screener" (place on c);
        check "one who wrote before it was on" "imbox"
          (place on [ message "Bob <bob@ix>" new_; message "bob@ix" old ]);
        let alice =
          Item.make ~id:"contact:bob@ix" ~stamps:[ "contact" ]
            [ ("name", "Bob"); ("email", "bob@ix") ] ""
        in
        check "a contact" "imbox" (place (alice :: on) c);
        check "a decision" "feed"
          (place (Screen.decide "BOB@ix" Feed :: on) c);
        check "out" "out" (place (Screen.decide "bob@ix" Out :: on) c);
        check "the account's own, unanswered" "imbox"
          (place on [ message "Erin <erin@ix>" new_ ]);
        check "the newest not the account's decides" "screener"
          (place on [ message "erin@ix" new_; message "Bob <bob@ix>" new_ ]));
  ]
