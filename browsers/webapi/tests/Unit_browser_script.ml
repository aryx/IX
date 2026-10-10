(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* ix: the author's mini-chrome's tests/browser/Unit_browser_script.ml (its 8af888e) (docs/plans/plan_browser.md) *)

(* See Unit_browser_script.mli *)

(* a page's scripts run *)
let page (html : string) : Browser_script.t =
  let t = Browser_script.create (Html_tree.of_string html) in
  Browser_script.run_scripts t;
  t

(* the frozen body, blank text and scripts left out, as indented lines *)
let body (t : Browser_script.t) : string list =
  let root = Dom.without_blank_text (Browser_script.tree t) in
  match Dom.find_all "body" root with
  | [ b ] ->
      List.concat_map
        (fun (n : Dom.node) ->
          match n with
          | Element e when e.name = "script" -> []
          | Element e -> Dom.to_lines e
          | Text s -> [ Printf.sprintf "%S" s ])
        b.children
  | _ -> Alcotest.fail "no body"

(* a script's value, as the console shows it *)
let value (t : Browser_script.t) (s : string) : string =
  match Browser_script.eval t s with Ok v -> Js_value.display v | Error e -> "error: " ^ e.message

let check_body what t expected = Alcotest.(check (list string)) what expected (body t)

(* the element of id [id] in the frozen tree: what a click is given *)
let element (t : Browser_script.t) (id : string) : Dom.element =
  let rec find (e : Dom.element) : Dom.element option =
    if Dom.attribute "id" e = Some id then Some e
    else List.find_map (fun (n : Dom.node) -> match n with Element c -> find c | Text _ -> None) e.children
  in
  match find (Browser_script.tree t) with Some e -> e | None -> Alcotest.fail ("no element " ^ id)

let tests =
  Testo.categorize "Browser_script"
    [
      Testo.create "the worked example: a text changed" (fun () ->
          let t = Browser_script.create (Html_tree.of_string "<p id=x>a</p><script>document.getElementById(\"x\").textContent = \"b\"</script>") in
          Alcotest.(check bool) "not changed before the scripts" false (Browser_script.changed t);
          Browser_script.run_scripts t;
          Alcotest.(check bool) "changed after" true (Browser_script.changed t);
          check_body "the text" t [ "p id=\"x\""; "  \"b\"" ];
          Alcotest.(check bool) "frozen: not changed any more" false (Browser_script.changed t));
      Testo.create "a listener that is an object: its handleEvent" (fun () ->
          (* a framework's one object hearing every event, the method its class's *)
          let t =
            page
              "<p id=p>x</p><script>function L() { this.heard = [] }\nL.prototype.handleEvent = function (e) { this.heard.push(e.type + ' ' + e.target.id) };\nvar l = new L(); document.addEventListener('click', l, false);</script>"
          in
          ignore (Browser_script.click t (element t "p"));
          Alcotest.(check string) "called, the object for this" "[\"click p\"]" (value t "l.heard"));
      Testo.create "history.pushState: the page's address, no page loaded" (fun () ->
          let t = Browser_script.create_with { Browser_script.defaults with base = "http://site.test/groups/a" } (Html_tree.of_string "<p>x</p>") in
          Browser_script.run_scripts t;
          Alcotest.(check string) "before" "/groups/a" (value t "location.pathname");
          ignore (value t "history.pushState({ n: 1 }, '', '/latest?x=1')");
          Alcotest.(check string) "location follows" "http://site.test/latest?x=1 /latest 1" (value t "location.href + ' ' + location.pathname + ' ' + history.state.n");
          Alcotest.(check (list (pair string bool))) "the browser told, once" [ ("http://site.test/latest?x=1", false) ] (Browser_script.take_address t);
          Alcotest.(check (list (pair string bool))) "then nothing" [] (Browser_script.take_address t);
          ignore (value t "history.replaceState(null, '', '/b'); history.pushState(null, '', '/c')");
          Alcotest.(check (list (pair string bool))) "each one, in order" [ ("http://site.test/b", true); ("http://site.test/c", false) ] (Browser_script.take_address t);
          (* Back to a state of the same document: the address, and popstate *)
          ignore (value t "var popped = []; window.addEventListener('popstate', function () { popped.push(location.pathname) })");
          Browser_script.popstate t "http://site.test/b";
          Alcotest.(check string) "the script told" "[\"/b\"]" (value t "popped"));
      Testo.create "where an element is: asked of the browser, once between two changes" (fun () ->
          let t = page "<div id=a>x</div><div id=b>y</div>" in
          let asked = ref 0 in
          (* a browser that stacks the page's elements, each 10 high, 100 wide *)
          Browser_script.set_measure t (fun tree ->
              incr asked;
              let divs = Dom.find_all "div" tree in
              fun e -> List.find_map (fun (i, d) -> if d == e then Some (0., 10. *. float_of_int i, 100., 10.) else None) (List.mapi (fun i d -> (i, d)) divs));
          Alcotest.(check string) "sizes and places" "[10, 100, 10, 20]"
            (value t "var b = document.getElementById('b'), r = b.getBoundingClientRect(); [b.offsetHeight, b.offsetWidth, r.top, r.bottom]");
          Alcotest.(check int) "one layout for the four" 1 !asked;
          Alcotest.(check string) "after a change, again" "20"
            (value t "var d = document.createElement('div'); document.body.insertBefore(d, document.getElementById('a')); document.getElementById('b').offsetTop");
          Alcotest.(check int) "a second layout" 2 !asked);
      Testo.create "a value shown: five deep, no further" (fun () ->
          let t = page "<script>var o = { a: { b: { c: { d: { e: { f: 1 } } } } } }</script>" in
          Alcotest.(check string) "cut" "{a: {b: {c: {d: {e: ...}}}}}" (value t "o"));
      Testo.create "the worked example: a hundred items, one task" (fun () ->
          let t =
            page
              "<ul id=list></ul><script>\nconst list = document.getElementById(\"list\");\nfor (let i = 0; i < 100; i++) {\n  const li = document.createElement(\"li\");\n  li.textContent = \"item \" + i;\n  list.appendChild(li);\n}\n</script>"
          in
          Alcotest.(check int) "100 li" 100 (List.length (Dom.find_all "li" (Browser_script.tree t)));
          Alcotest.(check string) "the last" "item 99" (value t "document.querySelector(\"ul\").lastChild.textContent"));
      Testo.create "innerHTML, written and read" (fun () ->
          let t = page "<p id=x>a</p>" in
          ignore (value t "document.getElementById(\"x\").innerHTML = \"<b>3</b> & more\"");
          check_body "parsed" t [ "p id=\"x\""; "  b"; "    \"3\""; "  \" & more\"" ];
          Alcotest.(check string) "read back, escaped" "<b>3</b> &amp; more" (value t "document.getElementById(\"x\").innerHTML"));
      Testo.create "selectors: Css's, descendants and classes" (fun () ->
          let t = page "<ul><li class=done>a<li>b</ul><ol><li class=done>c</ol>" in
          Alcotest.(check string) "ul li.done: one" "1" (value t "document.querySelectorAll(\"ul li.done\").length");
          Alcotest.(check string) ".done: the first" "a" (value t "document.querySelector(\".done\").textContent");
          Alcotest.(check string) "within an element" "c" (value t "document.querySelector(\"ol\").querySelector(\"li\").textContent");
          Alcotest.(check string) "none" "null" (value t "document.querySelector(\"table\")"));
      Testo.create "style and class" (fun () ->
          let t = page "<p id=x>a</p>" in
          ignore (value t "const p = document.getElementById(\"x\"); p.style.color = \"red\"; p.style.backgroundColor = \"blue\"; p.className = \"done\"");
          check_body "the attributes" t [ "p id=\"x\" style=\"color: red; background-color: blue\" class=\"done\""; "  \"a\"" ];
          Alcotest.(check string) "read back" "blue" (value t "p.style.backgroundColor"));
      Testo.create "an element, one host object" (fun () ->
          let t = page "<p id=x>a</p>" in
          Alcotest.(check string) "===" "true" (value t "document.getElementById(\"x\") === document.getElementById(\"x\")");
          Alcotest.(check string) "an expando kept" "true" (value t "document.getElementById(\"x\").seen = true; document.body.firstElementChild.seen"));
      Testo.create "the tree edited" (fun () ->
          let t = page "<ul id=a><li>1<li>2</ul><ul id=b></ul>" in
          ignore (value t "const a = document.getElementById(\"a\"), b = document.getElementById(\"b\"); b.appendChild(a.firstChild)");
          check_body "moved" t [ "ul id=\"a\""; "  li"; "    \"2\""; "ul id=\"b\""; "  li"; "    \"1\"" ];
          ignore (value t "const li = document.createElement(\"li\"); li.textContent = \"0\"; b.insertBefore(li, b.firstChild); a.removeChild(a.firstChild)");
          check_body "inserted, removed" t [ "ul id=\"a\""; "ul id=\"b\""; "  li"; "    \"0\""; "  li"; "    \"1\"" ];
          Alcotest.(check string) "never inside itself" "error: HierarchyRequestError: The new child element contains the parent."
            (value t "b.firstChild.appendChild(b)"));
      Testo.create "the title" (fun () ->
          let t = page "<title>A</title><p>x" in
          ignore (value t "document.title = document.title + \"B\"");
          Alcotest.(check string) "AB" "AB" (Dom.text_content (List.hd (Dom.find_all "title" (Browser_script.tree t)))));
      Testo.create "Netscape's attributes kept through the copy" (fun () ->
          let t = page "<body bgcolor=white><center>x</center>" in
          let root = Browser_script.tree t in
          let b = List.hd (Dom.find_all "body" root) and c = List.hd (Dom.find_all "center" root) in
          Alcotest.(check (option string)) "bgcolor still an extension" (Some "white") (Dom.attribute_any "bgcolor" b);
          Alcotest.(check (option string)) "not a core attribute" None (Dom.attribute "bgcolor" b);
          Alcotest.(check bool) "center still Netscape's" true (c.origin = Dtd.Netscape));
      Testo.create "events: a click bubbles" (fun () ->
          let t =
            page
              "<ul id=l><li id=a>x</ul><script>const log = [];\ndocument.getElementById(\"l\").addEventListener(\"click\", e => log.push(\"ul:\" + e.target.id));\ndocument.getElementById(\"a\").onclick = () => log.push(\"li\");\ndocument.addEventListener(\"click\", () => log.push(\"document\"))</script>"
          in
          Alcotest.(check bool) "not prevented" false (Browser_script.click t (element t "a"));
          Alcotest.(check string) "the li's, the ul's, the document's" "[\"li\", \"ul:a\", \"document\"]" (value t "log"));
      Testo.create "events: stopped, prevented, onclick=\"...\"" (fun () ->
          let t =
            page
              "<p id=p><a id=k href=next.html onclick=\"this.textContent = 'clicked'; return false\">go</a></p><script>let seen = false;\ndocument.getElementById(\"p\").addEventListener(\"click\", () => { seen = true })</script>"
          in
          Alcotest.(check bool) "return false: prevented" true (Browser_script.click t (element t "k"));
          check_body "this is the element" t [ "p id=\"p\""; "  a id=\"k\" href=\"next.html\" onclick=\"this.textContent = 'clicked'; return false\""; "    \"clicked\"" ];
          Alcotest.(check string) "and it still bubbled" "true" (value t "seen");
          ignore (value t "document.getElementById(\"k\").onclick = e => { e.stopPropagation(); e.preventDefault() }; seen = false");
          Alcotest.(check bool) "preventDefault" true (Browser_script.click t (element t "k"));
          Alcotest.(check string) "stopped: the p not told" "false" (value t "seen"));
      Testo.create "events: one handler for a whole table (delegation)" (fun () ->
          let t =
            page
              "<table id=board><tr><td id=c0>.</td><td id=c1>.</td></tr></table><script>document.getElementById(\"board\").addEventListener(\"click\", e => { e.target.textContent = \"X\" })</script>"
          in
          ignore (Browser_script.click t (element t "c1"));
          Alcotest.(check string) "the cell clicked" "[\".\", \"X\"]" (value t "[0, 1].map(i => document.getElementById(\"c\" + i).textContent)"));
      Testo.create "events: keys, and a field typed into" (fun () ->
          let t =
            page
              "<input id=f><script>let last = \"\", typed = \"\";\ndocument.addEventListener(\"keydown\", e => { last = e.key });\ndocument.getElementById(\"f\").addEventListener(\"input\", e => { typed = e.target.value })</script>"
          in
          ignore (Browser_script.key t "ArrowUp");
          Browser_script.input t (element t "f") "hello";
          Alcotest.(check string) "the key, the text" "[\"ArrowUp\", \"hello\"]" (value t "[last, typed]"));
      Testo.create "timers on the page's clock" (fun () ->
          let t = page "<script>let a = 0, b = 0;\nsetTimeout(() => { a = 1 }, 100);\nconst i = setInterval(() => { b++ }, 100)</script>" in
          Browser_script.advance t 50.;
          Alcotest.(check string) "50 ms: nothing yet" "[0, 0]" (value t "[a, b]");
          Browser_script.advance t 300.;
          Alcotest.(check string) "350 ms: the timeout once, the interval 3 times" "[1, 3]" (value t "[a, b]");
          ignore (value t "clearInterval(i)");
          Browser_script.advance t 1000.;
          Alcotest.(check string) "cleared" "[1, 3]" (value t "[a, b]"));
      Testo.create "promises: a timer awaited" (fun () ->
          let t =
            page
              "<p id=out></p><script>const sleep = ms => new Promise(done => setTimeout(done, ms));\nlet said = [];\nasync function steps() { said.push(\"start\"); await sleep(100); said.push(\"100\"); await sleep(100); said.push(\"200\"); document.getElementById(\"out\").textContent = said.join(\" \") }\nsteps().then(() => said.push(\"done\"))</script>"
          in
          Alcotest.(check string) "up to its first await" "[\"start\"]" (value t "said");
          Browser_script.advance t 150.;
          Alcotest.(check string) "the timer's function resolved it: the function goes on" "[\"start\", \"100\"]" (value t "said");
          Browser_script.advance t 100.;
          Alcotest.(check string) "to its end, and its promise's then" "[\"start\", \"100\", \"200\", \"done\"]" (value t "said");
          Alcotest.(check string) "the page changed from it" "start 100 200" (value t "document.getElementById(\"out\").textContent"));
      Testo.create "alert, and DOMContentLoaded" (fun () ->
          let t = page "<script>document.addEventListener(\"DOMContentLoaded\", () => alert(\"ready\"));\nalert(\"first\")</script>" in
          Alcotest.(check (list string)) "queued in order" [ "first"; "ready" ] (Browser_script.take_alerts t);
          Alcotest.(check (list string)) "taken" [] (Browser_script.take_alerts t));
      Testo.create "document.readyState: loading, interactive, complete" (fun () ->
          let t =
            page
              "<script>var said = [document.readyState];\n\
               document.addEventListener(\"readystatechange\", () => said.push(\"change \" + document.readyState));\n\
               document.addEventListener(\"DOMContentLoaded\", () => said.push(\"DOMContentLoaded \" + document.readyState));\n\
               window.addEventListener(\"load\", () => said.push(\"load \" + document.readyState))</script>"
          in
          Alcotest.(check string) "a script being read is told loading: what it waits for is yet to come"
            "[\"loading\", \"change interactive\", \"DOMContentLoaded interactive\", \"change complete\", \"load complete\"]" (value t "said"));
      Testo.create "an iframe's window: an empty page's" (fun () ->
          let t =
            page
              "<body><script>var f = document.createElement(\"iframe\"); document.body.appendChild(f);\n\
               var w = f.contentWindow; w.addEventListener(\"resize\", function () {}); w.document.open(); w.document.close();\n\
               var said = [typeof w, w === f.contentWindow, w.parent === window, f.contentDocument === w.document, typeof document.body.contentWindow]\n\
               var globals = [typeof w.String.prototype.replace, w.Array === Array, typeof w.setTimeout, w.window === w, w.document !== document]</script>"
          in
          Alcotest.(check string) "one window a frame, with a document; no other element has one" "[\"object\", true, true, true, \"undefined\"]" (value t "said");
          Alcotest.(check string) "and the language's globals, asked of it by who wants them untouched" "[\"function\", true, \"function\", true, true]" (value t "globals"));
      Testo.create "outerHTML: a style's text as written, a paragraph's with entities" (fun () ->
          let t = page "<body><script>var s = document.createElement(\"style\"); s.textContent = \"a > b { color: red }\"; var p = document.createElement(\"p\"); p.textContent = \"1 < 2 && 3\";\nvar said = [s.outerHTML, p.outerHTML]</script>" in
          Alcotest.(check string) "no entity in a style" "[\"<style>a > b { color: red }</style>\", \"<p>1 &lt; 2 &amp;&amp; 3</p>\"]" (value t "said"));
      Testo.create "screen is a Screen, the language's own members do not show" (fun () ->
          let t = page "<body><script>var n = 0; for (var k in Array.prototype) n++; for (var k in Math) n++;\nvar said = [screen instanceof Screen, typeof screen.addEventListener, n, Object.keys(new Error(\"x\")).length, typeof new OffscreenCanvas(2, 2).getContext(\"2d\")]</script>" in
          Alcotest.(check string) "what a page asks to know its browser was not tampered with" "[true, \"function\", 0, 0, \"object\"]" (value t "said"));
      Testo.create "a property of an attribute not written: the empty text" (fun () ->
          let t = page "<head><meta charset=utf-8><meta name=viewport content=x></head><body><a id=a>x</a><img id=i><div id=d></div><script>var m = document.getElementsByTagName(\"meta\");\nvar said = [m[0].name, m[1].name.toLowerCase(), document.getElementById(\"a\").rel, document.getElementById(\"i\").alt, typeof document.getElementById(\"d\").name]</script>" in
          Alcotest.(check string) "a meta's name, a link's rel, a picture's alt; a div has no name" "[\"\", \"viewport\", \"\", \"\", \"undefined\"]" (value t "said"));
      Testo.create "window.postMessage to oneself: a message event, in a task of its own" (fun () ->
          let t = page "<body><script>var said = [];\nwindow.addEventListener(\"message\", e => said.push(e.data + \" \" + (e.source === window) + \" \" + typeof e.origin));\nwindow.postMessage(\"hello\", \"*\"); said.push(\"posted\")</script>" in
          Alcotest.(check string) "not told yet" "[\"posted\"]" (value t "said");
          Browser_script.advance t 10.;
          Alcotest.(check string) "told after the script" "[\"posted\", \"hello true string\"]" (value t "said"));
      Testo.create "text and bytes: TextEncoder, TextDecoder, atob and btoa" (fun () ->
          let t =
            page
              "<body><p id=p>é😀</p><script>var said = [Array.from(new TextEncoder().encode(\"é€😀\")).join(\" \"), new TextDecoder().decode(new Uint8Array([195, 169, 226, 130, 172, 240, 159, 152, 128])) === \"é€😀\",\n\
               btoa(String.fromCharCode(0, 200, 255)), atob(\"AMj/\").charCodeAt(1), atob(\"AMj/\").length, document.getElementById(\"p\").textContent.length]</script>"
          in
          Alcotest.(check string) "UTF-8's bytes of a text; a byte a character in a binary string; a page's text in units"
            "[\"195 169 226 130 172 240 159 152 128\", true, \"AMj/\", 200, 3, 3]" (value t "said"));
      Testo.create "the page's selection is none, and its text empty" (fun () ->
          let t = page "<body><script>var s = getSelection(); var said = [String(s), \"\" + s, s.isCollapsed, s.rangeCount, s.type]</script>" in
          Alcotest.(check string) "what a page asks before it takes a click for one" "[\"\", \"\", true, 0, \"None\"]" (value t "said"));
      Testo.create "location as a string is the page's address; el.click() is the left button's" (fun () ->
          let t =
            page
              "<body><a id=a>x</a><script>var a = document.getElementById(\"a\"), button = \"none\";\n\
               a.addEventListener(\"click\", function (e) { button = e.button });\n\
               a.click();\n\
               var said = [(location + \"#top\").slice(-5), String(location) === location.href, \"\" + a, button]</script>"
          in
          Alcotest.(check string) "an address made with +, and the button a handler asks for" "[\"k#top\", true, \"[object HTMLElement]\", 0]" (value t "said"));
      Testo.create "a table as its rows and cells" (fun () ->
          let t =
            page
              "<body><table id=t><thead><tr><th>h</th></tr></thead><tbody><tr id=r><td>a</td><td id=c>b</td></tr><tr><td>c</td></tr></tbody></table><div id=d></div><script>\n\
               var t = document.getElementById(\"t\"), r = document.getElementById(\"r\"), c = document.getElementById(\"c\");\n\
               var said = [t.rows.length, t.tBodies[0].rows.length, r.cells.length, r.cells[1] === c, r.cells.item(1) === c, c.cellIndex, r.rowIndex, r.sectionRowIndex, typeof document.getElementById(\"d\").cells]</script>"
          in
          Alcotest.(check string) "table.rows, a body's, a row's cells, and where each is" "[3, 2, 2, true, true, 1, 1, 0, \"undefined\"]" (value t "said"));
      Testo.create "document.write, as the page is read: HTML where the script is, in order; a script written runs" (fun () ->
          let t =
            page
              "<head><script>document.write('<link rel=\"stylesheet\" href=\"a.css\">'); document.write('<meta name=\"x\">', '<meta name=\"y\">')</script><title>t</title></head>\n\
               <body><p id=before></p><script>document.write('<p id=w>written</p><script>var ran = \"yes\"<\\/script>')</script><p id=after></p>\n\
               <script>var head = document.head.children, w = document.getElementById(\"w\");\n\
               var said = [Array.prototype.map.call(head, function (e) { return e.localName + (e.getAttribute(\"name\") || \"\") }).join(\" \"),\n\
               w.previousElementSibling.localName, w.textContent, typeof ran, document.getElementById(\"after\").previousElementSibling.localName]</script>"
          in
          Alcotest.(check string) "the link after its script, the writes in order; the paragraph after its own, the script after it run"
            "[\"script link metax metay title\", \"script\", \"written\", \"string\", \"script\"]" (value t "said"));
      Testo.create "what a page asks for that is not here is told: a property not found, a function that does nothing" (fun () ->
          let t = page "<body><p id=p></p>" in
          let asked = ref [] in
          Js_value.missing := Some (fun cls k -> asked := (cls ^ "." ^ k) :: !asked);
          let r = Browser_script.eval t "var p = document.getElementById('p'); [typeof document.zork, typeof p.frobnicate, typeof window.nope, typeof document.title, typeof p.cells, typeof p.insertRow]" in
          Js_value.missing := None;
          Alcotest.(check string) "the page itself goes on" {|["undefined", "undefined", "undefined", "string", "undefined", "function"]|} (match r with Ok v -> Js_value.display v | Error e -> e.message);
          Alcotest.(check (list string)) "the three not found, and a table's cells, which a paragraph has not; not what is there"
            [ "HTMLDocument.zork"; "HTMLElement.frobnicate"; "Window.nope" ] (List.rev !asked);
          Hashtbl.reset (Script_host.missed_names ());
          ignore (Browser_script.eval t "document.open(); document.open(); p.scrollTo(0, 10)");
          Alcotest.(check (list string)) "called, said once each" [ "document.open()"; "element.scrollTo()" ] (List.sort compare (List.of_seq (Hashtbl.to_seq_keys (Script_host.missed_names ())))));
      Testo.create "a control's form; an event's handler not set is null" (fun () ->
          let t =
            page
              "<body><form id=f><input id=i><button id=b></button></form><form id=g></form><input id=o form=g><p id=p></p><script>\n\
               var get = function (id) { return document.getElementById(id) }, i = get(\"i\"), p = get(\"p\");\n\
               var before = [i.oninput, \"onclick\" in p, p.onclick];\n\
               p.onclick = function () {};\n\
               var said = [i.form === get(\"f\"), get(\"b\").form.id, get(\"o\").form.id, typeof p.form, before, typeof p.onclick, document.prerendering]</script>"
          in
          Alcotest.(check string) "the form around, or the one named; null until set" "[true, \"f\", \"g\", \"undefined\", [null, true, null], \"function\", false]" (value t "said"));
      Testo.create "a frame's world: its own globals, messages to and from its page, the page's clock, a key" (fun () ->
          let inside = "<body><p id=m>none</p><script>var mine = 'the frame';\nwindow.addEventListener('message', function (e) { document.getElementById('m').textContent = e.data; e.source.postMessage('got ' + e.data) });\ndocument.addEventListener('keydown', function (e) { parent.postMessage('key ' + e.key) });\nsetTimeout(function () { parent.postMessage('hello') }, 50)</script>" in
          let t =
            page
              ("<body><iframe id=f srcdoc=\"" ^ String.concat "&quot;" (String.split_on_char '"' (String.concat "&lt;" (String.split_on_char '<' inside))) ^ "\"></iframe><script>var mine = 'the page', heard = [], from = [];\n\
                window.addEventListener('message', function (e) { heard.push(e.data); from.push(e.source === document.getElementById('f').contentWindow) })</script>")
          in
          let frame = Browser_script.create_with { Browser_script.defaults with base = "about:blank" } (Html_tree.of_string inside) in
          Browser_script.adopt t ~key:inside frame;
          Browser_script.run_scripts frame;
          let said (s : Browser_script.t) e = match Browser_script.eval s e with Ok v -> Js_value.display v | Error e -> e.message in
          Alcotest.(check (pair string string)) "two worlds: a name in each" ("the page", "the frame") (said t "mine", said frame "mine");
          Alcotest.(check string) "the frame's parent is not itself" "false" (said frame "parent === window");
          (* the page's clock is the frame's: its timer, then the message's task in the page *)
          Browser_script.advance t 60.;
          Browser_script.advance t 16.;
          Alcotest.(check string) "the page heard its frame" {|[["hello"], [true]]|} (said t "[heard, from]");
          ignore (Browser_script.eval t "document.getElementById('f').contentWindow.postMessage('ping')");
          Browser_script.advance t 16.;
          Browser_script.advance t 16.;
          Alcotest.(check string) "the frame heard the page, and answered its source" {|["hello", "got ping"]|} (said t "heard");
          Alcotest.(check bool) "its document changed: the page's to lay out again" true (Browser_script.changed t);
          Alcotest.(check (option string)) "as the frame's scripts have it" (Some "ping") (Option.map (fun tree -> Dom.text_content (List.hd (Dom.find_all "p" tree))) (Browser_script.frame_tree t inside));
          Alcotest.(check bool) "a key is the frame's too: the page, which has no listener of its own, listens" true (Browser_script.listens t "keydown");
          ignore (Browser_script.window_event t "keydown" [ ("key", String "ArrowRight") ]);
          Browser_script.advance t 16.;
          Alcotest.(check string) "told to the page" "key ArrowRight" (said t "heard[2]"));
      Testo.create "another document, as a sanitizer makes and goes through one (DOMPurify's ways)" (fun () ->
          let t =
            page
              "<body><p id=mine>the page</p><script>\n\
               var d = new DOMParser().parseFromString('<p>hi <b>x</b></p><!--c--><svg><g></g></svg>', 'text/html');\n\
               var byTag = document.getElementsByTagName, it = document.createNodeIterator.call(d, d.body, 1 | 4 | 128, null, false), n, seen = [];\n\
               while ((n = it.nextNode())) seen.push(n.nodeName);\n\
               var made = document.implementation.createHTMLDocument(''), body = made.body;\n\
               body.outerHTML = '<i>cleaned</i> text';\n\
               var p = document.getElementById('mine'); p.outerHTML = '<h3 id=now>replaced</h3><em></em>';\n\
               var said = [byTag.call(d, 'html').length, byTag.call(d, 'body')[0] === d.body, byTag.call(d, 'p').length, document.getElementsByTagName('html')[0] === document.documentElement,\n\
                 d.body.firstChild.ownerDocument === d, document.body.ownerDocument === document, seen.join(' '), d.body.lastChild.namespaceURI.slice(-3),\n\
                 byTag.call(made, 'body')[0].innerHTML, document.getElementById('now').nextSibling.localName, document.getElementById('mine'),\n\
                 new XMLSerializer().serializeToString(d.body.firstChild)]</script>"
          in
          Alcotest.(check string) "the page's functions called on it; its nodes are its own; a body's outerHTML; a serializer"
            {|[1, true, 1, true, true, true, "P #text B #text #comment svg g", "svg", "<i>cleaned</i> text", "em", null, "<p>hi <b>x</b></p>"]|} (value t "said"));
      Testo.create "a table's rows and cells put in and taken out" (fun () ->
          let t =
            page
              "<body><table id=t></table><script>\n\
               var t = document.getElementById(\"t\"), r = t.insertRow(), c = r.insertCell(-1), first = r.insertCell(0), r0 = t.insertRow(0), last = t.insertRow(-1);\n\
               var said = [t.tBodies.length, t.rows.length, t.rows[0] === r0, t.rows[2] === last, r.cells.length, r.cells[0] === first, r.cells[1] === c, r.parentNode.localName];\n\
               t.deleteRow(0); r.deleteCell(-1); t.createTHead(); said.push(t.rows.length, r.cells.length, t.firstChild.localName)</script>"
          in
          Alcotest.(check string) "insertRow, insertCell, deleteRow, deleteCell, createTHead" "[1, 3, true, true, 2, true, true, \"tbody\", 2, 1, \"thead\"]" (value t "said"));
      Testo.create "errors to the console, the next script still run" (fun () ->
          let t = page "<script>\nx.y\n</script><script>console.log(\"next\", [1])</script>" in
          Alcotest.(check (list string)) "the console" [ "Uncaught ReferenceError: x is not defined (line 2)"; "next [1]" ] (Browser_script.console t));
      Testo.create "Script_dom's worked example: the copy thawed, read, changed, frozen" (fun () ->
          let tree = Html_tree.of_string "<p id=a>one <b>two</b>" in
          let root = Script_dom.thaw tree in
          let p = List.find (fun (n : Script_types.node) -> n.name = "p") (Script_dom.elements root) in
          Alcotest.(check (list string)) "its children: a text, a b" [ "#text"; "b" ] (List.map (fun (n : Script_types.node) -> n.name) p.children);
          Alcotest.(check bool) "each knows its parent" true (List.for_all (fun (n : Script_types.node) -> match n.parent with Some q -> q == p | None -> false) p.children);
          Alcotest.(check (option string)) "its attribute" (Some "a") (Script_dom.attribute p "id");
          Alcotest.(check string) "its text" "one two" (Script_dom.text_content p);
          Alcotest.(check string) "inner_html" "one <b>two</b>" (Script_dom.inner_html p);
          Alcotest.(check string) "html_of" {|<p id="a">one <b>two</b></p>|} (Script_dom.html_of p);
          Alcotest.(check bool) "frozen unchanged: the same tree" true (Script_dom.freeze root = tree);
          Script_dom.set_attribute p "id" "b";
          Script_dom.set_attribute p "class" "x";
          Script_dom.detach (List.nth p.children 1);
          Alcotest.(check string) "changed" {|<p id="b" class="x">one </p>|} (Script_dom.html_of p);
          Alcotest.(check (list string)) "a fragment's nodes" [ "i"; "#text" ] (List.map (fun (n : Script_types.node) -> n.name) (Script_dom.parse_fragment "<i>a</i>b")));
    ]
