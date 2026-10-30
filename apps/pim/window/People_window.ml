(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See People_window.mli *)

open Playground
open Pim_look

type caps = Mail_window.caps

(*****************************************************************************)
(* The model *)
(*****************************************************************************)

type mode = Browsing | Page | Asking

type model = {
  people : Item.t list; (* by name *)
  selected : int;
  (* the page open: the person, what is with them by section (the
   * items linking to them, the money paid to them, the mail with them),
   * the row selected *)
  person : Item.t option;
  page : (string * Item.t) list;
  at : int;
  mode : mode;
  field : string; (* a new person, typed *)
  status : string;
  held : string Set_.t;
}

let store (caps : caps) : Items.t = Items.at (Items.place caps)

(* a person's page (plan_pim.md, idea 2): what links to them by its
 * kind, the next events first; the money whose payee is their name;
 * the mail from or to them *)
let page (items : Item.t list) (c : Item.t) : (string * Item.t) list =
  let backs = List.map snd (Links.backlinks items c) in
  let backs =
    List.fold_left
      (fun acc i -> if List.memq i acc then acc else acc @ [ i ])
      [] backs
  in
  let day (i : Item.t) =
    match Search.day i with Some d -> Civil.days_from_civil d | None -> 0
  in
  let named = String.lowercase_ascii (title c) in
  let paid =
    List.filter
      (fun i ->
        Item.has_stamp i "money" && (not (List.memq i backs))
        && String.lowercase_ascii (Item.field i "payee") = named)
      items
  in
  let section name stamp l =
    List.map (fun i -> (name, i))
      (List.filter (fun i -> Item.has_stamp i stamp) l)
  in
  section "Events" "event"
    (List.stable_sort (fun a b -> compare (day a) (day b)) backs)
  @ section "Tasks" "task"
      (List.filter (fun i -> not (Item.has_stamp i "message")) backs)
  @ section "Money" "money"
      (List.filter (fun i -> not (Item.has_stamp i "task")) backs @ paid)
  @ section "Notes" "note" backs
  @ List.map (fun i -> ("Mail", i)) (People.with_ items c)

let load (caps : caps) (m : model) : model =
  let items = Items.all caps (store caps) in
  let ps = People.contacts items in
  let page = match m.person with Some c -> page items c | None -> [] in
  { m with people = ps; page;
    selected = max 0 (min m.selected (List.length ps - 1)) }

let initial (caps : caps) (_flags : Playground.flags) : model =
  load caps
    { people = []; selected = 0; person = None; page = []; at = 0;
      mode = Browsing; field = ""; status = ""; held = Set_.empty }

let refresh (caps : caps) (keys : string Set_.t) (m : model) : model =
  load caps { m with held = keys }

