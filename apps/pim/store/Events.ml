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
              List.map (fun d -> (d, time, i)) days)
      items
  in
  let key (d, t, _) =
    (Civil.days_from_civil d, match t with Some t -> t | None -> -1)
  in
  List.stable_sort (fun a b -> compare (key a) (key b)) all

let of_ics ~(message : string) (text : string) : Item.t list =
  let cal = Ics.of_string text in
  List.map
    (fun (e : Ics.event) ->
      let at (m : Ics.moment) =
        match m.time with
        | Some t -> Civil.to_string m.date ^ " " ^ clock (t / 60)
        | None -> Civil.to_string m.date
      in
      let end_ =
        match e.end_ with
        | Some { time = Some t; _ } -> [ ("end", clock (t / 60)) ]
        | _ -> []
      in
      let opt name v = if v = "" then [] else [ (name, v) ] in
      (* (a uid is the sender's, a file's name here: no / in it) *)
      let uid = String.map (fun c -> if c = '/' || c = ' ' then '-' else c) e.uid in
      Item.make ~id:("event:" ^ uid) ~stamps:[ "event" ]
        (List.concat
           [ [ ("title", e.summary); ("when", at e.start) ]; end_;
             (match e.rrule with
             | Some r -> [ ("repeat", Ics.rule_to_string r) ]
             | None -> []);
             opt "where" e.location; opt "re" message ])
        e.description)
    cal.events
