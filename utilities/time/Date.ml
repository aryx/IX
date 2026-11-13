(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-date is Plan 9's date (principia's utilities/time/date.c). It
 * writes the time now, or the time of the seconds since 1970 that are
 * given, as a line: the day, the month, the hour, the year. With -n, it
 * writes the seconds, as a number. The time is in GMT (date.c's -u is
 * accepted): date.c's ctime reads /env/timezone, which is not read
 * here.
 *
 *     date 0                Thu Jan  1 00:00:00 GMT 1970
 *     date 2147483647       Tue Jan 19 03:14:07 GMT 2038
 *
 * cs-history:
 * The time as one number, counted from a fixed instant, with the
 * day, the month and the zone left to a library, was Unix's choice,
 * and it has been everyone's since. The first edition counted
 * sixtieths of a second from 1971, which 32 bits hold for a little
 * over two years; the unit became the second, and the start 1970, in
 * the fourth edition (1973). The second line above is the last second
 * that a signed number of 32 bits holds: that is the year 2038
 * problem, for whatever still keeps the time that way. *)

type caps = < Cap.stdout; Cap.stderr; Cap.clock >

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
      | _ -> CapUnix.time caps () in
    (if !number then Console.print caps (Printf.sprintf "%.0f\n" now)
     else begin
       let t : Unix.tm = Unix.gmtime now in
       Console.print caps (Printf.sprintf "%s %s %2d %02d:%02d:%02d GMT %d\n" days.(t.tm_wday) months.(t.tm_mon) t.tm_mday t.tm_hour t.tm_min t.tm_sec (t.tm_year + 1900))
     end);
    Exit.OK
  with Usage -> Console.eprint caps "usage: date [-un] [seconds]\n"; Exit.Err "usage"

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
