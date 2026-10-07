(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* mini-seq: Plan 9's seq (principia's utilities/misc/seq.c; this file
 * Seq_: Seq is the standard library's): the
 * numbers from 1, or from the first given, to the last, by 1 or by
 * the increment given (which may go down), one a line, as %g writes
 * them. -w: all as wide, zeros before. For a script's loop. Not
 * seq.c's -f format: a format here is the compiler's, not a string
 * read when the program runs. *)

type caps = < Cap.stdout; Cap.stderr >

exception Usage

(* atof: what is no number is 0 *)
let number s = match float_of_string_opt s with Some f -> f | None -> 0.0

(* a number with so many digits after the point (%g has 6 at most) *)
let fixed places v =
  match places with
  | 0 -> Printf.sprintf "%.0f" v | 1 -> Printf.sprintf "%.1f" v | 2 -> Printf.sprintf "%.2f" v | 3 -> Printf.sprintf "%.3f" v
  | 4 -> Printf.sprintf "%.4f" v | 5 -> Printf.sprintf "%.5f" v | _ -> Printf.sprintf "%.6f" v

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  try
    let wide, args = match List.tl (Array.to_list argv) with
      | "-w" :: rest -> true, rest
      | a :: _ when String.length a > 1 && a.[0] = '-' && not (a.[1] >= '0' && a.[1] <= '9') && a.[1] <> '.' -> raise Usage
      | rest -> false, rest in
    let first, incr, last = match args with
      | [ last ] -> 1.0, 1.0, number last
      | [ first; last ] -> number first, 1.0, number last
      | [ first; incr; last ] -> number first, number incr, number last
      | _ -> raise Usage in
    if incr = 0.0 then begin Console.eprint caps "seq: zero increment\n"; Exit.Err "zero increment" end
    else begin
      let rec values v = if (incr > 0.0 && v <= last) || (incr < 0.0 && v >= last) then v :: values (v +. incr) else [] in
      let values = values first in
      let plain = List.map (fun v -> Printf.sprintf "%g" v) values in
      (* -w: the widest whole part and the most digits after the point
       * decide for all; not when one is written with an exponent, nor
       * when the numbers go down (seq.c measures going up only) *)
      let lines =
        if not wide || incr < 0.0 || List.exists (fun s -> String.contains s 'e') plain then plain
        else begin
          let whole s = match String.index_opt s '.' with Some k -> k | None -> String.length s in
          let width = List.fold_left (fun w s -> max w (whole s)) 0 plain
          and places = List.fold_left (fun p s -> max p (String.length s - whole s - 1)) 0 plain in
          let width = if places > 0 then width + places + 1 else width in
          List.map (fun v -> let s = fixed places v in String.make (max 0 (width - String.length s)) '0' ^ s) values
        end in
      Console.print caps (String.concat "" (List.map (fun s -> s ^ "\n") lines));
      Exit.OK
    end
  with Usage -> Console.eprint caps "usage: seq [-fformat] [-w] [first [incr]] last\n"; Exit.Err "usage"

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
