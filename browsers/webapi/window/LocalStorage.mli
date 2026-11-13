(* LocalStorage: a page's own small store, where a script keeps names
   and strings for later; and sessionStorage, its twin.

     localStorage.setItem("theme", "dark")
     localStorage.getItem("theme")        "dark"
     localStorage.getItem("nope")         null
     localStorage.theme                   "dark"   (an item is a property too)
     localStorage.length                  1
     localStorage.key(0)                  "theme"
     localStorage.removeItem("theme"), localStorage.clear()

   There are six methods, and only strings are stored: a number stored
   comes back as a string, and an object as "[object Object]". That is
   why what is stored is nearly always the output of JSON.stringify.

   In a browser, the store belongs to the *origin* (Cors.mli): every
   page of https://example.com sees the same localStorage, no page of
   another site does, and it is still there after the browser is
   closed. sessionStorage is the same object with a shorter life: it
   belongs to one tab, and is gone when the tab closes.

   wib:
   Here each store is a list in memory, made when the page is made and
   gone with it. A script that asks for the store finds one and can
   use it within its page, which is what most scripts do (for a theme,
   a draft, or whether a banner was dismissed). Nothing is written to
   the profile, and two pages of one site do not share a store. There
   is no "storage" event either (the event that tells one tab that
   another changed the store).

   cs-history:
   Before it, the only thing a page could keep was a cookie (Lou
   Montulli, Netscape, 1994; see mini-chrome's Cookie.mli, since ix
   keeps none yet). A cookie holds 4 KB, and is sent back to the
   server with every request, pictures and style sheets included: it
   was made for the server to recognise a visitor, not for a script to
   remember. For want of better, sites kept data in Flash's "local
   shared objects" and in Internet Explorer's userData behaviors.

   cs-history:
   Web Storage was Ian Hickson's work, in HTML5's drafts (first as "DOM
   Storage", 2005-06). It held megabytes instead of kilobytes, was
   never sent anywhere, and was a plain object. Firefox 2 had
   sessionStorage (2006); localStorage was in Internet Explorer 8,
   Firefox 3.5, Safari 4 and Chrome 4 by 2009-10, and became a W3C
   Recommendation in 2013.

   evolution:
   It is *synchronous*: getItem returns at once, so the browser must
   have the origin's whole store in memory, read from disk before the
   first script that asks for it, and a page freezes while the browser
   reads it.
   What came after is all asynchronous: IndexedDB (2011-15), a
   database of objects with transactions, and the Cache API for a
   service worker's files. localStorage stayed, for what is small.

   Reference: the HTML Standard, section 12, "Web storage"
   (html.spec.whatwg.org/multipage/webstorage.html). *)
(* ix: copied from src/webapi/window/LocalStorage.mli in the author's
 * mini-chrome (its 8af888e) (docs/plans/plan_browser.md) *)

(* a new empty store, as a Storage object *)
val make : unit -> Js_value.value

(* defines window's localStorage and sessionStorage, each a store of its
 * own *)
val install : (string -> Js_value.value -> unit) -> unit
