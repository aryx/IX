(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Capture.mli *)

type event = {
  title : string;
  day : Civil.date;
  time : int option;
  repeat : string;
  with_ : string list;
}

(* "12:30", "12h30", "12h", "4pm", "11am", "noon", "midi" *)
let time_of (w : string) : int option =
  let w = String.lowercase_ascii w in
  let n = String.length w in
  let hm h m =
    match (int_of_string_opt h, int_of_string_opt m) with
    | Some h, Some m when h >= 0 && h < 24 && m >= 0 && m < 60 ->
        Some ((h * 60) + m)
    | _ -> None
  in
  let ends s =
    let k = String.length s in
    n > k && String.sub w (n - k) k = s
  in
  if w = "noon" || w = "midi" then Some (12 * 60)
  else if String.contains w ':' then Events.minutes w
  else if String.contains w 'h' then
    match String.split_on_char 'h' w with
    | [ h; "" ] -> hm h "0"
    | [ h; m ] -> hm h m
    | _ -> None
  else if ends "am" || ends "pm" then
    match int_of_string_opt (String.sub w 0 (n - 2)) with
    | Some h when h >= 1 && h <= 12 ->
        let h = h mod 12 in
        Some ((if ends "pm" then h + 12 else h) * 60)
    | _ -> None
  else None

let weekdays =
  [ ([ "sunday"; "dimanche" ], "SU", 0); ([ "monday"; "lundi" ], "MO", 1);
    ([ "tuesday"; "mardi" ], "TU", 2); ([ "wednesday"; "mercredi" ], "WE", 3);
    ([ "thursday"; "jeudi" ], "TH", 4); ([ "friday"; "vendredi" ], "FR", 5);
    ([ "saturday"; "samedi" ], "SA", 6) ]

(* "every monday": the rule, and its first day from [today] (today if
 * it is one) *)
let repeat_of ~(today : Civil.date) (w : string) : (string * Civil.date) option =
  let t = Civil.days_from_civil today in
  let w = String.lowercase_ascii w in
  let plain f = Some ("FREQ=" ^ f, today) in
  match w with
  | "day" | "jour" -> plain "DAILY"
  | "week" | "semaine" -> plain "WEEKLY"
  | "month" | "mois" -> plain "MONTHLY"
  | "year" | "an" | "année" -> plain "YEARLY"
  | _ ->
      List.find_map
        (fun (names, code, wd) ->
          if List.exists (fun n -> n = w || String.sub n 0 3 = w) names then
            let d = (wd - Civil.weekday t + 7) mod 7 in
            Some ("FREQ=WEEKLY;BYDAY=" ^ code, Civil.civil_from_days (t + d))
          else None)
        weekdays

let event ~(today : Civil.date) ~(people : Item.t list) (line : string) :
    event =
  let ws = List.filter (fun w -> w <> "") (String.split_on_char ' ' line) in
  (* the time, and an "at" before it *)
  let rec cut_time acc l =
    match l with
    | [] -> (List.rev acc, None)
    | w :: rest -> (
        match time_of w with
        | Some t ->
            let acc =
              match acc with
              | ("at" | "à" | "a") :: before -> before
              | _ -> acc
            in
            (List.rev acc @ rest, Some t)
        | None -> cut_time (w :: acc) rest)
  in
  let ws, time = cut_time [] ws in
  (* the repeat *)
  let rec cut_repeat acc l =
    match l with
    | ("every" | "chaque") :: w :: rest -> (
        match repeat_of ~today w with
        | Some r -> (List.rev acc @ rest, Some r)
        | None -> cut_repeat (w :: "every" :: acc) rest)
    | w :: rest -> cut_repeat (w :: acc) rest
    | [] -> (List.rev acc, None)
  in
  let ws, repeat = cut_repeat [] ws in
  let title, day = When.ending ~today (String.concat " " ws) in
  let day, repeat =
    match (day, repeat) with
    | Some d, Some (r, _) -> (d, r)
    | Some d, None -> (d, "")
    | None, Some (r, first) -> (first, r)
    | None, None -> (today, "")
  in
  (* the people: the word after with or avec *)
  let rec names l =
    match l with
    | ("with" | "avec") :: w :: rest -> String.lowercase_ascii w :: names rest
    | _ :: rest -> names rest
    | [] -> []
  in
  let who (name : string) : string option =
    List.find_map
      (fun c ->
        let first =
          match String.split_on_char ' ' (Item.field c "name") with
          | f :: _ -> String.lowercase_ascii f
          | [] -> ""
        in
        let addressed e =
          String.length e >= String.length name
          && String.sub e 0 (String.length name) = name
        in
        if first = name || List.exists addressed (People.emails c) then
          Some (Item.id c)
        else None)
      people
  in
  { title; day; time; repeat;
    with_ = List.filter_map who (names (String.split_on_char ' ' title)) }

let to_item ~(id : string) (e : event) : Item.t =
  let when_ =
    Civil.to_string e.day
    ^ match e.time with Some t -> " " ^ Events.clock t | None -> ""
  in
  let opt name v = if v = "" then [] else [ (name, v) ] in
  Item.make ~id ~stamps:[ "event" ]
    (List.concat
       [ [ ("title", e.title); ("when", when_) ]; opt "repeat" e.repeat;
         opt "with" (String.concat " " e.with_) ])
    ""
