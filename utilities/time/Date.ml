(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* mini-date: Plan 9's date (principia's utilities/time/date.c): the
 * time now, or of the seconds since 1970 given, as a line: the day,
 * the month, the hour, the year. -n: the seconds, as a number. The
 * time is GMT's (date.c's -u, taken): its ctime reads /env/timezone,
 * not read here. *)

type caps = < Cap.stdout; Cap.stderr >

exception Usage

let days = [| "Sun"; "Mon"; "Tue"; "Wed"; "Thu"; "Fri"; "Sat" |]
let months = [| "Jan"; "Feb"; "Mar"; "Apr"; "May"; "Jun"; "Jul"; "Aug"; "Sep"; "Oct"; "Nov"; "Dec" |]

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  try
    let number = ref false in
    let rec options = function
      | "--" :: rest -> rest
      | a :: rest when String.length a > 1 && a.[0] = '-' ->
          String.iteri (fun k c -> if k > 0 then match c with 'n' -> number := true | 'u' -> () | _ -> raise Usage) a;
          options rest
      | rest -> rest in
    (* (a float: seconds since 1970 are past arm's int; what is no number is 0, as strtoul's) *)
    let now = match options (List.tl (Array.to_list argv)) with
      | [ v ] -> if v <> "" && String.for_all (fun c -> c >= '0' && c <= '9') v then float_of_string v else 0.0
      | _ -> Unix.time () in
    (if !number then Console.print caps (Printf.sprintf "%.0f\n" now)
     else begin
       let t : Unix.tm = Unix.gmtime now in
       Console.print caps (Printf.sprintf "%s %s %2d %02d:%02d:%02d GMT %d\n" days.(t.tm_wday) months.(t.tm_mon) t.tm_mday t.tm_hour t.tm_min t.tm_sec (t.tm_year + 1900))
     end);
    Exit.OK
  with Usage -> Console.eprint caps "usage: date [-un] [seconds]\n"; Exit.Err "usage"

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
