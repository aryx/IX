(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Pim_window.mli *)

open Playground
open Pim_look

type caps = Mail_window.caps

(*****************************************************************************)
(* The model *)
(*****************************************************************************)

(* what Home says of each view, read from the store as it is shown *)
type home = {
  unread : int; (* the Inbox's conversations not read *)
  inbox : int;
  late : int; (* the tasks to do whose day is past *)
  due_today : int;
  to_do : int;
  people : int;
  notes : int;
  events_today : int;
  money : (string * Money.cents) list; (* the first accounts' balances *)
  next_event : string; (* the next today, "" for none *)
  day_written : bool; (* today's page has a text *)
  (* the late tasks and today's, the mail back from a snooze *)
  today_list : (bool * string) list; (* late?, what *)
  page : string list; (* today's page's first lines *)
}

type model = {
  view : view;
  account : string;
  today : Civil.date;
  home : home;
  mail : Mail_window.model;
  tasks : Tasks_window.model;
  people : People_window.model;
  notes : Notes_window.model;
  calendar : Calendar_window.model;
  money_ : Money_window.model;
  (* a search over every view, shown over the view searched from *)
  finding : bool;
  search : Search_window.model;
  held : string Set_.t;
}

let store (caps : caps) : Items.t = Items.at (Items.place caps)

let home (caps : caps) ~(account : string) ~(today : Civil.date) : home =
  let items = Items.all caps (store caps) in
  let cs =
    Conversations.group (Mail_item.listed items ~account ~mailbox:"INBOX")
  in
  let events = Events.between items ~from:today ~upto:today in
  let page = List.filteri (fun k _ -> k < 4) (Today.page items today) in
  {
    unread = List.length (List.filter Conversations.unread cs);
    inbox = List.length cs;
    late = List.length (Today.late items today);
    due_today = List.length (Today.due items today);
    to_do = List.length (Today.to_do items today);
    people = List.length (People.contacts items);
    notes = List.length (List.filter (fun i -> Item.has_stamp i "note") items);
    events_today = List.length events;
    money =
      List.filteri (fun k _ -> k < 2)
        (List.filter_map
           (fun a ->
             if String.length a > 7 && String.sub a 0 7 = "Assets:" then
               Some (String.sub a 7 (String.length a - 7), Books.balance items a)
             else None)
           (Books.accounts items));
    next_event =
      (match events with
       | (_, Some t, i) :: _ -> Events.clock t ^ " " ^ title i
       | (_, None, i) :: _ -> title i
       | [] -> "");
    day_written = page <> [];
    page;
    today_list =
      List.map
        (fun (k, what) ->
          match (k : Today.kind) with
          | At (Some t) -> (false, Events.clock t ^ " " ^ what)
          | At None -> (false, what)
          | Late -> (true, "late: " ^ what)
          | Due -> (false, "due today: " ^ what)
          | Back -> (false, "back from snooze: " ^ what)
          | From who -> (false, "from " ^ who ^ ": " ^ what))
        (Today.lines items ~account today);
  }

let initial (caps : caps) (flags : Playground.flags) : model =
  let flag name =
    match List.assoc_opt name flags with Some v -> v | None -> ""
  in
  let account = flag "user" in
  let today =
    match Search.date (flag "today") with Some d -> d | None -> When.today caps
  in
  {
    view =
      (match flag "view" with
      | "mail" -> Mail
      | "tasks" -> Tasks
      | "people" -> People
      | "notes" -> Notes
      | "calendar" -> Calendar
      | "money" -> Money
      | _ -> Home);
    account;
    today;
    home = home caps ~account ~today;
    mail = Mail_window.initial caps flags;
    tasks = Tasks_window.initial caps flags;
    people = People_window.initial caps flags;
    notes = Notes_window.initial caps flags;
    calendar = Calendar_window.initial caps flags;
    money_ = Money_window.initial caps flags;
    finding = false;
    search = Search_window.initial caps flags;
    held = Set_.empty;
  }

(*****************************************************************************)
(* Going from view to view *)
(*****************************************************************************)

(* the view [v], read again from the store: another view may have
 * changed it (a task made in Mail, a sender added to People) *)
let switch (caps : caps) (s : model) (keys : string Set_.t) (v : view) : model =
  let s = { s with view = v; finding = false } in
  match v with
  | Home -> { s with home = home caps ~account:s.account ~today:s.today }
  | Mail -> { s with mail = Mail_window.refresh caps keys s.mail }
  | Tasks -> { s with tasks = Tasks_window.refresh caps keys s.tasks }
  | People -> { s with people = People_window.refresh caps keys s.people }
  | Notes -> { s with notes = Notes_window.refresh caps keys s.notes }
  | Calendar ->
      { s with calendar = Calendar_window.refresh caps keys s.calendar }
  | Money -> { s with money_ = Money_window.refresh caps keys s.money_ }

let go (caps : caps) (s : model) (keys : string Set_.t) (g : go) : model =
  match g with
  | View v -> switch caps s keys v
  | Item id -> (
      (* where it lives: a message (a task too) in Mail, then by its
       * stamp *)
      let i = Items.find caps (store caps) id in
      let has stamp =
        match i with Some i -> Item.has_stamp i stamp | None -> false
      in
      if has "message" then
        let s = switch caps s keys Mail in
        { s with mail = Mail_window.show caps s.mail id }
      else if has "contact" then
        let s = switch caps s keys People in
        { s with people = People_window.show caps s.people id }
      else if has "task" then
        let s = switch caps s keys Tasks in
        { s with tasks = Tasks_window.show caps s.tasks id }
      else if has "event" then
        let s = switch caps s keys Calendar in
        { s with calendar = Calendar_window.show caps s.calendar id }
      else if has "note" then
        let s = switch caps s keys Notes in
        { s with notes = Notes_window.show caps s.notes id }
      else if has "money" then
        let s = switch caps s keys Money in
        { s with money_ = Money_window.show caps s.money_ id }
      else s)
  | Write to_ ->
      let s = switch caps s keys Mail in
      { s with mail = Mail_window.write s.mail to_ }

(* the suite's menu, the first: Outlook's Go > Mail, Calendar,
 * Contacts, Tasks, and their keys, Ctrl and the view's number; the
 * search over them all *)
type command = Go_to of view | Find | Exit

let pim_menu : (string * (string * command) list) list =
  [ ( "Pim",
      List.mapi
        (fun i (v, name) ->
          (Printf.sprintf "%s  (Ctrl+%d)" name i, Go_to v))
        views
      @ [ ("Search...  (Ctrl+E)", Find); ("Exit", Exit) ] ) ]

(* the switcher's places, at the sidebar's foot *)
let switcher_y (computer : computer) (i : int) : float =
  (* (above the platform's line, at the very foot, of the tests') *)
  (-.computer.screen.height /. 2.) +. 70.
  +. (float_of_int (List.length views - 1 - i) *. row)

(* the view whose place in the switcher was clicked *)
let switcher_click (computer : computer) : view option =
  let mouse = computer.mouse in
  let left = -.computer.screen.width /. 2. in
  if not mouse.mclick || mouse.mx < left || mouse.mx > left +. side then None
  else
    List.find_map
      (fun (i, (v, _)) ->
        let y = switcher_y computer i in
        if mouse.my >= y && mouse.my < y +. row then Some v else None)
      (List.mapi (fun i v -> (i, v)) views)

(* Home's tiles: a view each, three a row *)
let tiles : (view * string) list = List.filter (fun (v, _) -> v <> Home) views

let tile_box (i : int) : Widget.box =
  { Widget.x = -260. +. (float_of_int (i mod 3) *. 260.);
    y = 250. -. (float_of_int (i / 3) *. 190.); w = 220.; h = 170. }

(* the key that opens a view from Home *)
let home_keys : (string * view) list =
  [ ("m", Mail); ("c", Calendar); ("p", People); ("t", Tasks); ("n", Notes);
    ("b", Money) ]

let tile_click (computer : computer) : view option =
  let mouse = computer.mouse in
  if not mouse.mclick then None
  else
    List.find_map
      (fun (i, (v, _)) ->
        let b = tile_box i in
        if
          Float.abs (mouse.mx -. b.x) <= b.w /. 2.
          && Float.abs (mouse.my -. b.y) <= b.h /. 2.
        then Some v
        else None)
      (List.mapi (fun i t -> (i, t)) tiles)

let update (caps : caps) (computer : computer) (s : model) : model =
  let keys = computer.keyboard.keys in
  let pressed name = Set_.mem name keys && not (Set_.mem name s.held) in
  let menu = chosen computer ~first:0 pim_menu in
  let by_key =
    if not (Set_.mem "Control" keys) then None
    else
      List.find_map
        (fun (i, (v, _)) -> if pressed (string_of_int i) then Some v else None)
        (List.mapi (fun i v -> (i, v)) views)
  in
  let clicked =
    if Gui.modal () then None
    else if s.view = Home && not s.finding then tile_click computer
    else switcher_click computer
  in
  let home_key =
    if s.view <> Home || s.finding then None
    else List.find_map (fun (k, v) -> if pressed k then Some v else None) home_keys
  in
  let find =
    (Set_.mem "Control" keys && pressed "e")
    || (s.view = Home && (not s.finding) && pressed "/")
  in
  let menu = if menu = None && find then Some Find else menu in
  let day_page = s.view = Home && (not s.finding) && pressed "d" in
  let s =
    match (menu, by_key, clicked, home_key) with
    | Some Exit, _, _, _ -> CapStdlib.exit caps 0
    | None, None, None, None when day_page ->
        let s = switch caps s keys Notes in
        { s with notes = Notes_window.day_note caps s.notes }
    | Some Find, _, _, _ ->
        { s with finding = true;
          search = Search_window.start caps keys s.search s.view }
    | Some (Go_to v), _, _, _
    | None, Some v, _, _
    | None, None, Some v, _
    | None, None, None, Some v ->
        switch caps s keys v
    | None, None, None, None when s.finding -> (
        let f, g = Search_window.update caps computer s.search in
        let s = { s with search = f } in
        match g with Some g -> go caps s keys g | None -> s)
    | None, None, None, None -> (
        match s.view with
        | Home -> s
        | Mail -> { s with mail = Mail_window.update caps computer s.mail }
        | Tasks -> (
            let t, g = Tasks_window.update caps computer s.tasks in
            let s = { s with tasks = t } in
            match g with Some g -> go caps s keys g | None -> s)
        | People -> (
            let p, g = People_window.update caps computer s.people in
            let s = { s with people = p } in
            match g with Some g -> go caps s keys g | None -> s)
        | Notes -> (
            let n, g = Notes_window.update caps computer s.notes in
            let s = { s with notes = n } in
            match g with Some g -> go caps s keys g | None -> s)
        | Calendar -> (
            let c, g = Calendar_window.update caps computer s.calendar in
            let s = { s with calendar = c } in
            match g with Some g -> go caps s keys g | None -> s)
        | Money -> (
            let b, g = Money_window.update caps computer s.money_ in
            let s = { s with money_ = b } in
            match g with Some g -> go caps s keys g | None -> s))
  in
  { s with held = keys }

(*****************************************************************************)
(* The picture *)
(*****************************************************************************)

let weekdays =
  [ "Sunday"; "Monday"; "Tuesday"; "Wednesday"; "Thursday"; "Friday";
    "Saturday" ]

let months =
  [ "January"; "February"; "March"; "April"; "May"; "June"; "July";
    "August"; "September"; "October"; "November"; "December" ]

(* "Thursday 29 October 2026" *)
let long_day (d : Civil.date) : string =
  Printf.sprintf "%s %d %s %d"
    (List.nth weekdays (Civil.weekday (Civil.days_from_civil d)))
    d.day
    (List.nth months (d.month - 1))
    d.year

(* a view's picture on its tile: an envelope, a list ticked, a face *)
let icon (v : view) (b : Widget.box) : shape list =
  let at dx dy sh = sh |> move (b.x +. dx) (b.y +. dy) in
  let line = rgb 60 64 67 in
  match v with
  | Mail ->
      [ at 0. 30. (rectangle line 84. 54.); at 0. 30. (rectangle white 80. 50.);
        at (-20.) 40. (rectangle line 50. 2. |> rotate (-32.));
        at 20. 40. (rectangle line 50. 2. |> rotate 32.) ]
  | Tasks ->
      List.concat
        (List.init 3 (fun k ->
             let y = 52. -. (float_of_int k *. 20.) in
             [ at (-30.) y (rectangle line 12. 12.);
               at (-30.) y (rectangle white 9. 9.);
               at 10. y (rectangle line 56. 3.) ]))
  | People ->
      [ at 0. 46. (circle line 15.); at 0. 46. (circle white 12.);
        at 0. 12. (oval line 56. 30.); at 0. 10. (oval white 50. 26.);
        at 0. 2. (rectangle white 60. 16.) ]
  | Notes ->
      [ at 0. 34. (rectangle line 56. 70.); at 0. 34. (rectangle white 52. 66.) ]
      @ List.init 4 (fun k ->
            at 0. (54. -. (float_of_int k *. 13.)) (rectangle line 36. 2.))
  | Calendar ->
      [ at 0. 34. (rectangle line 70. 60.); at 0. 31. (rectangle white 66. 50.);
        at 0. 60. (rectangle line 70. 6.) ]
      @ List.concat
          (List.init 6 (fun k ->
               [ at (-22. +. (float_of_int (k mod 3) *. 22.))
                   (44. -. (float_of_int (k / 3) *. 18.))
                   (rectangle line 12. 10.) ]))
  | Money ->
      [ at 0. 34. (rectangle line 84. 46.); at 0. 34. (rectangle white 80. 42.);
        at 0. 34. (circle line 13.); at 0. 34. (circle white 10.);
        at (-30.) 34. (circle line 4.); at 30. 34. (circle line 4.) ]
  | Home -> []

let home_view (computer : computer) (s : model) : shape list =
  let h = s.home in
  let says (v : view) : string list =
    match v with
    | Mail ->
        [ Printf.sprintf "%d unread" h.unread;
          Printf.sprintf "%d in the Inbox" h.inbox ]
    | Tasks ->
        [ count h.to_do "task" ^ " to do";
          Printf.sprintf "%d late, %d today" h.late h.due_today ]
    | People -> [ count h.people "person" ]
    | Calendar ->
        [ Printf.sprintf "%d today" h.events_today;
          (if h.next_event = "" then "nothing today" else h.next_event) ]
    | Money ->
        if h.money = [] then [ "no lines yet" ]
        else List.map (fun (a, c) -> a ^ " " ^ Money.to_string c) h.money
    | Notes ->
        [ count h.notes "note";
          (if h.day_written then "today's page written" else "no page today") ]
    | Home -> []
  in
  let tile i (v, name) =
    let b = tile_box i in
    [ rectangle (rgb 218 220 224) (b.w +. 4.) (b.h +. 4.)
      |> move (b.x +. 3.) (b.y -. 3.);
      rectangle white b.w b.h |> move b.x b.y ]
    @ icon v b
    @ [ text ink ~bold:true ~room:b.w (b.x -. (width name /. 2.)) (b.y -. 30.)
          name ]
    @ List.mapi
        (fun k l ->
          text grey ~bold:false ~room:b.w (b.x -. (width l /. 2.))
            (b.y -. 54. -. (float_of_int k *. 20.)) l)
        (says v)
  in
  let a = area computer in
  let today =
    if h.today_list = [] then
      [ (false, "Nothing today: no event, nothing late or due.") ]
    else List.filteri (fun i _ -> i < 7) h.today_list
  in
  (* today's page under the list, d to write in it (Notes) *)
  let page_y = -110. -. (float_of_int (List.length today) *. 24.) -. 30. in
  let page =
    text ink ~bold:true ~room:500. (-390.) page_y "Today's page"
    :: List.mapi
         (fun k l ->
           text grey ~bold:false ~room:780. (-390.)
             (page_y -. 30. -. (float_of_int k *. 24.)) l)
         (if h.page = [] then [ "Nothing written yet: d writes it." ] else h.page)
  in
  [ rectangle (rgb 241 243 244) computer.screen.width computer.screen.height;
    text ink ~bold:true ~room:500. (a.left +. 40.) (a.top -. 50.) "mini-pim";
    text grey ~bold:false ~room:500.
      (-.a.left -. 40. -. width (long_day s.today))
      (a.top -. 50.) (long_day s.today) ]
  @ List.concat (List.mapi tile tiles)
  @ [ text ink ~bold:true ~room:500. (-390.) (-80.) "Today" ]
  @ List.mapi
      (fun k (late, l) ->
        text (if late then red else ink) ~bold:false ~room:780. (-390.)
          (-110. -. (float_of_int k *. 24.)) l)
      today
  @ page
  @ [ text grey ~bold:false ~room:900. (-390.)
        ((-.computer.screen.height /. 2.) +. 24.)
        ("m, c, p, t, n, b or a click opens a view, d today's page, / "
         ^ "searches; Ctrl+0 to 6 goes to one.") ]

(* the switcher: the views, the one shown marked *)
let switcher_view (computer : computer) (s : model) : shape list =
  let left = -.computer.screen.width /. 2. in
  let top = switcher_y computer 0 +. row in
  (rectangle (rgb 218 220 224) side 1. |> move (left +. (side /. 2.)) (top +. 6.))
  :: List.concat
       (List.mapi
          (fun i (v, name) ->
            let y = switcher_y computer i in
            (if v = s.view then
               [ rectangle (rgb 211 227 253) side row
                 |> move (left +. (side /. 2.)) (y +. (row /. 2.)) ]
             else [])
            @ [ text (if v = s.view then ink else grey) ~bold:(v = s.view)
                  ~room:(side -. 24.) (left +. 16.) (y +. 9.) name ])
          views)

let view (computer : computer) (s : model) : shape list =
  let body =
    match s.view with
    | _ when s.finding ->
        Search_window.view computer s.search @ switcher_view computer s
    | Home -> home_view computer s
    | Mail -> Mail_window.view computer s.mail @ switcher_view computer s
    | Tasks -> Tasks_window.view computer s.tasks @ switcher_view computer s
    | People -> People_window.view computer s.people @ switcher_view computer s
    | Notes -> Notes_window.view computer s.notes @ switcher_view computer s
    | Calendar ->
        Calendar_window.view computer s.calendar @ switcher_view computer s
    | Money -> Money_window.view computer s.money_ @ switcher_view computer s
  in
  let top = (computer.screen.height /. 2.) -. menu_bar in
  body
  @ [ rectangle (Gui.theme ()).face computer.screen.width menu_bar
      |> move 0. (top +. (menu_bar /. 2.)) ]
  (* (the menus last: an open one over the rest) *)
  @ Gui.draw ()
