(* LocalStorage: a page's own small store -- names and strings a
   script keeps for later; and sessionStorage, its twin.

     localStorage.setItem("theme", "dark")
     localStorage.getItem("theme")        "dark"
     localStorage.getItem("nope")         null
     localStorage.theme                   "dark"   (an item is a property too)
     localStorage.length                  1
     localStorage.key(0)                  "theme"
     localStorage.removeItem("theme"), localStorage.clear()

   Six methods and strings only: a number stored comes back as a
   string, an object as "[object Object]" -- which is why what is
   stored is nearly always JSON.stringify's.

   In a browser the store is the *origin*'s (Cors.mli): every page of
   https://example.com sees the same localStorage, no page of another
   site does, and it is still there after the browser is closed.
   sessionStorage is the same object with a shorter life: one tab's,
   gone when it closes.

   wib:
   Here each is a list in memory, made when the page is, gone with
   it: a script that asks for the store finds one and can use it
   within its page, which is what most do (a theme, a draft, whether a
   banner was dismissed); nothing is written to the profile, and two
   pages of one site do not share it. No "storage" event either (what
   tells one tab that another changed the store).

   cs-history:
   Before it, the only thing a page could keep was a cookie (Lou
   Montulli, Netscape, 1994; Cookie.mli): 4 KB, and sent back to the
   server with every request, picture and style sheet included --
   made for the server to recognise a visitor, not for a script to
   remember. Sites kept data in Flash's "local shared objects" and in
   Internet Explorer's userData behaviors for want of better.

   cs-history:
   Web Storage was Ian Hickson's, in HTML5's drafts (first as "DOM
   Storage", 2005-06): megabytes instead of kilobytes, never sent
   anywhere, a plain object. Firefox 2 had sessionStorage (2006);
   localStorage was in Internet Explorer 8, Firefox 3.5, Safari 4 and
   Chrome 4 by 2009-10, and a W3C Recommendation in 2013.

   evolution:
   It is *synchronous*: getItem returns at once, so the browser must
   have the origin's whole store in memory -- read from disk before
   the first script that asks -- and a page freezes while it does.
   What came after is all asynchronous: IndexedDB (2011-15), a
   database of objects with transactions, and the Cache API for a
   service worker's files. localStorage stayed, for what is small.

   Reference: the HTML Standard, section 12, "Web storage"
   (html.spec.whatwg.org/multipage/webstorage.html). *)
(* ix: the author's mini-chrome's src/webapi/window/LocalStorage.mli (its 8af888e) (docs/plans/plan_browser.md) *)

(* a store of its own, empty: a Storage object *)
val make : unit -> Js_value.value

(* window's localStorage and sessionStorage, each a store of its own *)
val install : (string -> Js_value.value -> unit) -> unit
