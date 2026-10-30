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
  (* the late tasks and today's, the mail back from a snooze *)
  today_list : (bool * string) list; (* late?, what *)
}

type model = {
  view : view;
  account : string;
  today : Civil.date;
  home : home;
  mail : Mail_window.model;
  tasks : Tasks_window.model;
  people : People_window.model;
  held : string Set_.t;
}

let store (caps : caps) : Items.t = Items.at (Items.place caps)

let home (caps : caps) ~(account : string) ~(today : Civil.date) : home =
  let items = Items.all caps (store caps) in
  let cs =
    Conversations.group (Mail_item.listed items ~account ~mailbox:"INBOX")
  in
  let t = Civil.days_from_civil today in
  let day (i : Item.t) =
    match Search.day i with Some d -> Civil.days_from_civil d | None -> max_int
  in
  let later (i : Item.t) =
    match Search.date (Item.field i "until") with
    | Some d -> Civil.days_from_civil d > t
    | None -> false
  in
  let to_do =
    List.filter
      (fun i ->
        Item.has_stamp i "task" && Item.field i "done" = "" && not (later i))
      items
  in
  let late = List.filter (fun i -> day i < t) to_do in
  let due = List.filter (fun i -> day i = t) to_do in
  let woke = List.filter (fun i -> Item.field i "woke" <> "") items in
  {
    unread = List.length (List.filter Conversations.unread cs);
    inbox = List.length cs;
    late = List.length late;
    due_today = List.length due;
    to_do = List.length to_do;
    people = List.length (People.contacts items);
    today_list =
      List.map (fun i -> (true, "late: " ^ title i)) late
      @ List.map (fun i -> (false, "due today: " ^ title i)) due
      @ List.map (fun i -> (false, "back from snooze: " ^ title i)) woke;
  }

let initial (caps : caps) (flags : Playground.flags) : model =
  let flag name =
    match List.assoc_opt name flags with Some v -> v | None -> ""
  in
  let account = flag "user" in
  let today =
    match Search.date (flag "today") with Some d -> d | None -> When.today ()
  in
  {
    view =
      (match flag "view" with
      | "mail" -> Mail
      | "tasks" -> Tasks
      | "people" -> People
      | _ -> Home);
    account;
    today;
    home = home caps ~account ~today;
    mail = Mail_window.initial caps flags;
    tasks = Tasks_window.initial caps flags;
    people = People_window.initial caps flags;
    held = Set_.empty;
  }

(*****************************************************************************)
(* Going from view to view *)
(*****************************************************************************)

(* the view [v], read again from the store: another view may have
 * changed it (a task made in Mail, a sender added to People) *)
let switch (caps : caps) (s : model) (keys : string Set_.t) (v : view) : model =
  let s = { s with view = v } in
  match v with
  | Home -> { s with home = home caps ~account:s.account ~today:s.today }
  | Mail -> { s with mail = Mail_window.refresh caps keys s.mail }
  | Tasks -> { s with tasks = Tasks_window.refresh caps keys s.tasks }
  | People -> { s with people = People_window.refresh caps keys s.people }

let go (caps : caps) (s : model) (keys : string Set_.t) (g : go) : model =
  match g with
  | View v -> switch caps s keys v
  | Message id ->
      let s = switch caps s keys Mail in
      { s with mail = Mail_window.show caps s.mail id }
  | Write to_ ->
      let s = switch caps s keys Mail in
      { s with mail = Mail_window.write s.mail to_ }

(* the suite's menu, the first: Outlook's Go > Mail, Calendar,
 * Contacts, Tasks, and their keys, Ctrl and the view's number *)
type command = Go_to of view | Exit

let pim_menu : (string * (string * command) list) list =
  [ ( "Pim",
      List.mapi
        (fun i (v, name) ->
          (Printf.sprintf "%s  (Ctrl+%d)" name i, Go_to v))
        views
      @ [ ("Exit", Exit) ] ) ]

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

(* Home's tiles: a view each, side by side *)
let tiles : (view * string) list = List.filter (fun (v, _) -> v <> Home) views

let tile_box (i : int) : Widget.box =
  { Widget.x = -260. +. (float_of_int i *. 260.); y = 220.; w = 220.; h = 180. }

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
    else if s.view = Home then tile_click computer
    else switcher_click computer
  in
  let home_key =
    if s.view <> Home then None
    else if pressed "m" then Some Mail
    else if pressed "t" then Some Tasks
    else if pressed "p" then Some People
    else None
  in
  let s =
    match (menu, by_key, clicked, home_key) with
    | Some Exit, _, _, _ -> CapStdlib.exit caps 0
    | Some (Go_to v), _, _, _
    | None, Some v, _, _
    | None, None, Some v, _
    | None, None, None, Some v ->
        switch caps s keys v
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
    if h.today_list = [] then [ (false, "Nothing late, nothing due today.") ]
    else List.filteri (fun i _ -> i < 8) h.today_list
  in
  [ rectangle (rgb 241 243 244) computer.screen.width computer.screen.height;
    text ink ~bold:true ~room:500. (a.left +. 40.) (a.top -. 50.) "mini-pim";
    text grey ~bold:false ~room:500.
      (-.a.left -. 40. -. width (long_day s.today))
      (a.top -. 50.) (long_day s.today) ]
  @ List.concat (List.mapi tile tiles)
  @ [ text ink ~bold:true ~room:500. (-390.) 80. "Today" ]
  @ List.mapi
      (fun k (late, l) ->
        text (if late then red else ink) ~bold:false ~room:780. (-390.)
          (50. -. (float_of_int k *. 24.)) l)
      today
  @ [ text grey ~bold:false ~room:900. (-390.)
        ((-.computer.screen.height /. 2.) +. 24.)
        ("m, t, p or a click opens a view; Ctrl+0 comes back here, "
         ^ "Ctrl+1 to 3 go to the others.") ]

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
    | Home -> home_view computer s
    | Mail -> Mail_window.view computer s.mail @ switcher_view computer s
    | Tasks -> Tasks_window.view computer s.tasks @ switcher_view computer s
    | People -> People_window.view computer s.people @ switcher_view computer s
  in
  let top = (computer.screen.height /. 2.) -. menu_bar in
  body
  @ [ rectangle (Gui.theme ()).face computer.screen.width menu_bar
      |> move 0. (top +. (menu_bar /. 2.)) ]
  (* (the menus last: an open one over the rest) *)
  @ Gui.draw ()
