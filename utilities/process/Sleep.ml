(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-sleep: Plan 9's sleep (principia's utilities/process/sleep.c):
 * the seconds given are waited, a second at a time (an interrupt ends
 * it within one), then the thousandths after a point (three digits at
 * most are read: sleep .5 is half a second). *)

type caps = < Cap.stderr >

let main (_ : < caps; .. >) (argv : string array) : Exit.t =
  (match List.tl (Array.to_list argv) with
   | [] -> ()
   | a :: _ ->
       let digits from = let rec go k = if k < String.length a && a.[k] >= '0' && a.[k] <= '9' then go (k + 1) else k in String.sub a from (go from - from) in
       let whole = digits 0 in
       for _second = 1 to (if whole = "" then 0 else int_of_string whole) do Unix.sleepf 1.0 done;
       let dot = String.length whole in
       if dot < String.length a && a.[dot] = '.' then begin
         (* the thousandths: the digits after the point, three of them, a missing one a 0 *)
         let part = digits (dot + 1) in
         let part = if String.length part > 3 then String.sub part 0 3 else part ^ String.make (3 - String.length part) '0' in
         let ms = int_of_string part in
         if ms > 0 then Unix.sleepf (float_of_int ms /. 1000.0)
       end);
  Exit.OK

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
