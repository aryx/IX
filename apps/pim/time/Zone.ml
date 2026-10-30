(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Zone.mli *)

(* a rule of POSIX's TZ, "CET-1CEST,M3.5.0,M10.5.0/3": the offsets east
 * of UTC in seconds, and when summer time begins and ends, each a
 * month, a week (5 the last), a weekday (0 Sunday), and the second of
 * the local day *)
type change = { month : int; week : int; wday : int; at : int }

type rule = { std : int; dst : (int * change * change) option }

type t = {
  (* from each UTC second on, the offset, the oldest first *)
  transitions : (float * int) list;
  first : int; (* before the first *)
  rule : rule option; (* after the last *)
}

let utc : t = { transitions = []; first = 0; rule = None }

(*****************************************************************************)
(* POSIX's rule, the footer of a TZif file *)
(*****************************************************************************)

(* "-1", "5", "-3:30", "2", "/3": hours[:minutes[:seconds]] *)
let hms (s : string) : int option =
  let neg = String.length s > 0 && s.[0] = '-' in
  let s =
    if String.length s > 0 && (s.[0] = '-' || s.[0] = '+') then
      String.sub s 1 (String.length s - 1)
    else s
  in
  let parts = List.map int_of_string_opt (String.split_on_char ':' s) in
  if parts = [] || List.mem None parts then None
  else
    let n =
      List.fold_left ( + ) 0
        (List.mapi
           (fun k p ->
             (match p with Some p -> p | None -> 0)
             * (match k with 0 -> 3600 | 1 -> 60 | _ -> 1))
           parts)
    in
    Some (if neg then -n else n)

(* the name: letters, or anything between < > ("<+03>") *)
let name (s : string) (i : int) : int =
  let n = String.length s in
  if i < n && s.[i] = '<' then
    match String.index_from_opt s i '>' with Some j -> j + 1 | None -> n
  else
    let rec go j =
      if j < n && ((s.[j] >= 'a' && s.[j] <= 'z') || (s.[j] >= 'A' && s.[j] <= 'Z'))
      then go (j + 1)
      else j
    in
    go i

(* the offset after a name: the digits, signs and colons *)
let number (s : string) (i : int) : int =
  let n = String.length s in
  let rec go j =
    if j < n && (s.[j] = '+' || s.[j] = '-' || s.[j] = ':' || (s.[j] >= '0' && s.[j] <= '9'))
    then go (j + 1)
    else j
  in
  go i

(* "M3.5.0/3" *)
let change (s : string) : change option =
  let s, at =
    match String.index_opt s '/' with
    | Some i -> (String.sub s 0 i, hms (String.sub s (i + 1) (String.length s - i - 1)))
    | None -> (s, Some 7200)
  in
  match (String.length s > 1 && s.[0] = 'M', at) with
  | true, Some at -> (
      match
        List.map int_of_string_opt
          (String.split_on_char '.' (String.sub s 1 (String.length s - 1)))
      with
      | [ Some month; Some week; Some wday ] -> Some { month; week; wday; at }
      | _ -> None)
  | _ -> None

let rule (s : string) : rule option =
  let s = String.trim s in
  let a = name s 0 in
  let b = number s a in
  (* (POSIX's offsets are west of UTC: CET-1 is an hour east) *)
  match hms (String.sub s a (b - a)) with
  | None -> None
  | Some west -> (
      let std = -west in
      let c = name s b in
      if c = b then Some { std; dst = None }
      else
        let d = number s c in
        let dst =
          if d = c then Some (std + 3600)
          else
            match hms (String.sub s c (d - c)) with
            | Some w -> Some (-w)
            | None -> None
        in
        match
          (dst, String.split_on_char ',' (String.sub s d (String.length s - d)))
        with
        | Some dst, [ ""; b; e ] -> (
            match (change b, change e) with
            | Some b, Some e -> Some { std; dst = Some (dst, b, e) }
            | _ -> None)
        | _ -> None)

(* the day number of a change in [year]: its week's weekday in the
 * month, the 5th the last *)
let day_of (year : int) (c : change) : int =
  let first = Civil.days_from_civil { year; month = c.month; day = 1 } in
  let d = first + ((c.wday - Civil.weekday first + 7) mod 7) + ((c.week - 1) * 7) in
  let last = first + Civil.days_in_month year c.month - 1 in
  if d > last then d - (7 * ((d - last + 6) / 7)) else d

let rule_offset (r : rule) (t : float) : int =
  match r.dst with
  | None -> r.std
  | Some (dst, b, e) ->
      let year =
        (Civil.civil_from_days
           (int_of_float (Float.floor ((t +. float_of_int r.std) /. 86400.))))
          .year
      in
      (* the changes' UTC seconds: the start said in standard time, the
       * end in summer time *)
      let utc_of (c : change) (off : int) =
        (float_of_int (day_of year c) *. 86400.) +. float_of_int (c.at - off)
      in
      let s = utc_of b r.std and e = utc_of e dst in
      let summer = if s < e then t >= s && t < e else t >= s || t < e in
      if summer then dst else r.std

(*****************************************************************************)
(* The files *)
(*****************************************************************************)

let be32 (s : string) (i : int) : int =
  let b k = Char.code s.[i + k] in
  let n = (b 0 lsl 24) lor (b 1 lsl 16) lor (b 2 lsl 8) lor b 3 in
  if n land 0x80000000 <> 0 then n - 0x100000000 else n

(* TZif (RFC 8536), version 1's data, 32-bit times to 2037, and the
 * footer's rule after them *)
let of_tzif (s : string) : t option =
  if String.length s < 44 || String.sub s 0 4 <> "TZif" then None
  else
    let count k = be32 s (20 + (4 * k)) in
    let isut = count 0 and isstd = count 1 and leap = count 2 in
    let times = count 3 and types = count 4 and chars = count 5 in
    let at = 44 in
    let idx = at + (4 * times) in
    let info = idx + times in
    let size =
      info + (6 * types) + chars + (8 * leap) + isstd + isut
    in
    if String.length s < size || types = 0 then None
    else
      let offset k = be32 s (info + (6 * k)) in
      let transitions =
        List.init times (fun k ->
            (float_of_int (be32 s (at + (4 * k))), offset (Char.code s.[idx + k])))
      in
      (* the rule: between the last two newlines *)
      let rule =
        if s.[4] = '\000' then None
        else
          match String.rindex_opt s '\n' with
          | Some j when j > 0 -> (
              match String.rindex_from_opt s (j - 1) '\n' with
              | Some i -> rule (String.sub s (i + 1) (j - i - 1))
              | None -> None)
          | _ -> None
      in
      Some { transitions; first = offset 0; rule }

(* Plan 9's /env/timezone: "CET 3600 CEST 7200", then the UTC seconds
 * where the offset changes, summer's first, each other one *)
let of_plan9 (s : string) : t option =
  match
    List.filter (fun w -> w <> "")
      (String.split_on_char ' '
         (String.map (fun c -> if c = '\n' || c = '\t' then ' ' else c) s))
  with
  | _ :: std :: _ :: dst :: times -> (
      match (int_of_string_opt std, int_of_string_opt dst) with
      | Some std, Some dst ->
          let transitions =
            List.mapi
              (fun k t -> (float_of_string t, if k mod 2 = 0 then dst else std))
              (List.filter (fun t -> float_of_string_opt t <> None) times)
          in
          Some { transitions; first = std; rule = Some { std; dst = None } }
      | _ -> None)
  | _ -> None

let offset (z : t) (t : float) : int =
  let rec go (last : int option) l =
    match l with
    | (u, off) :: rest when u <= t -> go (Some off) rest
    | [] -> (
        match (z.rule, last) with
        | Some r, _ -> rule_offset r t
        | None, Some off -> off
        | None, None -> z.first)
    | _ -> ( match last with Some off -> off | None -> z.first)
  in
  go None z.transitions

let local (caps : < Cap.open_in ; Cap.env ; .. >) : t =
  let read path = try Some (FS.read caps (Fpath.v path)) with _ -> None in
  let tz = try CapSys.getenv caps "TZ" with Not_found -> "" in
  let from_file path =
    match read path with
    | Some s -> (
        match of_tzif s with Some z -> Some z | None -> of_plan9 s)
    | None -> None
  in
  let found =
    if tz = "UTC" || tz = "UTC0" then Some utc
    else if tz <> "" && tz.[0] = ':' then
      from_file ("/usr/share/zoneinfo/" ^ String.sub tz 1 (String.length tz - 1))
    else if tz <> "" then
      match from_file ("/usr/share/zoneinfo/" ^ tz) with
      | Some z -> Some z
      | None -> (
          match rule tz with
          | Some r -> Some { utc with rule = Some r }
          | None -> None)
    else
      match from_file "/etc/localtime" with
      | Some z -> Some z
      | None -> from_file "/env/timezone"
  in
  match found with Some z -> z | None -> utc

let clock (z : t) (t : float) : Civil.date * int =
  let local = Float.floor (t +. float_of_int (offset z t)) in
  let days = int_of_float (Float.floor (local /. 86400.)) in
  let seconds = int_of_float (local -. (float_of_int days *. 86400.)) in
  (Civil.civil_from_days days, seconds / 60)
