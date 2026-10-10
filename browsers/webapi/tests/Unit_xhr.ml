(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* ix: the author's mini-chrome's tests/browser/Unit_xhr.ml (its 8af888e) (docs/plans/plan_browser.md) *)

(* See Unit_xhr.mli *)

(* a page at http://site.test/app/ whose script is [script] *)
let page (script : string) : Browser_script.t =
  let t = Browser_script.create_with { Browser_script.defaults with base = "http://site.test/app/" } (Html_tree.of_string ("<body><p id=out></p><script>var seen = [];\n" ^ script ^ "</script></body>")) in
  Browser_script.run_scripts t;
  t

let value (t : Browser_script.t) (s : string) : string = match Browser_script.eval t s with Ok v -> Js_value.display v | Error e -> "error: " ^ e.message

(* the requests the script made, as "GET url" or "POST url type body" *)
let requests (t : Browser_script.t) : string list * int list =
  let rs = Browser_script.take_requests t in
  ( List.map (fun (r : Script_types.request) -> match r.post with Some (ct, body) -> Printf.sprintf "%s %s %s %s" r.meth r.url ct body | None -> r.meth ^ " " ^ r.url) rs,
    List.map (fun (r : Script_types.request) -> r.rid) rs )

let ok ?(status = 200) ?(headers = [ ("Content-Type", "application/json") ]) ?(final = "http://site.test/app/items.json") (body : string) :
    (Script_types.answer, string) result =
  Ok { status; headers; body; final }

let tests =
  Testo.categorize "XMLHttpRequest and fetch"
    [
      Testo.create "XMLHttpRequest: the worked example" (fun () ->
          let t =
            page
              {|const x = new XMLHttpRequest();
                x.onreadystatechange = () => seen.push("state " + x.readyState);
                x.open("GET", "items.json");
                x.onload = () => { if (x.status === 200) seen.push("load " + JSON.parse(x.responseText).length) };
                x.addEventListener("loadend", e => seen.push("loadend " + (e.target === x)));
                x.send(); seen.push("the script goes on")|}
          in
          let urls, rids = requests t in
          Alcotest.(check (list string)) "queued for the browser, its URL resolved" [ "GET http://site.test/app/items.json" ] urls;
          Alcotest.(check string) "nothing yet" {|["state 1", "the script goes on"]|} (value t "seen");
          Browser_script.answer t (List.hd rids) (ok {|[1, 2, 3]|});
          Alcotest.(check string) "the answer: its states and events in order" {|["state 1", "the script goes on", "state 4", "load 3", "loadend true"]|} (value t "seen");
          Alcotest.(check string) "what it holds once done" {|[4, 200, "OK", "application/json", null, "content-type: application/json\r\n", "http://site.test/app/items.json", true]|}
            (value t {|[x.readyState, x.status, x.statusText, x.getResponseHeader("content-type"), x.getResponseHeader("nope"), x.getAllResponseHeaders(), x.responseURL, x instanceof XMLHttpRequest]|});
          Browser_script.answer t (List.hd rids) (ok "again");
          Alcotest.(check string) "an answer is given once" "5" (value t "seen.length"));
      Testo.create "XMLHttpRequest: a POST, a 404, no answer, json, abort" (fun () ->
          let t =
            page
              {|function ask(method, url, body, type) {
                  const x = new XMLHttpRequest(); x.open(method, url);
                  if (type) x.responseType = type;
                  if (body) x.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
                  x.onload = () => seen.push([url, "load", x.status, x.response]); x.onerror = () => seen.push([url, "error", x.status]);
                  x.send(body); return x }
                ask("POST", "/vote", "id=7&how=up"); ask("GET", "gone"); ask("GET", "down"); ask("GET", "data", null, "json"); ask("GET", "never").abort()|}
          in
          let urls, rids = requests t in
          Alcotest.(check (list string)) "the requests, a POST's type and body"
            [ "POST http://site.test/vote application/x-www-form-urlencoded id=7&how=up"; "GET http://site.test/app/gone"; "GET http://site.test/app/down"; "GET http://site.test/app/data"; "GET http://site.test/app/never" ] urls;
          (match rids with
          | [ vote; gone; down; data; never ] ->
              Browser_script.answer t vote (ok ~final:"http://site.test/vote" "voted");
              Browser_script.answer t gone (ok ~status:404 "no such page");
              Browser_script.answer t down (Error "network error");
              Browser_script.answer t data (ok {|{"n": 5}|});
              Browser_script.answer t never (ok "too late")
          | _ -> Alcotest.fail "five requests");
          Alcotest.(check string) "a 404 is an answer (load); no answer is an error; json parsed; an aborted one says nothing"
            {|[["/vote", "load", 200, "voted"], ["gone", "load", 404, "no such page"], ["down", "error", 0], ["data", "load", 200, {n: 5}]]|} (value t "seen"));
      Testo.create "fetch: a promise of the response" (fun () ->
          let t =
            page
              {|async function load() {
                  const r = await fetch("items.json");
                  seen.push([r.ok, r.status, r.headers.get("content-type")]);
                  seen.push([r.headers.entries().next().value.join(": "), [...r.headers.keys()].length == [...r.headers].length, typeof r.headers.values]);
                  const items = await r.json();
                  document.getElementById("out").textContent = items.join(" ");
                  return items.length }
                load().then(n => seen.push("done " + n)); seen.push("the script goes on")|}
          in
          let urls, rids = requests t in
          Alcotest.(check (list string)) "queued" [ "GET http://site.test/app/items.json" ] urls;
          Alcotest.(check bool) "the page not changed yet" false (Browser_script.changed t);
          Browser_script.answer t (List.hd rids) (ok {|["a", "b"]|});
          Alcotest.(check string) "the function went on from its await, to its end" {|["the script goes on", [true, 200, "application/json"], ["content-type: application/json", true, "function"], "done 2"]|} (value t "seen");
          Alcotest.(check (pair bool string)) "and changed the page: to be laid out again" (true, "a b") (Browser_script.changed t, value t {|document.getElementById("out").textContent|}));
      Testo.create "a script's request headers: its own, not the browser's" (fun () ->
          let t =
            page
              {|fetch("a.json", { headers: { Accept: "application/json", Cookie: "stolen=1" } });
                fetch(new Request("b.json", { headers: new Headers({ "X-Requested-With": "XMLHttpRequest" }) }));
                const x = new XMLHttpRequest(); x.open("GET", "c.json"); x.setRequestHeader("Accept", "text/plain"); x.send();
                fetch("http://other.test/d.json", { headers: { Accept: "*/*" } });|}
          in
          Alcotest.(check (list (list (pair string string))))
            "an object's, a Request's Headers, setRequestHeader's; Origin first to another site"
            [ [ ("Accept", "application/json") ]; [ ("x-requested-with", "XMLHttpRequest") ]; [ ("Accept", "text/plain") ]; [ ("Origin", "http://site.test"); ("Accept", "*/*") ] ]
            (List.map (fun (r : Script_types.request) -> r.said) (Browser_script.take_requests t)));
      Testo.create "a body of bytes is sent as bytes" (fun () ->
          let t = page {|fetch("log", { method: "POST", headers: { "Content-Encoding": "gzip", "Content-Type": "application/json" }, body: new Uint8Array([31, 139, 8, 0]) });
                         const x = new XMLHttpRequest(); x.open("POST", "log2"); x.send(new Uint8Array([104, 105]).buffer);|} in
          Alcotest.(check (list string)) "a Uint8Array to fetch, a buffer to XMLHttpRequest"
            [ "POST http://site.test/app/log application/json \031\139\008\000"; "POST http://site.test/app/log2 text/plain;charset=UTF-8 hi" ]
            (fst (requests t)));
      Testo.create "fetch: a POST, a 404, no answer, a method not sent" (fun () ->
          let t =
            page
              {|fetch("/api", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ a: 1 }) }).then(r => r.text()).then(text => seen.push(text));
                fetch("gone").then(r => seen.push([r.ok, r.status, r.statusText]));
                fetch("down").then(() => seen.push("never"), e => seen.push(e.name + ": " + e.message));
                fetch("/x", { method: "DELETE" }).catch(e => seen.push("delete " + e.name));
                fetch("bad.json").then(r => r.json()).catch(e => seen.push("json " + e.name))|}
          in
          let urls, rids = requests t in
          Alcotest.(check (list string)) "the requests (the DELETE is not sent)"
            [ {|POST http://site.test/api application/json {"a":1}|}; "GET http://site.test/app/gone"; "GET http://site.test/app/down"; "GET http://site.test/app/bad.json" ] urls;
          Alcotest.(check string) "refused at once" {|["delete TypeError"]|} (value t "seen");
          (match rids with
          | [ api; gone; down; bad ] ->
              Browser_script.answer t api (ok ~final:"http://site.test/api" "posted");
              Browser_script.answer t gone (ok ~status:404 "");
              Browser_script.answer t down (Error "timeout");
              Browser_script.answer t bad (ok "{not json")
          | _ -> Alcotest.fail "four requests");
          Alcotest.(check string) "a 404 fulfils (ok false); no answer rejects; a body that is not JSON rejects json()"
            {|["delete TypeError", "posted", [false, 404, "Not Found"], "TypeError: Failed to fetch", "json SyntaxError"]|} (value t "seen"));
      Testo.create "who may read what: the same origin, or an answer that allows it" (fun () ->
          let t =
            page
              {|for (const url of ["http://site.test/mine", "http://other.test/private", "http://other.test/open", "http://other.test/for-us", "http://other.test/for-them", "https://site.test/mine"])
                  fetch(url).then(r => r.text()).then(text => seen.push(text), () => seen.push("blocked"))|}
          in
          let _, rids = requests t in
          let cors origin = [ ("Access-Control-Allow-Origin", origin) ] in
          List.iteri
            (fun i (final, headers, body) -> Browser_script.answer t (List.nth rids i) (ok ~final ~headers body))
            [ ("http://site.test/mine", [], "mine");
              ("http://other.test/private", [], "the reader's account");
              ("http://other.test/open", cors "*", "open to all");
              ("http://other.test/for-us", cors "http://site.test", "for this page");
              ("http://other.test/for-them", cors "http://third.test", "for another");
              ("https://site.test/mine", [], "another scheme is another origin") ];
          Alcotest.(check string) "the page's own; another's only when it says so" {|["mine", "blocked", "open to all", "for this page", "blocked", "blocked"]|} (value t "seen");
          Alcotest.(check bool) "and said on the console" true
            (List.exists (fun l -> String.starts_with ~prefix:"http://other.test/private has been blocked by CORS policy" l) (Browser_script.console t));
          Alcotest.(check (list string)) "an origin: the scheme, the host, the port" [ "https://example.com"; "http://localhost:8000"; "http://site.test" ]
            (List.map Cors.origin [ "https://example.com/a/b?q#h"; "http://localhost:8000/"; "http://site.test" ]));
    ]
