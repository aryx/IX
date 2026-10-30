(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Detect.mli *)

type kind =
  | Day of Civil.date * int option
  | Amount of Money.cents
  | Address of string * string

type found = { said : string; kind : kind; line : string }

(* a word as written, and as read: its punctuation around taken off *)
let core (w : string) : string =
  let strip c = String.contains ".,;:!?()\"'<>[]" c in
  let n = String.length w in
  let rec first i = if i < n && strip w.[i] then first (i + 1) else i in
  let rec last j = if j > 0 && strip w.[j - 1] then last (j - 1) else j in
  let i = first 0 and j = last n in
  if i >= j then "" else String.sub w i (j - i)

let is_digit (c : char) : bool = c >= '0' && c <= '9'

(* where [sub] begins in [s] *)
let index (s : string) (sub : string) : int option =
  let n = String.length s and k = String.length sub in
  let rec go i =
    if i + k > n then None
    else if String.sub s i k = sub then Some i
    else go (i + 1)
  in
  go 0

(* "1,937.60", "62,40", "1.000,50", "12": the last separator followed
 * by two digits the cents', the others thousands' *)
let cents_of (s : string) : int option =
  let n = String.length s in
  if
    n = 0
    || (not (String.for_all (fun c -> is_digit c || c = ',' || c = '.') s))
    || (not (is_digit s.[0]))
    || not (is_digit s.[n - 1])
  then None
  else
    let digits t =
      String.concat ""
        (String.split_on_char ','
           (String.concat "" (String.split_on_char '.' t)))
    in
    let decimal = n >= 3 && (s.[n - 3] = '.' || s.[n - 3] = ',') in
    let whole = if decimal then String.sub s 0 (n - 3) else s in
    let cents = if decimal then String.sub s (n - 2) 2 else "00" in
    match (int_of_string_opt (digits whole), int_of_string_opt cents) with
    | Some w, Some c -> Some ((w * 100) + c)
    | _ -> None

let currencies =
  [ "$"; "€"; "£"; "eur"; "usd"; "gbp"; "euros"; "euro"; "dollars" ]

(* "$62.40", "62,40€", "€12": a sign stuck to the number *)
let stuck (w : string) : int option =
  let lw = String.lowercase_ascii w in
  List.find_map
    (fun c ->
      let k = String.length c and n = String.length lw in
      if n > k && String.sub lw 0 k = c then cents_of (String.sub w k (n - k))
      else if n > k && String.sub lw (n - k) k = c then
        cents_of (String.sub w 0 (n - k))
      else None)
    [ "$"; "€"; "£" ]

(* a day's words alone, without a number: few, so that "sun" or "may"
 * in a sentence are no day *)
let day_words =
  [ "today"; "tomorrow"; "aujourd'hui"; "demain"; "monday"; "tuesday";
    "wednesday"; "thursday"; "friday"; "saturday"; "sunday"; "lundi"; "mardi";
    "mercredi"; "jeudi"; "vendredi"; "samedi"; "dimanche" ]

let in_line ~(today : Civil.date) (line : string) : found list =
  let words =
    Array.of_list
      (List.filter (fun w -> w <> "") (String.split_on_char ' ' line))
  in
  let n = Array.length words in
  let cores = Array.map core words in
  let lower k = String.lowercase_ascii cores.(k) in
  (* the words from i to j as written, less the punctuation before the
   * first's core and after the last's: "(tuesday 12:30)." *)
  let said i j =
    let s = String.concat " " (Array.to_list (Array.sub words i (j - i))) in
    let start = match index words.(i) cores.(i) with Some p -> p | None -> 0 in
    let last = words.(j - 1) and c = cores.(j - 1) in
    let stop =
      match index last c with
      | Some p -> String.length last - p - String.length c
      | None -> 0
    in
    String.sub s start (String.length s - start - stop)
  in
  let found = ref [] in
  let add f = found := f :: !found in
  let k = ref 0 in
  while !k < n do
    let i = !k in
    (* a day: the longest of 3, 2, 1 words When reads *)
    let day =
      List.find_map
        (fun len ->
          if i + len > n then None
          else
            let phrase =
              String.concat " " (List.init len (fun d -> lower (i + d)))
            in
            let single_ok =
              len > 1 || List.mem phrase day_words
              || (String.length phrase >= 8 && is_digit phrase.[0])
            in
            if not single_ok then None
            else
              match When.parse ~today phrase with
              | Some d -> Some (len, d)
              | None -> None)
        [ 3; 2; 1 ]
    in
    match day with
    | Some (len, d) ->
        (* a time after it: "tuesday 12:30", "nov 5 at 4pm" *)
        let j = i + len in
        let j' =
          if j < n && (lower j = "at" || lower j = "à") then j + 1 else j
        in
        let time, upto =
          if j' < n then
            match Capture.time_of (lower j') with
            | Some t -> (Some t, j' + 1)
            | None -> (None, j)
          else (None, j)
        in
        add { said = said i upto; kind = Day (d, time); line };
        k := upto
    | None -> (
        let w = cores.(i) in
        let amount =
          match stuck w with
          | Some c -> Some (c, i + 1, i)
          | None -> (
              match cents_of w with
              | Some c when i + 1 < n && List.mem (lower (i + 1)) currencies ->
                  Some (c, i + 2, i)
              | Some c when i > 0 && List.mem (lower (i - 1)) currencies ->
                  Some (c, i + 1, i - 1)
              | _ -> None)
        in
        match amount with
        | Some (c, upto, from) ->
            add { said = said from upto; kind = Amount c; line };
            k := upto
        | None ->
            (match String.index_opt w '@' with
            | Some p when p > 0 && p < String.length w - 1 ->
                (* "Dan Brown <dan@ix>": the capitalized words before *)
                let rec name j acc =
                  if j >= 0 && j >= i - 3 && cores.(j) <> ""
                     && Char.uppercase_ascii cores.(j).[0] = cores.(j).[0]
                     && not (is_digit cores.(j).[0])
                  then name (j - 1) (cores.(j) :: acc)
                  else acc
                in
                let named =
                  if words.(i).[0] = '<' then name (i - 1) [] else []
                in
                add
                  { said = w;
                    kind =
                      Address
                        (String.concat " " named, String.lowercase_ascii w);
                    line }
            | _ -> ());
            k := i + 1)
  done;
  List.rev !found

let find ~(today : Civil.date) (text : string) : found list =
  let all =
    List.concat_map
      (fun l -> in_line ~today (String.trim l))
      (String.split_on_char '\n' text)
  in
  (* once each *)
  List.fold_left
    (fun acc f ->
      if List.exists (fun g -> g.kind = f.kind) acc then acc else acc @ [ f ])
    [] all
