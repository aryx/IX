(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Calendar_window.mli *)

open Playground
open Pim_look

type caps = Mail_window.caps

(*****************************************************************************)
(* The model *)
(*****************************************************************************)

type span = Day | Week | Month
type mode = Browsing | Asking

type model = {
  span : span;
  cursor : Civil.date; (* the day selected *)
  today : Civil.date;
  (* the occurrences of the days shown *)
  shown : (Civil.date * int option * Item.t) list;
  selected : int; (* in the day's list *)
  mode : mode;
  field : string; (* an event typed *)
  status : string;
  held : string Set_.t;
}

let store (caps : caps) : Items.t = Items.at (Items.place caps)

let days (d : Civil.date) : int = Civil.days_from_civil d
let date (n : int) : Civil.date = Civil.civil_from_days n

(* the week's Monday (ISO 8601's week, Europe's) *)
let monday (d : Civil.date) : Civil.date =
  date (days d - ((Civil.weekday (days d) + 6) mod 7))

(* the month's grid: from the Monday of its first week, six weeks *)
let grid_start (d : Civil.date) : Civil.date = monday { d with day = 1 }

let range (m : model) : Civil.date * Civil.date =
  match m.span with
  | Day -> (m.cursor, m.cursor)
  | Week -> (monday m.cursor, date (days (monday m.cursor) + 6))
  | Month -> (grid_start m.cursor, date (days (grid_start m.cursor) + 41))

let load (caps : caps) (m : model) : model =
  let from, upto = range m in
  let shown = Events.between (Items.all caps (store caps)) ~from ~upto in
  let n = List.length (List.filter (fun (d, _, _) -> d = m.cursor) shown) in
  { m with shown; selected = max 0 (min m.selected (n - 1)) }

let initial (caps : caps) (flags : Playground.flags) : model =
  let today =
    match List.assoc_opt "today" flags with
    | Some d -> (
        match Search.date d with Some d -> d | None -> When.today caps)
    | None -> When.today caps
  in
  load caps
    { span = Week; cursor = today; today; shown = []; selected = 0;
      mode = Browsing; field = ""; status = ""; held = Set_.empty }

let refresh (caps : caps) (keys : string Set_.t) (m : model) : model =
  load caps { m with held = keys }

let on (m : model) (d : Civil.date) : (Civil.date * int option * Item.t) list =
  List.filter (fun (d', _, _) -> d' = d) m.shown

(* the event [id]'s day, it selected *)
let show (caps : caps) (m : model) (id : string) : model =
  match Option.bind (Items.find caps (store caps) id) Events.start with
  | None -> { m with status = id ^ ": not an event" }
  | Some (d, _) ->
      let m = load caps { m with span = Day; cursor = d; selected = 0 } in
      let rec find k l =
        match l with
        | [] -> 0
        | (_, _, i) :: rest -> if Item.id i = id then k else find (k + 1) rest
      in
      { m with selected = find 0 (on m d); status = "" }

(*****************************************************************************)
(* What the keys and the menus do *)
(*****************************************************************************)

type command =
  | Create
  | Next_period
  | Previous_period
  | Today
  | Day_
  | Week_
  | Month_
  | Open_
  | Back
  | Get

let menus : (string * (string * command) list) list =
  [ ( "Event",
      [ ("New Event...  (c)", Create); ("Open  (o)", Open_);
        ("Back  (u)", Back); ("Get the Calendars  (g)", Get) ] );
    ( "View",
      [ ("Day  (d)", Day_); ("Week  (w)", Week_); ("Month  (m)", Month_);
        ("Today  (t)", Today); ("Next  (j)", Next_period);
        ("Previous  (k)", Previous_period) ] ) ]

let made = ref 0

let create (caps : caps) (m : model) (line : string) : model =
  let st = store caps in
  let people = People.contacts (Items.all caps st) in
  (* (the words' days from today, as the line says them) *)
  let e = Capture.event ~today:m.today ~people line in
  if String.trim e.title = "" then m
  else begin
    incr made;
    let id = Printf.sprintf "event:%.0f.%d" (Unix.gettimeofday ()) !made in
    Items.save caps st (Capture.to_item ~id e);
    let m = load caps { m with cursor = e.day } in
    { m with
      status =
        e.title ^ ", " ^ Civil.to_string e.day
        ^ (match e.time with Some t -> " " ^ Events.clock t | None -> "") }
  end

let step (caps : caps) (m : model) (by : int) : model =
  load caps { m with cursor = date (days m.cursor + by); selected = 0 }

let command (caps : caps) (m : model) (c : command) : model * go option =
  match c with
  | Get -> (
      (* Google's, read (Calendars): the store's calendars file's *)
      match Calendars.sources caps with
      | Error e -> ({ m with status = e }, None)
      | Ok [] ->
          ({ m with status = "no calendars: see Calendars.mli" }, None)
      | Ok l ->
          let said =
            List.map
              (fun (s : Calendars.source) ->
                match Calendars.fetch caps s with
                | Ok (saved, removed) ->
                    Printf.sprintf "%s %d new, %d gone" s.name saved removed
                | Error e -> e)
              l
          in
          (load caps { m with status = String.concat "; " said }, None))
  | Create -> ({ m with mode = Asking; field = ""; status = "" }, None)
  | Today -> (load caps { m with cursor = m.today; selected = 0 }, None)
  | Day_ -> (load caps { m with span = Day; selected = 0 }, None)
  | Week_ -> (load caps { m with span = Week }, None)
  | Month_ -> (load caps { m with span = Month }, None)
  | Next_period | Previous_period -> (
      let sign = if c = Next_period then 1 else -1 in
      match m.span with
      | Day -> (step caps m sign, None)
      | Week -> (step caps m (7 * sign), None)
      | Month ->
          ( load caps { m with cursor = Civil.add_months m.cursor sign },
            None ))
  | Open_ -> (
      match m.span with
      | Week | Month -> (load caps { m with span = Day; selected = 0 }, None)
      | Day -> (
          match List.nth_opt (on m m.cursor) m.selected with
          (* (an invitation: its mail) *)
          | Some (_, _, i) when Item.field i "re" <> "" ->
              (m, Some (Item (Item.field i "re")))
          | _ -> (m, None)))
  | Back -> (load caps { m with span = Week }, None)

let update (caps : caps) (computer : computer) (m : model) : model * go option =
  let keys = computer.keyboard.keys in
  let pressed name = Set_.mem name keys && not (Set_.mem name m.held) in
  let menu = chosen computer ~first:1 menus in
  let m, go =
    match m.mode with
    | Asking ->
        if pressed "Escape" then ({ m with mode = Browsing; field = "" }, None)
        else if pressed "Enter" then
          (create caps { m with mode = Browsing; field = "" } m.field, None)
        else if pressed "Backspace" then
          ({ m with field = without_last m.field }, None)
        else ({ m with field = m.field ^ printable computer.keyboard.typed }, None)
    | Browsing when Gui.modal () -> (m, None)
    | Browsing -> (
        let key =
          if pressed "c" then Some Create
          else if pressed "j" then Some Next_period
          else if pressed "k" then Some Previous_period
          else if pressed "t" then Some Today
          else if pressed "d" then Some Day_
          else if pressed "w" then Some Week_
          else if pressed "m" then Some Month_
          else if pressed "o" || pressed "Enter" then Some Open_
          else if pressed "u" || pressed "Escape" then Some Back
          else if pressed "g" then Some Get
          else None
        in
        match (menu, key) with
        | Some c, _ | None, Some c -> command caps m c
        | None, None ->
            (* the arrows: a day, a week; in a day, its events *)
            let n = List.length (on m m.cursor) in
            if m.span = Day && pressed "ArrowDown" then
              ({ m with selected = min (n - 1) (m.selected + 1) }, None)
            else if m.span = Day && pressed "ArrowUp" then
              ({ m with selected = max 0 (m.selected - 1) }, None)
            else if pressed "ArrowRight" then (step caps m 1, None)
            else if pressed "ArrowLeft" then (step caps m (-1), None)
            else if pressed "ArrowDown" then (step caps m 7, None)
            else if pressed "ArrowUp" then (step caps m (-7), None)
            else (m, None))
  in
  ({ m with held = keys }, go)

(*****************************************************************************)
(* The picture *)
(*****************************************************************************)

let short_weekdays = [ "Mon"; "Tue"; "Wed"; "Thu"; "Fri"; "Sat"; "Sun" ]

(* "12:30 lunch", or "lunch" for a day's event *)
let line (t : int option) (i : Item.t) : string =
  match t with Some t -> Events.clock t ^ " " ^ title i | None -> title i

let light = rgb 218 220 224

let view (computer : computer) (m : model) : shape list =
  let a = area computer in
  let bottom = (-.computer.screen.height /. 2.) +. 10. in
  let top = a.top -. bar in
  let title_ =
    match (m.mode, m.span) with
    | Asking, _ -> "an event: " ^ m.field ^ "_"
    | _, Day ->
        Printf.sprintf "%s %d %s %d"
          (Civil.weekday_name (Civil.weekday (days m.cursor)))
          m.cursor.day
          (Civil.month_name m.cursor.month)
          m.cursor.year
    | _, Week ->
        let d = monday m.cursor in
        Printf.sprintf "Week of %d %s %d" d.day (Civil.month_name d.month)
          d.year
    | _, Month ->
        Printf.sprintf "%s %d" (Civil.month_name m.cursor.month) m.cursor.year
  in
  let right =
    if m.status <> "" then m.status
    else count (List.length m.shown) "event"
  in
  (* a cell: its box's top left, its width and height; its day's number
   * and its events' lines *)
  let cell ~(x : float) ~(y : float) ~(w : float) ~(h : float) ~(head : string)
      (d : Civil.date) : shape list =
    let is_cursor = d = m.cursor and is_today = d = m.today in
    let grey_day = m.span = Month && d.month <> m.cursor.month in
    (* (a week's events wrapped in their column, a month's cut) *)
    let lines =
      List.concat_map
        (fun (_, t, i) ->
          if m.span = Week then wrap (w -. 12.) (line t i) else [ line t i ])
        (on m d)
    in
    let fits = max 0 (int_of_float ((h -. 30.) /. 20.)) in
    let lines =
      if List.length lines <= fits then lines
      else
        List.filteri (fun k _ -> k < fits - 1) lines
        @ [ Printf.sprintf "+%d more" (List.length lines - fits + 1) ]
    in
    (if is_cursor then
       [ rectangle (rgb 232 240 254) w h |> move (x +. (w /. 2.)) (y -. (h /. 2.)) ]
     else [])
    @ [ rectangle light w 1. |> move (x +. (w /. 2.)) y;
        rectangle light 1. h |> move x (y -. (h /. 2.));
        text
          (if is_today then blue else if grey_day then light else grey)
          ~bold:is_today ~room:(w -. 8.) (x +. 6.) (y -. 20.) head ]
    @ List.mapi
        (fun k l ->
          text (if grey_day then grey else ink) ~bold:false ~room:(w -. 10.)
            (x +. 6.) (y -. 42. -. (float_of_int k *. 20.)) l)
        lines
  in
  let main =
    match m.span with
    | Week ->
        let w = (a.room +. 16.) /. 7. in
        List.concat
          (List.init 7 (fun k ->
               let d = date (days (monday m.cursor) + k) in
               cell ~x:(a.x0 -. 8. +. (float_of_int k *. w)) ~y:top ~w
                 ~h:(top -. bottom)
                 ~head:(Printf.sprintf "%s %d" (List.nth short_weekdays k) d.day)
                 d))
    | Month ->
        let w = (a.room +. 16.) /. 7. in
        let head_h = 24. in
        let h = (top -. bottom -. head_h) /. 6. in
        List.mapi
          (fun k name ->
            text grey ~bold:false ~room:w
              (a.x0 -. 2. +. (float_of_int k *. w)) (top -. 17.) name)
          short_weekdays
        @ List.concat
            (List.init 42 (fun k ->
                 let d = date (days (grid_start m.cursor) + k) in
                 cell
                   ~x:(a.x0 -. 8. +. (float_of_int (k mod 7) *. w))
                   ~y:(top -. head_h -. (float_of_int (k / 7) *. h))
                   ~w ~h ~head:(string_of_int d.day) d))
    | Day ->
        let events = on m m.cursor in
        if events = [] then
          [ text grey ~bold:false ~room:a.room a.x0 (row_y a 0)
              "Nothing this day: c adds an event (lunch with alice 12:30)." ]
        else
          let rows =
            List.concat
              (List.mapi
                 (fun k (_, t, i) ->
                   let y = row_y a k in
                   (if k = m.selected then [ selected a y ] else [])
                   @ [ text grey ~bold:false ~room:90. a.x0 y
                         (match t with Some t -> Events.clock t | None -> "all day");
                       text ink ~bold:false ~room:(a.room -. 100.) (a.x0 +. 100.)
                         y (title i) ])
                 events)
          in
          (* the selected one's details under the list *)
          let details =
            match List.nth_opt events m.selected with
            | None -> []
            | Some (_, _, i) ->
                List.filter_map
                  (fun (name, label) ->
                    match Item.field i name with
                    | "" -> None
                    | v -> Some (label ^ v))
                  [ ("end", "until "); ("where", "where: ");
                    ("repeat", "repeats: "); ("with", "with: ");
                    ("re", "from the mail: o opens it, ") ]
                @ wrap a.room (String.trim i.body)
          in
          let k0 = List.length events + 1 in
          rows
          @ List.mapi
              (fun k l ->
                text grey ~bold:false ~room:a.room a.x0 (row_y a (k0 + k)) l)
              details
  in
  (rectangle white computer.screen.width computer.screen.height
   :: title_bar computer title_ right)
  @ sidebar a
      [ ("Day", m.span = Day); ("Week", m.span = Week);
        ("Month", m.span = Month) ]
  @ main
