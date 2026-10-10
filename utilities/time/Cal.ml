(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-cal: Plan 9's cal (principia's utilities/time/cal.c), its output
 * byte for byte: a month's days under the week's, or a year's twelve
 * months, three a row. Without an argument, this month; one argument
 * is a month of this year when it is 1 to 12 or a month's name (jan,
 * january), a year (1 to 9999) if not; two are a month and a year.
 *
 * The calendar is England's: Julian until September 1752, which has 19
 * days (the 2nd, then the 14th), Gregorian after.
 *
 * "This month" is GMT's: cal.c's localtime reads /env/timezone, not
 * read here.
 *
 *     cal 9 1752
 *        September 1752
 *      S  M Tu  W Th  F  S
 *            1  2 14 15 16
 *     17 18 19 20 21 22 23
 *     24 25 26 27 28 29 30
 *
 * cs-history:
 * The Julian calendar's year is a little too long, and by the 16th
 * century the seasons were ten days late on it. The Gregorian one
 * (1582) drops three leap years in four centuries and skipped the
 * ten days: in Rome and in Spain, October 4th, 1582 was followed by
 * the 15th. Britain and its colonies waited until 1752 (the
 * Calendar Act of 1750), by when eleven days were to skip; Russia
 * until 1918. So a date before the 20th century is in a calendar
 * that depends on the place, and a program must choose one: cal
 * took England's, and cal 10 1582 here is a whole month. A year is
 * the number as typed: cal 90 is the year 90, not 1990. *)

type caps = < Cap.stdout; Cap.stderr >

exception Bad

let help = "usage: cal [month] [year]\n"

let week = " S  M Tu  W Th  F  S"
let months = [| "January"; "February"; "March"; "April"; "May"; "June"; "July"; "August"; "September"; "October"; "November"; "December" |]

(* the day of the week (0: Sunday) of January 1st *)
let jan1 y =
  (* a day more each year, and one more each four *)
  let d = 4 + y + (y + 3) / 4 in
  (* Gregorian: three days less each 400 years *)
  let d = if y > 1800 then d - (y - 1701) / 100 + (y - 1601) / 400 else d in
  (* the changeover *)
  (if y > 1752 then d + 3 else d) mod 7

(* a month's days: its first one, its last, and those skipped (1752's September: 3 to 13) *)
let days m y =
  let all = [| 31; 29; 31; 30; 31; 30; 31; 31; 30; 31; 30; 31 |] in
  (* the year's length, by where the next one starts *)
  (match (jan1 (y + 1) + 7 - jan1 y) mod 7 with
   | 1 -> all.(1) <- 28
   | 2 -> ()
   | _ -> all.(8) <- 19);
  let first = ref (jan1 y) in
  for i = 0 to m - 2 do first := !first + all.(i) done;
  (!first mod 7, (if all.(m - 1) = 19 then 30 else all.(m - 1)), all.(m - 1) = 19)

(* a month's six lines of 20 columns: a day's two, then a space *)
let month m y : Bytes.t array =
  let lines = Array.init 6 (fun _i -> Bytes.make 20 ' ') in
  let column, last, short = days m y in
  let column = ref column and line = ref 0 in
  for i = 1 to last do
    if not (short && i >= 3 && i <= 13) then begin
      if i > 9 then Bytes.set lines.(!line) (3 * !column) (Char.chr (48 + i / 10));
      Bytes.set lines.(!line) (3 * !column + 1) (Char.chr (48 + i mod 10));
      incr column;
      if !column = 7 then begin column := 0; incr line end
    end
  done;
  lines

(* without the spaces at its end *)
let trimmed s =
  let n = ref (String.length s) in
  while !n > 0 && s.[!n - 1] = ' ' do decr n done;
  String.sub s 0 !n

(* a month's number, negative when it was a name; 0 for what is neither *)
let number s =
  let l = String.length s in
  let named = ref 0 in
  Array.iteri (fun i full ->
    let full = String.lowercase_ascii full in
    if s = full || s = String.sub full 0 3 || (s = "sept" && i = 8) then named := - (i + 1)) months;
  if !named <> 0 then !named
  else if l > 5 || not (String.for_all (fun c -> c >= '0' && c <= '9') s) then 0
  else if l = 0 then 0 else int_of_string s

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  let out = Buffer.create 2048 in
  let add = Buffer.add_string out in
  let one m y =
    if m < 1 || m > 12 || y < 1 || y > 9999 then raise Bad;
    add (Printf.sprintf "   %s %d\n%s\n" months.(m - 1) y week);
    Array.iter (fun line -> add (trimmed (Bytes.to_string line) ^ "\n")) (month m y) in
  let whole y =
    if y < 1 || y > 9999 then raise Bad;
    add (Printf.sprintf "\n\n\n%s%d\n\n" (String.make 32 ' ') y);
    List.iter (fun q ->
      let name k = String.sub months.(q + k) 0 3 and gap = String.make 20 ' ' in
      add (Printf.sprintf "         %s%s%s%s%s\n%s   %s   %s\n" (name 0) gap (name 1) gap (name 2) week week week);
      let three = Array.init 3 (fun k -> month (q + k + 1) y) in
      for line = 0 to 5 do
        add (trimmed (String.concat "   " (List.map (fun k -> Bytes.to_string three.(k).(line)) [ 0; 1; 2 ])) ^ "\n")
      done) [ 0; 3; 6; 9 ];
    add "\n\n\n" in
  let now = Unix.gmtime (Unix.time ()) in
  let this_year = now.Unix.tm_year + 1900 in
  match List.tl (Array.to_list argv) with
  | _ :: _ :: _ :: _ -> Console.eprint caps help; Exit.Err "usage"
  | args ->
      (try
         (match args with
          | [] -> one (now.Unix.tm_mon + 1) this_year
          | [ a ] -> let n = abs (number a) in if n >= 1 && n <= 12 then one n this_year else whole n
          | [ m; y ] -> one (abs (number m)) (number y)
          | _ -> ());
         Console.print caps (Buffer.contents out); Exit.OK
       (* (cal.c says it on its output, and falls off main) *)
       with Bad -> Console.print caps "cal: bad argument\n"; Exit.Err "main")

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