(* the person [id]'s page *)
let show (caps : caps) (m : model) (id : string) : model =
  match Items.find caps (store caps) id with
  | Some p -> load caps { m with mode = Page; person = Some p; at = 0 }
  | None -> { m with status = id ^ ": not in the store" }

(*****************************************************************************)
(* What the keys and the menus do *)
(*****************************************************************************)

type command = New_ | Open_ | Back | Write_ | Next | Previous

(* a page's rows: a section's name, an item; each section's name where
 * it begins *)
type row = Heading of string | Row of Item.t

let page_rows (page : (string * Item.t) list) : row list =
  let rec go last l =
    match l with
    | [] -> []
    | (name, i) :: rest ->
        (if name <> last then [ Heading name ] else []) @ (Row i :: go name rest)
  in
  go "" page

let menus : (string * (string * command) list) list =
  [ ( "Person",
      [ ("New Person...  (n)", New_); ("Open  (o)", Open_);
        ("Back to List  (u)", Back); ("Write To  (c)", Write_);
        ("Next  (j)", Next); ("Previous  (k)", Previous) ] ) ]

let current (m : model) : Item.t option =
  match m.mode with
  | Page -> m.person
  | Browsing | Asking -> List.nth_opt m.people m.selected

(* "Dan <dan@ix>" or "dan@ix" made a contact, BBDB's way by hand *)
let add (caps : caps) (m : model) (line : string) : model =
  match Mail.address (String.trim line) with
  | None -> { m with status = line ^ ": not an address (Dan <dan@ix>)" }
  | Some a ->
      let name = if a.display <> "" then a.display else a.mailbox in
      let c =
        Item.make ~id:(People.id a) ~stamps:[ "contact" ]
          [ ("name", name); ("email", String.lowercase_ascii a.mailbox) ]
          ""
      in
      if Items.find caps (store caps) (Item.id c) <> None then
        { m with status = Item.id c ^ ": already in People" }
      else begin
        Items.save caps (store caps) c;
        load caps { m with status = name ^ " added" }
      end

let command (caps : caps) (m : model) (c : command) : model * go option =
  match (c, m.mode) with
  | New_, _ -> ({ m with mode = Asking; field = ""; status = "" }, None)
  | Open_, Browsing -> (
      match current m with
      | Some p ->
          (load caps { m with mode = Page; person = Some p; at = 0 }, None)
      | None -> (m, None))
  | Open_, Page -> (
      match List.nth_opt m.page m.at with
      | Some (_, i) -> (m, Some (Item (Item.id i)))
      | None -> (m, None))
  | Back, _ -> ({ m with mode = Browsing; person = None }, None)
  | Write_, _ -> (
      match current m with
      | Some p -> (
          match People.emails p with
          | e :: _ ->
              let display = if title p = e then "" else title p in
              (m, Some (Write (Mail.address_to_string { display; mailbox = e })))
          | [] -> (m, None))
      | None -> (m, None))
  | Next, Page ->
      ({ m with at = min (List.length m.page - 1) (m.at + 1) }, None)
  | Previous, Page -> ({ m with at = max 0 (m.at - 1) }, None)
  | Next, _ ->
      ({ m with selected = min (List.length m.people - 1) (m.selected + 1) },
       None)
  | Previous, _ -> ({ m with selected = max 0 (m.selected - 1) }, None)
  | Open_, Asking -> (m, None)

let update (caps : caps) (computer : computer) (m : model) : model * go option =
  let keys = computer.keyboard.keys in
  let pressed name = Set_.mem name keys && not (Set_.mem name m.held) in
  let menu = chosen computer ~first:1 menus in
  let m, go =
    match m.mode with
    | Asking ->
        if pressed "Escape" then ({ m with mode = Browsing; field = "" }, None)
        else if pressed "Enter" then
          (add caps { m with mode = Browsing; field = "" } m.field, None)
        else if pressed "Backspace" then
          ({ m with field = without_last m.field }, None)
        else ({ m with field = m.field ^ printable computer.keyboard.typed }, None)
    | (Browsing | Page) when Gui.modal () -> (m, None)
    | Browsing | Page -> (
        let key =
          if pressed "j" || pressed "ArrowDown" then Some Next
          else if pressed "k" || pressed "ArrowUp" then Some Previous
          else if pressed "o" || pressed "Enter" then Some Open_
          else if pressed "u" || pressed "Escape" then Some Back
          else if pressed "n" then Some New_
          else if pressed "c" then Some Write_
          else None
        in
        let clicked =
          match (m.mode, m.person, row_click computer) with
          | Browsing, _, Some i when i < List.length m.people ->
              Some { m with selected = i }
          | Page, Some p, Some k -> (
              (* (the page's rows: the addresses, a blank, the sections) *)
              let k0 = List.length (People.emails p) + 1 in
              match List.nth_opt (page_rows m.page) (k - k0) with
              | Some (Row i) ->
                  let rec index j l =
                    match l with
                    | (_, x) :: rest -> if x == i then j else index (j + 1) rest
                    | [] -> -1
                  in
                  Some { m with at = index 0 m.page }
              | _ -> None)
          | _ -> None
        in
        match (menu, key, sidebar_click computer, clicked) with
        | Some c, _, _, _ | None, Some c, _, _ -> command caps m c
        | None, None, Some 0, _ -> command caps m Back
        | None, None, _, Some m' -> command caps m' Open_
        | None, None, _, None when wheel computer <> 0 ->
            if m.mode = Page then
              ({ m with at = moved m.at (wheel computer) (List.length m.page) },
               None)
            else
              ( { m with
                  selected =
                    moved m.selected (wheel computer) (List.length m.people) },
                None )
        | None, None, _, None -> (m, None))
  in
  ({ m with held = keys }, go)

(*****************************************************************************)
(* The picture *)
(*****************************************************************************)


let view (computer : computer) (m : model) : shape list =
  let a = area computer in
  let title_ =
    match (m.mode, m.person) with
    | Asking, _ -> "a person: " ^ m.field ^ "_"
    | Page, Some p -> title p
    | _ -> "People"
  in
  let right =
    if m.status <> "" then m.status
    else if m.mode = Page then count (List.length m.page) "item"
    else count (List.length m.people) "person"
  in
  let main =
    match (m.mode, m.person) with
    | Page, Some p ->
        (* the page: the addresses, then each section, its heading
         * where it begins *)
        let emails = People.emails p in
        let k0 = List.length emails + 1 in
        let rows = page_rows m.page in
        let shown (i : Item.t) =
          if Item.has_stamp i "message" then
            (Conversations.day i, Conversations.who i ^ "   " ^ title i)
          else
            ( (match Search.day i with
              | Some d -> Civil.to_string d
              | None -> ""),
              title i
              ^ match Books.postings i with
                | p :: _ when Item.has_stamp i "money" ->
                    "   " ^ Money.to_string (abs p.amount)
                | _ -> "" )
        in
        List.mapi
          (fun k e -> text grey ~bold:false ~room:a.room a.x0 (row_y a k) e)
          emails
        @ (if m.page = [] then
             [ text grey ~bold:false ~room:a.room a.x0 (row_y a k0)
                 "Nothing with them in the store yet." ]
           else [])
        @ List.concat
            (List.mapi
               (fun k r ->
                 let y = row_y a (k0 + k) in
                 match r with
                 | Heading name -> [ text ink ~bold:true ~room:a.room a.x0 y name ]
                 | Row i ->
                     let n =
                       let rec index j l =
                         match l with
                         | (_, x) :: rest ->
                             if x == i then j else index (j + 1) rest
                         | [] -> -1
                       in
                       index 0 m.page
                     in
                     let left, right = shown i in
                     (if n = m.at then [ selected a y ] else [])
                     @ [ text ink ~bold:false ~room:120. a.x0 y left;
                         text ink ~bold:false ~room:(a.room -. 130.)
                           (a.x0 +. 130.) y right ])
               rows)
    | _ when m.people = [] ->
        [ text grey ~bold:false ~room:a.room a.x0 (row_y a 0)
            "No one: n adds a person, p in Mail a conversation's sender." ]
    | _ ->
        List.concat
          (List.mapi
             (fun i (c : Item.t) ->
               let y = row_y a i in
               (if i = m.selected then [ selected a y ] else [])
               @ [ text ink ~bold:false ~room:190. a.x0 y (title c);
                   text grey ~bold:false ~room:(a.room -. 200.) (a.x0 +. 200.)
                     y (String.concat ", " (People.emails c)) ])
             m.people)
  in
  (rectangle white computer.screen.width computer.screen.height
   :: title_bar computer title_ right)
  @ sidebar a [ ("People", true) ]
  @ main
