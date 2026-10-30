(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See When.mli *)

let weekdays =
  [ ([ "sunday"; "sun"; "dimanche" ], 0); ([ "monday"; "mon"; "lundi" ], 1);
    ([ "tuesday"; "tue"; "mardi" ], 2); ([ "wednesday"; "wed"; "mercredi" ], 3);
    ([ "thursday"; "thu"; "jeudi" ], 4); ([ "friday"; "fri"; "vendredi" ], 5);
    ([ "saturday"; "sat"; "samedi" ], 6) ]

let months =
  [ [ "january"; "jan"; "janvier" ]; [ "february"; "feb"; "fevrier"; "février" ];
    [ "march"; "mar"; "mars" ]; [ "april"; "apr"; "avril" ]; [ "may"; "mai" ];
    [ "june"; "jun"; "juin" ]; [ "july"; "jul"; "juillet" ];
    [ "august"; "aug"; "aout"; "août" ];
    [ "september"; "sep"; "sept"; "septembre" ];
    [ "october"; "oct"; "octobre" ]; [ "november"; "nov"; "novembre" ];
    [ "december"; "dec"; "decembre"; "décembre" ] ]

let lookup (names : (string list * int) list) (w : string) : int option =
  List.find_map (fun (l, n) -> if List.mem w l then Some n else None) names

let month (w : string) : int option =
  lookup (List.mapi (fun i l -> (l, i + 1)) months) w

let today () : Civil.date =
  Civil.civil_from_days (int_of_float (Unix.gettimeofday () /. 86400.))

let parse ~(today : Civil.date) (words : string) : Civil.date option =
  let t = Civil.days_from_civil today in
  let plus n = Some (Civil.civil_from_days (t + n)) in
  (* the next [wday], 1 to 7 days on *)
  let next wday =
    let d = (wday - Civil.weekday t + 7) mod 7 in
    plus (if d = 0 then 7 else d)
  in
  let ws =
    List.filter (fun w -> w <> "")
      (String.split_on_char ' ' (String.lowercase_ascii (String.trim words)))
  in
  let ws = match ws with ("in" | "dans") :: rest -> rest | l -> l in
  let count n unit =
    match unit with
    | "day" | "days" | "jour" | "jours" -> plus n
    | "week" | "weeks" | "semaine" | "semaines" -> plus (7 * n)
    | "month" | "months" | "mois" -> Some (Civil.add_months today n)
    | _ -> None
  in
  (* a month's day, this year's, else next year's *)
  let on m d =
    let in_year y : Civil.date = { year = y; month = m; day = d } in
    let this = in_year today.year in
    if not (Civil.is_valid this) then None
    else if Civil.days_from_civil this >= t then Some this
    else Some (in_year (today.year + 1))
  in
  match ws with
  | [ ("today" | "aujourd'hui") ] -> plus 0
  | [ ("tomorrow" | "demain") ] -> plus 1
  | [ ("weekend" | "week-end") ] | [ "this"; "weekend" ] -> next 6
  | [ "next"; "week" ] | [ "la"; "semaine"; "prochaine" ] -> next 1
  | [ "next"; "month" ] | [ "le"; "mois"; "prochain" ] ->
      Some (Civil.add_months today 1)
  | [ w ] when lookup weekdays w <> None -> (
      match lookup weekdays w with Some d -> next d | None -> None)
  | [ w ] when Search.date w <> None -> Search.date w
  | [ n; unit ] when int_of_string_opt n <> None -> (
      match (int_of_string_opt n, month unit) with
      | Some d, Some m -> on m d
      | Some n, None -> count n unit
      | None, _ -> None)
  | [ m; d ] when month m <> None -> (
      match (month m, int_of_string_opt d) with
      | Some m, Some d -> on m d
      | _ -> None)
  | _ -> None

let ending ~(today : Civil.date) (line : string) : string * Civil.date option =
  let ws = List.filter (fun w -> w <> "") (String.split_on_char ' ' line) in
  let n = List.length ws in
  let first k = List.filteri (fun i _ -> i < k) ws in
  let last k = List.filteri (fun i _ -> i >= n - k) ws in
  (* the longest tail that is a day, a word at least left before it *)
  let rec try_ k =
    if k = 0 then (String.concat " " ws, None)
    else if k >= n then try_ (k - 1)
    else
      match parse ~today (String.concat " " (last k)) with
      | Some d ->
          let title =
            match List.rev (first (n - k)) with
            | w :: rest
              when rest <> []
                   && List.mem (String.lowercase_ascii w)
                        [ "by"; "on"; "due"; "pour" ] ->
                List.rev rest
            | l -> List.rev l
          in
          (String.concat " " title, Some d)
      | None -> try_ (k - 1)
  in
  try_ 4
