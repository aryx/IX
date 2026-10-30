(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Unit_mailto.mli *)

let strs = Alcotest.(check (list string))
let str = Alcotest.(check string)

let tests =
  [
    Testo.create "mailto: addresses" (fun () ->
        match
          Mailto.parse
            "mailto:alice@ix,bob+news@ix?cc=carol@ix&to=dan@ix\
             &bcc=eve@ix&subject=lunch%3F%20tuesday\
             &body=See%20you%0D%0Aat%20noon."
        with
        | None -> Alcotest.fail "not read"
        | Some m ->
            strs "to, a plus kept, to= after" [ "alice@ix"; "bob+news@ix"; "dan@ix" ]
              m.to_;
            strs "cc" [ "carol@ix" ] m.cc;
            strs "bcc" [ "eve@ix" ] m.bcc;
            str "subject" "lunch? tuesday" m.subject;
            str "body, its lines" "See you\nat noon." m.body);
    Testo.create "mailto: the rest" (fun () ->
        (match Mailto.parse "MAILTO:%22Martin%2C%20A%22%20%3Ca@ix%3E" with
        | Some m -> strs "a %2C in a name" [ "\"Martin, A\" <a@ix>" ] m.to_
        | None -> Alcotest.fail "not read");
        (match Mailto.parse "mailto:?subject=hi" with
        | Some m ->
            strs "no address" [] m.to_;
            str "a subject alone" "hi" m.subject
        | None -> Alcotest.fail "not read");
        Alcotest.(check bool) "http is not mailto" true
          (Mailto.parse "http://ix/" = None));
  ]
