(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-touch: Plan 9's touch (principia's utilities/files/touch.c):
 * each file's time written set to now, and a file that is not there
 * made, empty. -c: none is made; -t time: that time, seconds since
 * 1970, and not now. *)

type caps = < Cap.open_out; Cap.stderr >

exception Usage

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  try
    let nocreate = ref false and time = ref (Unix.time ()) in
    (* the options: letters after a -, in the first arguments; -t's
     * value is the letters after it, or the next argument *)
    let rec options = function
      | "--" :: rest -> rest
      | a :: rest when String.length a > 1 && a.[0] = '-' ->
          let rec letters k rest =
            if k >= String.length a then options rest
            else match a.[k] with
              | 'c' -> nocreate := true; letters (k + 1) rest
              | 't' ->
                  let v, rest =
                    if k + 1 < String.length a then String.sub a (k + 1) (String.length a - k - 1), rest
                    else match rest with v :: rest -> v, rest | [] -> raise Usage in
                  (* (a float: seconds since 1970 are past arm's int) *)
                  if v = "" || not (String.for_all (fun c -> c >= '0' && c <= '9') v) then raise Usage;
                  time := float_of_string v;
                  options rest
              | _ -> raise Usage in
          letters 1 rest
      | rest -> rest in
    let files = options (List.tl (Array.to_list argv)) in
    if files = [] then raise Usage;
    let failed = ref false in
    let said name what e = Console.eprint caps (Printf.sprintf "touch: %s: cannot %s: %s\n" name what (Unix.error_message e)); failed := true in
    List.iter (fun name ->
      match Sys_plan9.set_mtime caps name !time with
      | () -> ()
      | exception Unix.Unix_error (e, _, _) ->
          if !nocreate then said name "wstat" e
          else match FS.create_fd caps name 0o666 with
            | fd -> (try Sys_plan9.set_mtime caps name !time with Unix.Unix_error _ -> ()); Unix.close fd
            | exception Unix.Unix_error (e, _, _) -> said name "create" e) files;
    if !failed then Exit.Err "touch" else Exit.OK
  with Usage -> Console.eprint caps "usage: touch [-c] [-t time] files\n"; Exit.Err "usage"

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
