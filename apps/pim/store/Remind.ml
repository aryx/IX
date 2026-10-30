(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Remind.mli *)

let lead = 10

(* an event's minutes before, its remind: field's; None: "no" *)
let before (i : Item.t) : int option =
  match Item.field i "remind" with
  | "" -> Some lead
  | "no" -> None
  | s -> int_of_string_opt s

(* the reminders of [day], each its minute of the day (negative: the
 * day before's, an event just after midnight) *)
let of_day (items : Item.t list) (day : Civil.date) : (int * Item.t) list =
  let events =
    List.filter_map
      (fun (_, time, i) ->
        match (time, before i) with
        | Some t, Some b -> Some (t - b, i)
        | _ -> None)
      (Events.between items ~from:day ~upto:day)
  in
  (* a task's remind: "2026-11-03 9:00" *)
  let tasks =
    List.filter_map
      (fun i ->
        match String.split_on_char ' ' (Item.field i "remind") with
        | [ d; t ] when Item.has_stamp i "task" && Item.field i "done" = "" -> (
            match (Search.date d, Events.minutes t) with
            | Some d', Some m when d' = day -> Some (m, i)
            | _ -> None)
        | _ -> None)
      items
  in
  events @ tasks

let due (items : Item.t list) (day : Civil.date) ~(from : int) ~(upto : int) :
    (int * Item.t) list =
  let next =
    Civil.civil_from_days (Civil.days_from_civil day + 1)
  in
  let all =
    of_day items day
    @ List.map (fun (m, i) -> (m + 1440, i)) (of_day items next)
  in
  List.stable_sort
    (fun (a, _) (b, _) -> compare a b)
    (List.filter (fun (m, _) -> m >= from && m < upto) all)

let say (i : Item.t) : string =
  match Events.start i with
  | Some (_, Some t) when Item.has_stamp i "event" ->
      Search.title i ^ " at " ^ Events.clock t
  | _ -> Search.title i
