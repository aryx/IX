(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's mini-chrome's tests/network/Unit_cookie.ml; ~script and ~at said (docs/plans/plan_browser.md) *)

(* See Unit_cookie.mli *)

let url (s : string) : Url.t = match Url.parse s with Ok u -> u | Error e -> Alcotest.fail e

(* 9 June 2021, 10:18:14 GMT *)
let then_ = 1623233894.
let now = then_ -. 86400.
let set_as ~(script : bool) from value jar = Cookie.store ~now ~script (url from) value jar
let set from value jar = set_as ~script:false from value jar
let said_as ~(script : bool) ~(at : float) to_ jar = Cookie.header ~now:at ~script (url to_) jar
let said to_ jar = said_as ~script:false ~at:now to_ jar
let header = Alcotest.(option string)

let tests =
  Testo.categorize "Cookie"
    [
      Testo.create "the worked example: a session and a language, said back" (fun () ->
          let jar =
            [] |> set "https://www.example.com/login" "SID=31d4d96e407aad42; Path=/; Secure; HttpOnly"
            |> set "https://www.example.com/login" "lang=en-US; Path=/; Domain=example.com"
          in
          Alcotest.check header "both, the older first" (Some "SID=31d4d96e407aad42; lang=en-US") (said "https://www.example.com/inbox" jar);
          Alcotest.check header "another host of the domain: the language only (the session is its host's)" (Some "lang=en-US") (said "https://mail.example.com/" jar);
          Alcotest.check header "over http://: not the Secure one" (Some "lang=en-US") (said "http://www.example.com/inbox" jar);
          Alcotest.check header "the page's script: not the HttpOnly one" (Some "lang=en-US") (said_as ~script:true ~at:now "https://www.example.com/inbox" jar);
          Alcotest.check header "another site: none" None (said "https://example.org/" jar);
          Alcotest.check header "a name that ends the same is not under it" None (said "https://badexample.com/" jar));
      Testo.create "Path: the directory of the page by default; under it, not beside it" (fun () ->
          let jar = [] |> set "http://x.org/docs/web/page.html" "a=1" |> set "http://x.org/docs/web/page.html" "b=2; Path=/docs" |> set "http://x.org/" "c=3" in
          Alcotest.check header "the longest path first" (Some "a=1; b=2; c=3") (said "http://x.org/docs/web/other.html" jar);
          Alcotest.check header "above /docs/web" (Some "b=2; c=3") (said "http://x.org/docs/index.html" jar);
          Alcotest.check header "/docsweb is not under /docs" (Some "c=3") (said "http://x.org/docsweb" jar));
      Testo.create "a date read, as servers write them" (fun () ->
          let d = Alcotest.(option (float 0.5)) in
          Alcotest.check d "RFC 1123's" (Some then_) (Cookie.date "Wed, 09 Jun 2021 10:18:14 GMT");
          Alcotest.check d "RFC 850's, a year of two digits" (Some then_) (Cookie.date "Wednesday, 09-Jun-21 10:18:14 GMT");
          Alcotest.check d "asctime's" (Some then_) (Cookie.date "Wed Jun  9 10:18:14 2021");
          Alcotest.check d "the first second" (Some 0.) (Cookie.date "Thu, 01 Jan 1970 00:00:00 GMT");
          Alcotest.check d "a leap day" (Some 951782400.) (Cookie.date "29 Feb 2000 00:00:00");
          Alcotest.check d "no time: not a date" None (Cookie.date "9 Jun 2021"));
      Testo.create "until when: Expires, Max-Age (which wins), a session's" (fun () ->
          let jar =
            [] |> set "http://x.org/" "e=1; Expires=Wed, 09 Jun 2021 10:18:14 GMT" |> set "http://x.org/" "m=2; Max-Age=60; Expires=Wed, 09 Jun 2021 10:18:14 GMT"
            |> set "http://x.org/" "s=3"
          in
          Alcotest.check header "all three now" (Some "e=1; m=2; s=3") (said "http://x.org/" jar);
          Alcotest.check header "two minutes later: Max-Age's is gone" (Some "e=1; s=3") (said_as ~script:false ~at:(now +. 120.) "http://x.org/" jar);
          Alcotest.check header "two days later: the session's only" (Some "s=3") (said_as ~script:false ~at:(now +. 172800.) "http://x.org/" jar);
          Alcotest.(check int) "and the jar forgets the dead" 1 (List.length (Cookie.alive ~now:(now +. 172800.) jar)));
      Testo.create "replaced by its name, domain and path; deleted by a date in the past" (fun () ->
          let jar = [] |> set "http://x.org/" "a=1" |> set "http://x.org/" "b=2" |> set "http://x.org/" "a=changed" in
          Alcotest.check header "its place kept" (Some "a=changed; b=2") (said "http://x.org/" jar);
          let jar = set "http://x.org/" "a=; Expires=Thu, 01 Jan 1970 00:00:00 GMT" jar in
          Alcotest.check header "deleted" (Some "b=2") (said "http://x.org/" jar);
          let jar = set "http://x.org/" "b=; Max-Age=0" jar in
          Alcotest.(check int) "the jar empty" 0 (List.length jar));
      Testo.create "refused: for another site, for every site, Secure over http://, no name" (fun () ->
          let refused from value = Alcotest.(check bool) value true (Cookie.parse ~now (url from) value = None) in
          refused "http://www.example.com/" "a=1; Domain=example.org";
          refused "http://www.example.com/" "a=1; Domain=com";
          refused "http://www.example.com/" "a=1; Domain=mail.example.com";
          refused "http://www.example.com/" "a=1; Secure";
          refused "http://www.example.com/" "=1";
          refused "http://www.example.com/" "novalue";
          (* a Domain said with its dot, and one that is the host itself *)
          let kept from value = match Cookie.parse ~now (url from) value with Some c -> (c.domain, c.host_only) | None -> Alcotest.fail value in
          Alcotest.(check (pair string bool)) ".example.com" ("example.com", false) (kept "http://www.example.com/" "a=1; Domain=.Example.COM");
          Alcotest.(check (pair string bool)) "no Domain: the host's" ("www.example.com", true) (kept "http://www.example.com/" "a=1");
          Alcotest.(check (pair string bool)) "localhost, said: its own" ("localhost", true) (kept "http://localhost:8000/" "a=1; Domain=localhost");
          Alcotest.(check (pair string bool)) "an address has nothing above it" ("127.0.0.1", true) (kept "http://127.0.0.1:8000/" "a=1"));
      Testo.create "the page's script: no HttpOnly cookie set, none replaced" (fun () ->
          let jar = [] |> set "http://x.org/" "sid=secret; HttpOnly" |> set_as ~script:true "http://x.org/" "sid=stolen" |> set_as ~script:true "http://x.org/" "h=1; HttpOnly" |> set_as ~script:true "http://x.org/" "theme=dark" in
          Alcotest.check header "the server sees its own, and the script's" (Some "sid=secret; theme=dark") (said "http://x.org/" jar);
          Alcotest.check header "the script sees its own" (Some "theme=dark") (said_as ~script:true ~at:now "http://x.org/" jar));
    ]
