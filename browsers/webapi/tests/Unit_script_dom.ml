(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's mini-chrome's tests/browser/Unit_script_dom.ml (its 8af888e) (docs/plans/plan_browser.md) *)

(* See Unit_script_dom.mli *)

(* a page, then a script: its last expression's value as the console
 * shows it *)
let run ?(html = "") (script : string) : string =
  let t = Browser_script.create (Html_tree.of_string ("<body>" ^ html ^ "</body>")) in
  Browser_script.run_scripts t;
  match Browser_script.eval t script with Ok v -> Js_value.display v | Error e -> "error: " ^ e.message

let check what ?html script expected = Alcotest.(check string) what expected (run ?html script)
let list = "<ul id=l><li class=a>1</li><li>2</li></ul>"

let tests =
  Testo.categorize "Script dom"
    [
      Testo.create "the worked example: matches, closest, append, after" (fun () ->
          check "a selector tried on an element; its first ancestor that matches" ~html:list
            {|const l = document.getElementById("l"), first = l.firstElementChild;
              [first.matches("ul > li.a"), first.matches("li.b"), first.closest("ul") === l, first.closest("li") === first, first.closest("table")]|}
            "[true, false, true, true, null]";
          check "append: nodes and strings, at the end; after: beside" ~html:list
            {|const l = document.getElementById("l"), first = l.firstElementChild;
              l.append("3", document.createElement("li"));
              const then = l.innerHTML;
              first.after(l.lastElementChild);
              [then, l.innerHTML]|}
            {|["<li class=\"a\">1</li><li>2</li>3<li></li>", "<li class=\"a\">1</li><li></li><li>2</li>3"]|};
          check "prepend, before, replaceWith, replaceChildren" ~html:list
            {|const l = document.getElementById("l"), b = document.createElement("b");
              l.prepend("0"); l.lastElementChild.before(b); b.replaceWith("B", "b");
              const then = l.textContent;
              l.replaceChildren(); [then, l.childNodes.length]|}
            {|["01Bb2", 0]|});
      Testo.create "a tree a script made, not in the page" (fun () ->
          check "selectors work in it; it is not connected" 
            {|const d = document.createElement("div"); d.innerHTML = "<p class=x><b>t</b></p><p>u</p>";
              [d.querySelectorAll("p").length, d.querySelector("p.x b").textContent, d.firstChild.matches("div > p"), d.isConnected, document.body.isConnected, document.contains(d)]|}
            {|[2, "t", true, false, true, false]|};
          check "a copy: deep or not; the copy is another node" ~html:list
            {|const l = document.getElementById("l"), deep = l.cloneNode(true), shallow = l.cloneNode(false);
              deep.firstElementChild.textContent = "changed";
              [deep.children.length, shallow.children.length, shallow.id, l.firstElementChild.textContent, deep === l]|}
            {|[2, 0, "l", "1", false]|};
          check "a fragment: its children go in its place; a comment is a node, not shown" ~html:list
            {|const f = document.createDocumentFragment(), l = document.getElementById("l");
              f.append(document.createElement("li"), document.createComment("mark"));
              const kinds = [f.nodeType, f.lastChild.nodeType, f.lastChild.nodeValue];
              l.appendChild(f);
              [kinds, l.childNodes.length, l.children.length, f.childNodes.length, l.innerHTML.endsWith("<li></li><!--mark-->"), l.textContent]|}
            {|[[11, 8, "mark"], 4, 3, 0, true, "12"]|};
          check "who is first, who is inside" ~html:list
            {|const l = document.getElementById("l"), a = l.children[0], b = l.children[1];
              [a.compareDocumentPosition(b), b.compareDocumentPosition(a), a.compareDocumentPosition(l), l.compareDocumentPosition(a), a.compareDocumentPosition(a), l.contains(b), a.contains(l)]|}
            "[4, 2, 10, 20, 0, true, false]");
      Testo.create "attributes: as properties, as data, as a list" (fun () ->
          check "dataset; hasAttribute; toggleAttribute; attributes" ~html:{|<input id=i data-user-id=7 disabled>|}
            {|const i = document.getElementById("i");
              i.dataset.lastSeen = "now";
              [i.dataset.userId, i.getAttribute("data-last-seen"), i.hasAttribute("disabled"), i.toggleAttribute("disabled"), i.disabled, i.attributes.map(a => a.name)]|}
            {|["7", "now", true, false, false, ["id", "data-user-id", "data-last-seen"]]|};
          check "a property that is an attribute" ~html:{|<input id=i><div id=d></div><label id=lb for=i></label>|}
            {|const i = document.getElementById("i"), d = document.getElementById("d");
              i.type = "radio"; i.name = "n"; i.required = true;
              [i.getAttribute("type"), i.name, i.hasAttribute("required"), d.name, d.title, document.getElementById("lb").htmlFor, document.createElement("input").type]|}
            {|["radio", "n", true, undefined, "", "i", "text"]|};
          check "no boxes for a script, but the page's own size, the window's" ~html:list
            {|const r = document.getElementById("l").getBoundingClientRect(); [r.width, r.top, document.getElementById("l").offsetWidth, document.body.offsetWidth, document.documentElement.clientWidth === innerWidth]|}
            "[0, 0, 0, 1000, true]");
      Testo.create "events of a script's own" (fun () ->
          check "the worked example: a CustomEvent, its detail, bubbling to the document" ~html:list
            {|const l = document.getElementById("l"), seen = [];
              l.addEventListener("saved", e => seen.push("ul " + e.detail.id + " " + (e.target === l.firstElementChild)));
              document.addEventListener("saved", e => seen.push("document " + (e instanceof CustomEvent) + " " + (e instanceof Event)));
              const went = l.firstElementChild.dispatchEvent(new CustomEvent("saved", { detail: { id: 7 }, bubbles: true }));
              [seen, went]|}
            {|[["ul 7 true", "document true true"], true]|};
          check "one that does not bubble; stopPropagation; preventDefault" ~html:list
            {|const l = document.getElementById("l"), first = l.firstElementChild, seen = [];
              l.addEventListener("quiet", () => seen.push("never"));
              first.dispatchEvent(new Event("quiet"));
              first.addEventListener("loud", e => { e.stopPropagation(); e.preventDefault(); seen.push("li") });
              l.addEventListener("loud", () => seen.push("never"));
              [first.dispatchEvent(new Event("loud", { bubbles: true, cancelable: true })), seen]|}
            {|[false, ["li"]]|};
          check "once; an object with handleEvent; click(); createEvent" ~html:list
            {|const l = document.getElementById("l"), seen = [];
              l.addEventListener("click", () => seen.push("once"), { once: true });
              l.addEventListener("click", { handleEvent(e) { seen.push(e.type + " " + (this.handleEvent !== undefined)) } });
              l.firstElementChild.click(); l.click();
              const old = document.createEvent("CustomEvent"); old.initCustomEvent("made", true, false, "d");
              document.addEventListener("made", e => seen.push(e.detail));
              l.dispatchEvent(old); window.dispatchEvent(new Event("made"));
              seen|}
            {|["once", "click true", "click true", "d", null]|};
          check "a listener that throws: said, the next still run" ~html:list
            {|const l = document.getElementById("l"), seen = [];
              l.addEventListener("x", () => { throw new Error("first") }); l.addEventListener("x", () => seen.push("second"));
              l.dispatchEvent(new Event("x")); seen|}
            {|["second"]|});
      Testo.create "the document as a node; window's globals" (fun () ->
          check "what jQuery asks of a document" ~html:list
            {|[document.nodeType, document.documentElement.nodeName, document.childNodes.length, document.ownerDocument, document.body.ownerDocument === document,
               document.implementation.createHTMLDocument("").body.nodeName, document.createElement("p").ownerDocument === document]|}
            {|[9, "HTML", 1, null, true, "BODY", true]|};
          check "the classes: instanceof, constants, a method added to a prototype" ~html:list
            {|const l = document.getElementById("l");
              Element.prototype.shout = function () { return this.id.toUpperCase() };
              [l instanceof HTMLElement, l instanceof Node, l.firstChild.firstChild instanceof Text, l instanceof Text, document instanceof Document,
               Node.ELEMENT_NODE, l.shout(), l.hasOwnProperty("nope"), typeof l.toString]|}
            {|[true, true, true, false, true, 1, "L", false, "function"]|};
          check "window is the global object" {|var a = 1; window.b = 2; [window.a, b, window === self, window.window === window, globalThis === window, typeof window.setTimeout, window.innerWidth]|}
            {|[1, 2, true, true, true, "function", 1000]|};
          check "getComputedStyle: the element's own style, a few defaults" ~html:{|<p id=p style="color: red" hidden></p><p id=q></p>|}
            {|const s = getComputedStyle(document.getElementById("p"));
              [s.color, s.getPropertyValue("color"), s.display, getComputedStyle(document.getElementById("q")).display, s.marginTop]|}
            {|["red", "red", "none", "block", ""]|};
          check "storage, observers, history: there, and quiet; matchMedia: the window's size (1000 wide)"
            {|localStorage.setItem("k", 1); localStorage.other = "o";
              const o = new MutationObserver(() => {}); o.observe(document.body, { childList: true }); o.disconnect();
              history.pushState({}, "", "/x");
              [localStorage.getItem("k"), localStorage.getItem("nope"), localStorage.length, sessionStorage.length, matchMedia("(min-width: 1px)").matches, matchMedia("(max-width: 500px)").matches, typeof performance.now(), typeof requestAnimationFrame]|}
            {|["1", null, 2, 0, true, false, "number", "function"]|});
      Testo.create "selectors: the fast way and the simple one agree" (fun () ->
          let html = {|<div id=a class="x y"><ul><li class=first>1</li><li>2<span id=s>in</span></li><li>3</li></ul></div><p class=x>p</p>|} in
          let asks =
            {|var a = document.getElementById("a"), s = document.getElementById("s");
              JSON.stringify([document.querySelectorAll("li").length, a.querySelectorAll(":scope > ul > li").length, a.querySelectorAll("li:first-child")[0].textContent,
                a.querySelectorAll("li:last-child")[0].textContent, a.querySelector(".x") === null, document.querySelectorAll(".x").length,
                s.matches("div.x li span"), s.matches("ul > span"), s.closest("li").textContent, s.closest(".y").id, s.matches("li:nth-child(2) > span"),
                a.querySelectorAll("li + li").length, document.querySelectorAll("div p, body > p").length,
                a.querySelectorAll("*").length, document.querySelectorAll(" * ").length, Array.from(a.querySelectorAll("*")).map(e => e.tagName).join(""),
                document.createDocumentFragment().querySelectorAll("*").length])|}
          in
          let ask opti =
            let before = !Mini_opti.enabled in
            Mini_opti.enabled := opti;
            Fun.protect ~finally:(fun () -> Mini_opti.enabled := before) (fun () -> run ~html asks)
          in
          Alcotest.(check string) "what they find" {|[3,3,"1","3",true,2,true,false,"2in","a",true,2,1,5,9,"ULLILISPANLI",0]|} (ask true);
          Alcotest.(check string) "the same, the simple way" (ask true) (ask false));
      Testo.create "Event_loop, the worked example: a task, its microtasks, then the next task" (fun () ->
          let t = Browser_script.create_with { Browser_script.defaults with base = "http://site.test/" } (Html_tree.of_string "<body></body>") in
          let seen () = match Browser_script.eval t "seen.join(' ')" with Ok v -> Js_value.display v | Error e -> "error: " ^ e.message in
          ignore (Browser_script.eval t {|var seen = []; seen.push(1); setTimeout(() => seen.push(4), 0); Promise.resolve().then(() => seen.push(3)); seen.push(2)|});
          Alcotest.(check string) "the script to its end, then the promise's then; the timer is another task" "1 2 3" (seen ());
          Browser_script.advance t 1.;
          Alcotest.(check string) "the clock moved: the timer's turn" "1 2 3 4" (seen ());
          (* timers in the order they are due, an interval again and again, one cleared never *)
          ignore (Browser_script.eval t {|seen = []; setTimeout(() => seen.push("b"), 20); setTimeout(() => seen.push("a"), 10); const never = setTimeout(() => seen.push("x"), 15); clearTimeout(never);
                                           let n = 0; const every = setInterval(() => { seen.push("i" + ++n); if (n == 3) clearInterval(every) }, 10); requestAnimationFrame(() => seen.push("frame"))|});
          Browser_script.advance t 5.;
          Alcotest.(check string) "nothing due yet" "" (seen ());
          Browser_script.advance t 50.;
          Alcotest.(check string) "by their times, then by the order they were set" "a i1 frame b i2 i3" (seen ());
          (* a timer's own microtasks run before the next timer *)
          ignore (Browser_script.eval t {|seen = []; setTimeout(() => { seen.push("t1"); Promise.resolve().then(() => seen.push("m1")) }, 1); setTimeout(() => seen.push("t2"), 1)|});
          Browser_script.advance t 5.;
          Alcotest.(check string) "each task's microtasks before the next task" "t1 m1 t2" (seen ()));
      Testo.create "LocalStorage, the worked example: names and strings" (fun () ->
          let t = Browser_script.create_with { Browser_script.defaults with base = "http://site.test/" } (Html_tree.of_string "<body></body>") in
          let ask s = match Browser_script.eval t s with Ok v -> Js_value.display v | Error e -> "error: " ^ e.message in
          Alcotest.(check string) "set, got, as a property, counted, by its place"
            {|["dark", null, "dark", 1, "theme"]|}
            (ask {|localStorage.setItem("theme", "dark"); [localStorage.getItem("theme"), localStorage.getItem("nope"), localStorage.theme, localStorage.length, localStorage.key(0)]|});
          Alcotest.(check string) "strings only: a number, an object"
            {|["1", "[object Object]", "{\"a\":1}"]|}
            (ask {|localStorage.setItem("n", 1); localStorage.o = {a: 1}; localStorage.j = JSON.stringify({a: 1}); [localStorage.n, localStorage.getItem("o"), localStorage.j]|});
          Alcotest.(check string) "set again: its value changed, its place kept; removed; cleared"
            {|["light", "theme", 3, 0, undefined]|}
            (ask {|localStorage.setItem("theme", "light"); const a = [localStorage.theme, localStorage.key(0)]; localStorage.removeItem("n"); a.push(localStorage.length); localStorage.clear(); a.push(localStorage.length, localStorage.theme); a|});
          Alcotest.(check string) "sessionStorage: a store of its own" {|[null, "s"]|} (ask {|localStorage.setItem("only", "l"); sessionStorage.setItem("only", "s"); localStorage.clear(); [localStorage.getItem("only"), sessionStorage.getItem("only")]|}));
      Testo.create "a script sends the page elsewhere" (fun () ->
          let t = Browser_script.create_with { Browser_script.defaults with base = "http://site.test/a/page.html?q=1#top" } (Html_tree.of_string "<body></body>") in
          let ask s = match Browser_script.eval t s with Ok v -> Js_value.display v | Error e -> "error: " ^ e.message in
          Alcotest.(check string) "location's parts" {|["http:", "site.test", "/a/page.html", "?q=1", "#top", "http://site.test"]|}
            (ask "[location.protocol, location.host, location.pathname, location.search, location.hash, location.origin]");
          Alcotest.(check (option (pair string bool))) "nowhere yet" None (Browser_script.take_navigation t);
          ignore (ask {|location.href = "next.html"|});
          Alcotest.(check (option (pair string bool))) "href =: there, the page left kept in the history" (Some ("http://site.test/a/next.html", false)) (Browser_script.take_navigation t);
          Alcotest.(check (option (pair string bool))) "taken once" None (Browser_script.take_navigation t);
          ignore (ask {|location.replace("/other")|});
          Alcotest.(check (option (pair string bool))) "replace: in its place" (Some ("http://site.test/other", true)) (Browser_script.take_navigation t);
          ignore (ask {|window.location = "https://else.test/"; location.assign("last")|});
          Alcotest.(check (option (pair string bool))) "the last said wins" (Some ("http://site.test/a/last", false)) (Browser_script.take_navigation t));
      Testo.create "URLSearchParams" (fun () ->
          check "the worked example" {|const p = new URLSearchParams("q=caf%C3%A9+au+lait&lang=fr"); const q = p.get("q");
            p.set("lang", "en"); p.append("page", 2); [q, p.toString(), new URLSearchParams({ a: 1, b: "x y" }).toString()]|}
            {|["café au lait", "q=caf%C3%A9+au+lait&lang=en&page=2", "a=1&b=x+y"]|};
          check "a list: a name several times; gone through as pairs; from pairs, from another, from a ?query" {|
            const p = new URLSearchParams("?a=1&a=2&b=3"); p.delete("b"); p.append("c", "4");
            [p.getAll("a"), p.get("nope"), p.has("c"), [...p].map(kv => kv.join("=")), [...p.keys()], new URLSearchParams([["x", "1"]]).get("x"), new URLSearchParams(p).toString()]|}
            {|[["1", "2"], null, true, ["a=1", "a=2", "c=4"], ["a", "a", "c"], "1", "a=1&a=2&c=4"]|});
      Testo.create "what a page whose scripts run does not show; the script running" (fun () ->
          let t = Browser_script.create (Html_tree.of_string "<body><noscript><p id=no>enable scripts</p></noscript><p id=yes>content</p><script id=me>var mine = document.currentScript.id</script></body>") in
          Browser_script.run_scripts t;
          let ids = List.filter_map (Dom.attribute "id") (Dom.find_all "p" (Browser_script.tree t)) in
          Alcotest.(check (list string)) "a <noscript>'s content is not in the page laid out" [ "yes" ] ids;
          Alcotest.(check string) "document.currentScript, while it runs and after" {|["me", null]|}
            (match Browser_script.eval t "[mine, document.currentScript]" with Ok v -> Js_value.display v | Error e -> e.message);
          check "DOMParser: HTML read into a page of its own" {|const d = new DOMParser().parseFromString("<p class=a>one</p><p>two</p>", "text/html");
            [d.body.children.length, d.querySelector("p.a").textContent, d.querySelectorAll("p").length, document.querySelectorAll("p").length]|}
            {|[2, "one", 2, 0]|});
      Testo.create "a picture come: its <img> told, and its size" (fun () ->
          let t =
            Browser_script.create_with { Browser_script.defaults with base = "http://site.test/news/" } (Html_tree.of_string
                 {|<body><img id=a src="a.png"><img id=b src="/b.png" onerror="seen.push('b error')"><img id=c srcset="c-240.webp 240w, c-480.webp 480w" onload="seen.push('c load')"><script>var seen = [];
                   var a = document.getElementById("a"); a.addEventListener("load", function () { seen.push("a load " + a.naturalWidth + "x" + a.naturalHeight + " " + a.complete) });</script></body>|})
          in
          Browser_script.run_scripts t;
          let value s = match Browser_script.eval t s with Ok v -> Js_value.display v | Error e -> e.message in
          Alcotest.(check string) "before: not complete" "[undefined, []]" (value "[a.complete, seen]");
          Browser_script.picture t "http://site.test/news/a.png" (Some (640., 360.));
          Browser_script.picture t "http://site.test/b.png" None;
          Browser_script.picture t "http://site.test/other.png" (Some (1., 1.));
          Browser_script.picture t "http://site.test/news/c-240.webp" (Some (240., 135.));
          Alcotest.(check string) "load with its size; error for the one not had; nothing for another address; a srcset's first" {|["a load 640x360 true", "b error", "c load"]|} (value "seen"));
      Testo.create "an element is of its tag's class; EventTarget; a listener's signal; a sheet made by a script" (fun () ->
          check "instanceof" ~html:"<a id=a href=x>l</a><button id=b>b</button>"
            {|const a = document.getElementById("a"), b = document.getElementById("b");
              [a instanceof HTMLAnchorElement, a instanceof HTMLElement, b instanceof HTMLButtonElement, b instanceof HTMLAnchorElement, document.createElement("div") instanceof HTMLDivElement]|}
            "[true, true, true, false, true]";
          check "new EventTarget(), and a class that extends it" {|class Bus extends EventTarget {} const bus = new Bus(), seen = [];
              const f = e => seen.push(e.type); bus.addEventListener("ping", f); bus.dispatchEvent(new Event("ping")); bus.removeEventListener("ping", f); bus.dispatchEvent(new Event("ping")); seen|}
            {|["ping"]|};
          check "{ signal }: aborted, the listener is gone" ~html:"<p id=p></p>"
            {|const p = document.getElementById("p"), c = new AbortController(); let n = 0;
              p.addEventListener("x", () => n++, { signal: c.signal }); p.dispatchEvent(new Event("x")); c.abort(); p.dispatchEvent(new Event("x")); n|}
            "1";
          check "a TreeWalker: down, across, up, back; a filter that skips, one that rejects" ~html:"<div id=r><p id=a>x<b id=b>y</b></p><span><i id=c>z</i></span><em id=d></em></div>"
            {|const r = document.getElementById("r"), id = n => n && n.id;
              const w = document.createTreeWalker(r, NodeFilter.SHOW_ELEMENT);
              const seen = [id(w.firstChild()), id(w.firstChild()), id(w.nextSibling()), id(w.parentNode()), id(w.nextSibling()), id(w.lastChild()), id(w.parentNode()), id(w.nextSibling()), id(w.nextSibling()), id(w.previousNode())];
              const skip = document.createTreeWalker(r, NodeFilter.SHOW_ELEMENT, n => n.tagName === "SPAN" ? NodeFilter.FILTER_SKIP : n.tagName === "P" ? NodeFilter.FILTER_REJECT : NodeFilter.FILTER_ACCEPT);
              [seen, id(skip.firstChild()), id(skip.nextSibling()), id(skip.previousSibling()), id(skip.parentNode())]|}
            {|[["a", "b", null, "a", "", "c", "", "d", null, "c"], "c", "d", "c", "r"]|};
          check "prepend of a child already there, the first or another" ~html:"<div id=d><p id=a></p><p id=b></p><p id=c></p></div>"
            {|const d = document.getElementById("d"), ids = () => [...d.children].map(e => e.id).join("");
              d.prepend(d.children[0]); const same = ids(); d.prepend(d.children[2]); const moved = ids(); d.prepend(d.children[1], d.children[0]); [same, moved, ids()]|}
            {|["abc", "cab", "acb"]|};
          check "a <style>'s sheet: rules put in by a script, after its own text" ~html:"<style id=s>p { margin: 0 }</style><p id=p>x</p>"
            {|const s = document.getElementById("s"), sheet = s.sheet;
              sheet.insertRule(".a { color: red }", 0); sheet.insertRule(".b { color: blue }", 1); sheet.deleteRule(0);
              [sheet === s.sheet, sheet.ownerNode === s, sheet.cssRules.length, sheet.cssRules[0].cssText, sheet.cssRules[0].selectorText,
               s.textContent.replace(/\s+/g, " "), document.styleSheets.length, document.getElementById("p").sheet]|}
            {|[true, true, 1, ".b { color: blue }", ".b", "p { margin: 0 } .b { color: blue }", 1, null]|};
          check "a <script>'s innerHTML is its text, whatever < and > it holds"
            {|const s = document.createElement("script"); s.innerHTML = "var made = 0; for (var i = 0; i<3; i++) made += i>0 ? 1 : 0;"; document.head.appendChild(s);
              const st = document.createElement("style"); st.innerHTML = "a>b { color: red }"; [made, s.textContent.length, st.textContent]|}
            {|[2, 60, "a>b { color: red }"]|};
          check "IntersectionObserver: what is observed is not told at once" ~html:"<img id=i>"
            {|var told = []; const o = new IntersectionObserver(es => es.forEach(e => told.push(e.target.id + ":" + e.isIntersecting)));
              o.observe(document.getElementById("i")); [told.length, typeof o.unobserve, o.takeRecords().length]|}
            {|[0, "function", 0]|};
          (* Polymer's microtask: a text node changed, its observer told once the script has ended *)
          (let t = Browser_script.create (Html_tree.of_string "<body></body>") in
           Browser_script.run_scripts t;
           let ask e = match Browser_script.eval t e with Ok v -> Js_value.display v | Error e -> "error: " ^ e.message in
           Alcotest.(check string) "MutationObserver: not told at once" "0"
             (ask {|var told = [], n = document.createTextNode(""); new MutationObserver(rs => told.push(rs.length + rs[0].type)).observe(n, { characterData: true });
                    n.textContent = 1; n.textContent = 2; var other = document.createTextNode(""); other.textContent = 3; told.length|});
           Alcotest.(check string) "told after, once, of the two changes" {|["2characterData"]|} (ask "told"));
          (let t = Browser_script.create (Html_tree.of_string "<body><p id=p>x</p></body>") in
           Browser_script.run_scripts t;
           Browser_script.set_measure t (fun _ _ -> Some (0., 300., 100., 20.));
           Browser_script.scrolled t 120.;
           Alcotest.(check string) "the window scrolled: scrollY, and a rectangle from the window's top" "[120, 120, 180, 300]"
             (match Browser_script.eval t {|var p = document.getElementById("p"); [scrollY, pageYOffset, p.getBoundingClientRect().top, p.offsetTop]|} with
             | Ok v -> Js_value.display v
             | Error e -> "error: " ^ e.message));
          check "a property given before the element's class is defined: its own, taken at the upgrade (Polymer)" ~html:"<x-a id=a></x-a>"
            {|var a = document.getElementById("a"); a.icon = "menu"; var before = [a.hasOwnProperty("icon"), a.hasOwnProperty("id"), a.hasOwnProperty("nope")];
              class XA extends HTMLElement {
                constructor() { super(); if (this.hasOwnProperty("icon")) { var v = this.icon; delete this.icon; this.icon = v; } }
                set icon(v) { this._icon = v + "!"; } get icon() { return this._icon; } }
              customElements.define("x-a", XA); [before, a.icon, a.hasOwnProperty("icon")]|}
            {|[[true, false, false], "menu!", false]|};
          (* a click of the browser's own is an Event *)
          (let root = Html_tree.of_string "<body><b id=b>x</b></body>" in
           let t = Browser_script.create root in
           Browser_script.run_scripts t;
           ignore (Browser_script.eval t {|var was; document.addEventListener("click", e => { was = [e instanceof Event, e.composedPath().length > 2, e.path[0].id] })|});
           let rec find (e : Dom.element) = if Dom.attribute "id" e = Some "b" then Some e else List.find_map (fun (n : Dom.node) -> match n with Dom.Element c -> find c | Text _ -> None) e.children in
           ignore (Browser_script.click t (Option.get (find (Browser_script.tree t))));
           Alcotest.(check string) "the browser's click: an Event, with its path" {|[true, true, "b"]|}
             (match Browser_script.eval t "was" with Ok v -> Js_value.display v | Error e -> "error: " ^ e.message));
          (let t = Browser_script.create (Html_tree.of_string "<body><b id=b>x</b></body>") in
           Browser_script.run_scripts t;
           let ask e = match Browser_script.eval t e with Ok v -> Js_value.display v | Error e -> "error: " ^ e.message in
           Alcotest.(check string) "el.animate: running, and not ended at once" {|["running", 0]|}
             (ask {|var ends = []; var a = document.getElementById("b").animate([{ opacity: 1 }, { opacity: 0 }], 200); a.onfinish = () => ends.push("on"); a.addEventListener("finish", () => ends.push("listener")); a.finished.then(() => ends.push("promise")); [a.playState, ends.length]|});
           Browser_script.advance t 10.;
           Alcotest.(check string) "ended a moment later: all who waited told, once" {|["finished", "on,listener,promise"]|}
             (ask {|a.finish(); [a.playState, ends.sort().join().replace("listener,on", "on,listener")]|}));
          check "EventTarget.prototype's methods called on an element are the element's" ~html:"<div id=d></div>"
            {|var d = document.getElementById("d"), n = 0, f = () => n++;
              d.addEventListener("go", f); EventTarget.prototype.dispatchEvent.call(d, new Event("go"));
              EventTarget.prototype.addEventListener.call(d, "go", () => n += 10); d.dispatchEvent(new Event("go"));
              EventTarget.prototype.removeEventListener.call(d, "go", f); d.dispatchEvent(new Event("go"));
              var t = new EventTarget(), m = 0; t.addEventListener("x", () => m++); t.dispatchEvent(new Event("x")); [n, m]|}
            "[22, 1]";
          (* a form about to be sent: the document's submit listener puts a token in a hidden field (Google's sign-in), another prevents *)
          (let root = Html_tree.of_string {|<body><form id=f action=/go><input type=hidden name=bg id=bg value=js_disabled><button id=b>Next</button></form><form id=g><input type=hidden name=h></form></body>|} in
           let t = Browser_script.create root in
           Browser_script.run_scripts t;
           ignore (Browser_script.eval t {|document.addEventListener("submit", e => { if (e.target.id == "g") e.preventDefault(); else document.getElementById("bg").value = "token-" + e.type + "-" + (e instanceof Event) })|});
           let rec find id (e : Dom.element) = if Dom.attribute "id" e = Some id then Some e else List.find_map (fun (n : Dom.node) -> match n with Dom.Element c -> find id c | Text _ -> None) e.children in
           let tree = Browser_script.tree t in
           let get id = Option.get (find id tree) in
           Alcotest.(check bool) "told, not prevented" false (Browser_script.submit t (get "f"));
           Alcotest.(check (option string)) "the field's value as the script left it" (Some "token-submit-true") (Browser_script.value_now t (get "bg"));
           Alcotest.(check bool) "the other form's is prevented" true (Browser_script.submit t (get "g")));
          (* form.submit(): a form a script sends itself, its fields as the script left them *)
          (let t = Browser_script.create_with { Browser_script.defaults with base = "https://x.org/signin/wait?a=1" } (Html_tree.of_string {|<body><form id=f action=/signin/next method=post><input type=hidden name=token value=old><input type=hidden name=TL value="a b"></form><form id=g action="go?x=1#top"><input name=q value=cats></form></body>|}) in
           Browser_script.run_scripts t;
           ignore (Browser_script.eval t {|var f = document.getElementById("f"); f.elements; f.querySelector("[name=token]").value = "new"; f.submit()|});
           Alcotest.(check (option (pair string (option (pair string string))))) "a POST: the action resolved, the fields encoded"
             (Some ("https://x.org/signin/next", Some ("application/x-www-form-urlencoded", "token=new&TL=a+b")))
             (Browser_script.take_submission t);
           Alcotest.(check bool) "taken once" true (Browser_script.take_submission t = None);
           ignore (Browser_script.eval t {|document.getElementById("g").submit()|});
           Alcotest.(check (option (pair string (option (pair string string))))) "a GET: the fields in the place of the action's query" (Some ("https://x.org/signin/go?q=cats", None))
             (Browser_script.take_submission t));
          check "an event's path: its target, what it is in, the document, the window" ~html:"<div id=d><p id=p><b id=b>x</b></p></div>"
            {|var seen; document.getElementById("d").addEventListener("go", e => { seen = e.composedPath().map(n => n.id || n.nodeName || "window").join(" ") + " / " + (e.path.indexOf(e.currentTarget)) });
              document.getElementById("b").dispatchEvent(new Event("go", { bubbles: true })); seen|}
            "b p d BODY HTML #document window / 2";
          check "a custom element told of an attribute it observes, set and removed later" ~html:"<x-b id=b held></x-b>"
            {|var told = []; class XB extends HTMLElement { static get observedAttributes() { return ["held", "size"]; } attributeChangedCallback(n, o, v) { told.push(n + ":" + o + ">" + v); } }
              customElements.define("x-b", XB); var b = document.getElementById("b");
              b.setAttribute("size", "2"); b.setAttribute("size", "2"); b.setAttribute("other", "x"); b.removeAttribute("held"); told|}
            {|["held:null>", "size:null>2", "held:>null"]|};
          check "its entry is a class, with the members a page looks for before it trusts the observer"
            {|["intersectionRatio" in IntersectionObserverEntry.prototype, "isIntersecting" in IntersectionObserverEntry.prototype, typeof new IntersectionObserver(() => 0).observe]|}
            {|[true, true, "function"]|};
          check "a comment a script made: its next and previous element" ~html:"<div id=d><b id=x></b><i id=y></i></div>"
            {|const d = document.getElementById("d"), c = document.createComment("lit-node 0"); d.insertBefore(c, d.children[1]);
              [c.nextElementSibling.id, c.previousElementSibling.id, c.nextSibling.id, d.children[0].nextElementSibling.id, d.children[1].nextElementSibling]|}
            {|["y", "x", "y", "y", null]|};
          check "a custom element's class takes its properties' assignments; data is not a text's here" ~html:"<x-card id=c><b>kept</b></x-card>"
            {|class Card extends HTMLElement {}; const seen = [];
              Object.defineProperty(Card.prototype, "endpoint", { get() { return this._e }, set(v) { this._e = v; seen.push("set " + v.url) }, configurable: true });
              customElements.define("x-card", Card); const c = document.getElementById("c");
              c.endpoint = { url: "/watch" }; c.data = { title: "T" }; c.id = "d";
              [seen, c.endpoint.url, c.data.title, c.children.length, c.textContent, c.getAttribute("id"), document.createTextNode("x").data]|}
            {|[["set /watch"], "/watch", "T", 1, "kept", "d", "x"]|};
          check "document.all is something: undefined is not it" ~html:"<p>x</p>" {|[undefined === document.all, document.all.length > 2]|} "[false, true]";
          check "adoptedStyleSheets: a <style> of the page"
 {|const s = new CSSStyleSheet(); s.replaceSync("p { color: red }"); document.adoptedStyleSheets = [s];
              [document.adoptedStyleSheets.length, document.querySelector("style[data-adopted]").textContent.trim()]|}
            {|[1, "p { color: red }"]|});
    ]
