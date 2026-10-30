(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Events.mli *)

let minutes (s : string) : int option =
  match String.split_on_char ':' s with
  | [ h; m ] -> (
      match (int_of_string_opt h, int_of_string_opt m) with
      | Some h, Some m when h >= 0 && h < 24 && m >= 0 && m < 60 ->
          Some ((h * 60) + m)
      | _ -> None)
  | _ -> None

let clock (n : int) : string = Printf.sprintf "%d:%02d" (n / 60) (n mod 60)

let start (i : Item.t) : (Civil.date * int option) option =
  match String.split_on_char ' ' (String.trim (Item.field i "when")) with
  | [ d ] -> Option.map (fun d -> (d, None)) (Search.date d)
  | [ d; t ] -> Option.map (fun d -> (d, minutes t)) (Search.date d)
  | _ -> None

let between (items : Item.t list) ~(from : Civil.date) ~(upto : Civil.date) :
    (Civil.date * int option * Item.t) list =
  let all =
    List.concat_map
      (fun i ->
        if not (Item.has_stamp i "event") then []
        else
          match start i with
          | None -> []
          | Some (day, time) ->
              let days =
                match Ics.rule_of_string (Item.field i "repeat") with
                | Some r when Item.field i "repeat" <> "" ->
                    let at = match time with Some t -> t * 60 | None -> 0 in
                    Recur.occurrences ~at r ~start:day ~from ~upto
                | _ ->
                    let n = Civil.days_from_civil day in
                    if
                      n >= Civil.days_from_civil from
                      && n <= Civil.days_from_civil upto
                    then [ day ]
                    else []
              in
              (* (but those the series skips: except:) *)
              let except =
                String.split_on_char ' ' (Item.field i "except")
              in
              List.filter_map
                (fun d ->
                  if List.mem (Civil.to_string d) except then None
                  else Some (d, time, i))
                days)
      items
  in
  let key (d, t, _) =
    (Civil.days_from_civil d, match t with Some t -> t | None -> -1)
  in
  List.stable_sort (fun a b -> compare (key a) (key b)) all

(* a UTC moment at this place's clock (Zone): Google writes most times
 * in UTC *)
let local (zone : Zone.t) (m : Ics.moment) : Ics.moment =
  match m.time with
  | Some t when m.utc ->
      let u =
        (float_of_int (Civil.days_from_civil m.date) *. 86400.)
        +. float_of_int t
      in
      let date, minute = Zone.clock zone u in
      { date; time = Some (minute * 60); utc = false }
  | _ -> m

(* a uid as a file's name: no / in it *)
let safe (s : string) : string =
  String.map (fun c -> if c = '/' || c = ' ' then '-' else c) s

let of_ics (zone : Zone.t) ~(message : string) (text : string) : Item.t list =
  let cal = Ics.of_string text in
  let at (m : Ics.moment) =
    let m = local zone m in
    match m.time with
    | Some t -> Civil.to_string m.date ^ " " ^ clock (t / 60)
    | None -> Civil.to_string m.date
  in
  (* the dates a series skips: its EXDATEs, and those moved or cancelled
   * by an event of its UID with a RECURRENCE-ID *)
  let skipped (uid : string) : string list =
    List.concat_map
      (fun (e : Ics.event) ->
        if e.uid <> uid then []
        else
          (match e.recurrence_id with
          | Some r -> [ Civil.to_string (local zone r).date ]
          | None -> [])
          @ List.map (fun m -> Civil.to_string (local zone m).date) e.exdates)
      cal.events
  in
  List.filter_map
    (fun (e : Ics.event) ->
      if e.cancelled then None
      else
        let end_ =
          match e.end_ with
          | Some ({ time = Some _; _ } as m) -> (
              match (local zone m).time with
              | Some t -> [ ("end", clock (t / 60)) ]
              | None -> [])
          | _ -> []
        in
        let opt name v = if v = "" then [] else [ (name, v) ] in
        let id, repeat =
          match (e.recurrence_id, e.rrule) with
          | Some r, _ ->
              let day = Civil.to_string (local zone r).date in
              ("event:" ^ safe e.uid ^ "@" ^ day, [])
          | None, Some r ->
              ( "event:" ^ safe e.uid,
                ("repeat", Ics.rule_to_string r)
                :: opt "except" (String.concat " " (skipped e.uid)) )
          | None, None -> ("event:" ^ safe e.uid, [])
        in
        Some
          (Item.make ~id ~stamps:[ "event" ]
             (List.concat
                [ [ ("title", e.summary); ("when", at e.start) ]; end_; repeat;
                  opt "where" e.location; opt "re" message ])
             e.description))
    cal.events
