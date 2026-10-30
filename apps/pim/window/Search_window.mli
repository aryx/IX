(* Search_window: one search over every component (plan_pim.md, idea
   4: "Search over every item, Gmail's syntax where it fits"), Ctrl+E
   from any view (Outlook's), / from Home (Gmail's); the items found as
   the query is typed, by the component they live in, and one opened
   there.

       Pim   Search
       search: alice_                                  4 items
      +-------------+---------------------------------------------+
      |#Everything##|  Mail (2)                                   |
      | Mail  2     |    the plan               Alice   2026-10-29|
      | Calendar  1 |    Re: the plan           Carol   2026-10-29|
      | People  1   |  Calendar (1)                               |
      |             |    lunch with alice       2026-11-03 12:30  |
      |             |  People (1)                                 |
      |             |    Alice Martin           alice@ix          |
      +-------------+---------------------------------------------+

   The query is Search's (store/Search.mli): words, from:alice,
   is:task, before:2026-12-01, -is:read. It runs over the store as it
   was when the search began, each letter typed. Up and Down choose
   (j and k are letters of the query), Enter or a click opens the
   item where it lives (Pim_look.Item: a message in Mail, a money line
   in its register...), Tab shows one component's, then the next's,
   Esc goes back to the view searched from.

   Mail's own / is not this one: it asks Gmail (X-GM-RAW), which has
   every message and their texts; this searches what the store has. *)

type caps = Mail_window.caps

type model

(* today= the tests' day, else the clock's *)
val initial : caps -> Playground.flags -> model

(* [start caps keys m back]: a new search, the store read, from the
 * view [back]; [keys] those down now *)
val start : caps -> string Set_.t -> model -> Pim_look.view -> model

val update : caps -> Playground.computer -> model -> model * Pim_look.go option

(* the view, under the menu bar and the menus, which the suite draws *)
val view : Playground.computer -> model -> Playground.shape list
