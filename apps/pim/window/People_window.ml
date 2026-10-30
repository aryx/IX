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
  (* the page open: the person, the mail with them, the message selected *)
  person : Item.t option;
  mail : Item.t list;
  at : int;
  mode : mode;
  field : string; (* a new person, typed *)
  status : string;
  held : string Set_.t;
}

let store (caps : caps) : Items.t = Items.at (Items.place caps)

let load (caps : caps) (m : model) : model =
  let items = Items.all caps (store caps) in
  let ps = People.contacts items in
  let mail =
    match m.person with Some c -> People.with_ items c | None -> []
  in
  { m with people = ps; mail;
    selected = max 0 (min m.selected (List.length ps - 1)) }

let initial (caps : caps) (_flags : Playground.flags) : model =
  load caps
    { people = []; selected = 0; person = None; mail = []; at = 0;
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
      match List.nth_opt m.mail m.at with
      | Some i -> (m, Some (Item (Item.id i)))
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
  | Next, Page -> ({ m with at = min (List.length m.mail - 1) (m.at + 1) }, None)
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
        match (menu, key) with
        | Some c, _ | None, Some c -> command caps m c
        | None, None -> (m, None))
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
    else if m.mode = Page then count (List.length m.mail) "message"
    else count (List.length m.people) "person"
  in
  let main =
    match (m.mode, m.person) with
    | Page, Some p ->
        (* the page: the addresses, then the mail with them *)
        let emails = People.emails p in
        let k0 = List.length emails + 2 in
        List.mapi
          (fun k e -> text grey ~bold:false ~room:a.room a.x0 (row_y a k) e)
          emails
        @ [ text ink ~bold:true ~room:a.room a.x0 (row_y a (k0 - 1)) "Mail" ]
        @ (if m.mail = [] then
             [ text grey ~bold:false ~room:a.room a.x0 (row_y a k0)
                 "No mail with them in the store." ]
           else [])
        @ List.concat
            (List.mapi
               (fun k (i : Item.t) ->
                 let y = row_y a (k0 + k) in
                 (if k = m.at then [ selected a y ] else [])
                 @ [ text ink ~bold:false ~room:120. a.x0 y (Conversations.day i);
                     text ink ~bold:false ~room:(a.room -. 130.) (a.x0 +. 130.)
                       y (Conversations.who i ^ "   " ^ title i) ])
               m.mail)
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
