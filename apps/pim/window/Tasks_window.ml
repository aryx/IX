(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Tasks_window.mli *)

open Playground
open Pim_look

type caps = Mail_window.caps

(*****************************************************************************)
(* The model *)
(*****************************************************************************)

type shown = To_do | Done
type asking = New | Due | Until
type mode = Browsing | Page | Asking of asking

type model = {
  shown : shown;
  tasks : Item.t list; (* the list shown's *)
  snoozed : int; (* the tasks to do put away until a later day *)
  today : Civil.date;
  selected : int;
  mode : mode;
  field : string; (* what is typed after a question *)
  status : string;
  held : string Set_.t;
}

let store (caps : caps) : Items.t = Items.at (Items.place caps)

let days (d : Civil.date option) : int =
  match d with Some d -> Civil.days_from_civil d | None -> max_int

(* the tasks to do, by their day, those without one last, those
 * snoozed to a later day left out (plan_pim.md, idea 5); or those
 * done, the last done first *)
let load (caps : caps) (m : model) : model =
  let items = Items.all caps (store caps) in
  let tasks = List.filter (fun i -> Item.has_stamp i "task") items in
  let later (i : Item.t) =
    days (Search.date (Item.field i "until")) <> max_int
    && days (Search.date (Item.field i "until"))
       > Civil.days_from_civil m.today
  in
  let to_do = List.filter (fun i -> Item.field i "done" = "") tasks in
  let l =
    match m.shown with
    | To_do ->
        List.stable_sort
          (fun a b -> compare (days (Search.day a)) (days (Search.day b)))
          (List.filter (fun i -> not (later i)) to_do)
    | Done ->
        List.stable_sort
          (fun a b -> compare (Item.field b "done") (Item.field a "done"))
          (List.filter (fun i -> Item.field i "done" <> "") tasks)
  in
  { m with
    tasks = l;
    snoozed = List.length (List.filter later to_do);
    selected = max 0 (min m.selected (List.length l - 1)) }

let initial (caps : caps) (flags : Playground.flags) : model =
  let today =
    match List.assoc_opt "today" flags with
    | Some d -> (
        match Search.date d with Some d -> d | None -> When.today ())
    | None -> When.today ()
  in
  load caps
    { shown = To_do; tasks = []; snoozed = 0; today; selected = 0;
      mode = Browsing; field = ""; status = ""; held = Set_.empty }

let refresh (caps : caps) (keys : string Set_.t) (m : model) : model =
  load caps { m with held = keys; mode = Browsing }

(* the task [id]'s page, in the list it is in *)
let show (caps : caps) (m : model) (id : string) : model =
  match Items.find caps (store caps) id with
  | None -> { m with status = id ^ ": not in the store" }
  | Some i -> (
      let shown = if Item.field i "done" = "" then To_do else Done in
      let m = load caps { m with shown; selected = 0 } in
      let rec find k l =
        match l with
        | [] -> None
        | t :: rest -> if Item.id t = id then Some k else find (k + 1) rest
      in
      match find 0 m.tasks with
      | Some k -> { m with selected = k; mode = Page; status = "" }
      | None -> { m with status = id ^ ": snoozed" })

(*****************************************************************************)
(* What the keys and the menus do *)
(*****************************************************************************)

type command =
  | New_
  | Open_
  | Back
  | Done_
  | Due_
  | Snooze_
  | Next
  | Previous
  | To_do_list
  | Done_list

let menus : (string * (string * command) list) list =
  [ ( "Task",
      [ ("New Task...  (n)", New_); ("Open  (o)", Open_);
        ("Back to List  (u)", Back); ("Mark Done  (x)", Done_);
        ("Due...  (d)", Due_); ("Snooze...  (z)", Snooze_);
        ("Next  (j)", Next); ("Previous  (k)", Previous) ] );
    ("List", [ ("To Do  (Tab)", To_do_list); ("Done  (Tab)", Done_list) ]) ]

let current (m : model) : Item.t option = List.nth_opt m.tasks m.selected

let made = ref 0

(* a task captured, its id the time and a count *)
let capture (caps : caps) (m : model) (line : string) : model =
  let title, due = When.ending ~today:m.today line in
  if String.trim title = "" then m
  else begin
    incr made;
    let id = Printf.sprintf "task:%.0f.%d" (Unix.gettimeofday ()) !made in
    let due =
      match due with Some d -> [ ("due", Mail_sync.day d) ] | None -> []
    in
    Items.save caps (store caps)
      (Item.make ~id ~stamps:[ "task" ] (("title", title) :: due) "");
    load caps
      { m with shown = To_do; status = "a task: " ^ title }
  end

(* a field of the selected task set, the list read again *)
let set (caps : caps) (m : model) (name : string) (value : string)
    (status : string) : model =
  match current m with
  | None -> m
  | Some i ->
      let i =
        if value = "" then Mail.remove name i else Mail.set name value i
      in
      Items.save caps (store caps) i;
      load caps { m with mode = Browsing; status = status ^ title i }

let command (caps : caps) (m : model) (c : command) : model * go option =
  match c with
  | New_ -> ({ m with mode = Asking New; field = ""; status = "" }, None)
  | Open_ -> (
      match current m with
      | None -> (m, None)
      (* (a message: the mail shows it) *)
      | Some i when Item.has_stamp i "message" -> (m, Some (Item (Item.id i)))
      | Some _ -> ({ m with mode = Page }, None))
  | Back -> ({ m with mode = Browsing }, None)
  | Done_ -> (
      match (current m, m.shown) with
      | None, _ -> (m, None)
      | Some _, To_do -> (set caps m "done" (Mail_sync.day m.today) "done: ", None)
      | Some _, Done -> (set caps m "done" "" "to do again: ", None))
  | Due_ when current m <> None ->
      ({ m with mode = Asking Due; field = ""; status = "" }, None)
  | Snooze_ when current m <> None && m.shown = To_do ->
      ({ m with mode = Asking Until; field = ""; status = "" }, None)
  | Due_ | Snooze_ -> (m, None)
  | Next ->
      ({ m with selected = min (List.length m.tasks - 1) (m.selected + 1) }, None)
  | Previous -> ({ m with selected = max 0 (m.selected - 1) }, None)
  | To_do_list ->
      (load caps { m with shown = To_do; selected = 0; mode = Browsing }, None)
  | Done_list ->
      (load caps { m with shown = Done; selected = 0; mode = Browsing }, None)

let update (caps : caps) (computer : computer) (m : model) : model * go option =
  let keys = computer.keyboard.keys in
  let pressed name = Set_.mem name keys && not (Set_.mem name m.held) in
  let menu = chosen computer ~first:1 menus in
  let m, go =
    match m.mode with
    | Asking a ->
        if pressed "Escape" then ({ m with mode = Browsing; field = "" }, None)
        else if pressed "Enter" then
          let m' = { m with field = ""; mode = Browsing } in
          match a with
          | New -> (capture caps m' m.field, None)
          | Due | Until -> (
              match When.parse ~today:m.today m.field with
              | None ->
                  ( { m' with
                      status = m.field ^ ": not a day (monday, in 3 days)" },
                    None )
              | Some d when a = Due ->
                  let m = set caps m' "due" (Mail_sync.day d) "" in
                  ({ m with status = "due " ^ Mail_sync.day d }, None)
              | Some d ->
                  let m = set caps m' "until" (Mail_sync.day d) "" in
                  ({ m with status = "snoozed until " ^ Mail_sync.day d }, None))
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
          else if pressed "x" then Some Done_
          else if pressed "d" then Some Due_
          else if pressed "z" then Some Snooze_
          else if pressed "Tab" then
            Some (if m.shown = To_do then Done_list else To_do_list)
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
  let h = computer.screen.height in
  let a = area computer in
  let title_ =
    match m.mode with
    | Asking New -> "a task: " ^ m.field ^ "_"
    | Asking Due -> "due: " ^ m.field ^ "_"
    | Asking Until -> "snooze until: " ^ m.field ^ "_"
    | Page -> (match current m with Some i -> title i | None -> "")
    | Browsing -> if m.shown = To_do then "To Do" else "Done"
  in
  let right =
    if m.status <> "" then m.status
    else if m.shown = To_do && m.snoozed > 0 then
      count (List.length m.tasks) "task"
      ^ Printf.sprintf ", %d snoozed" m.snoozed
    else count (List.length m.tasks) "task"
  in
  let main =
    match (m.mode, current m) with
    | Page, Some i ->
        (* the task: its fields, its text, what names it *)
        let fields =
          List.filter_map
            (fun name ->
              match Item.field i name with
              | "" -> None
              | v -> Some (name ^ ": " ^ v))
            [ "due"; "until"; "done"; "stamp" ]
        in
        let lines =
          fields @ [ "" ] @ wrap a.room (String.trim i.body)
        in
        List.mapi
          (fun k l ->
            text (if k < List.length fields then grey else ink) ~bold:false
              ~room:a.room a.x0 (row_y a k) l)
          lines
    | _ when m.tasks = [] ->
        [ text grey ~bold:false ~room:a.room a.x0 (row_y a 0)
            (if m.shown = To_do then
               "Nothing to do: n adds a task, t in Mail makes one of a message."
             else "Nothing done yet.") ]
    | _ ->
        let fits = int_of_float ((h -. bar -. 12.) /. row) in
        let first = max 0 (m.selected - fits + 1) in
        List.concat
          (List.mapi
             (fun i (t : Item.t) ->
               if i < first || i >= first + fits then []
               else
                 let y = row_y a (i - first) in
                 let day =
                   if m.shown = Done then Item.field t "done"
                   else Item.field t "due"
                 in
                 let late =
                   m.shown = To_do
                   && days (Search.day t) < Civil.days_from_civil m.today
                 in
                 let mail =
                   if Item.has_stamp t "message" then "  (mail)" else ""
                 in
                 (if i = m.selected then [ selected a y ] else [])
                 @ [ text (if late then red else grey) ~bold:false
                       ~room:(width "2026-10-30" +. 4.) a.x0 y
                       (if day = "" then "-" else day);
                     text ink ~bold:false ~room:(a.room -. 130.) (a.x0 +. 130.)
                       y (title t ^ mail) ])
             m.tasks)
  in
  (rectangle white computer.screen.width h :: title_bar computer title_ right)
  @ sidebar a [ ("To Do", m.shown = To_do); ("Done", m.shown = Done) ]
  @ main
