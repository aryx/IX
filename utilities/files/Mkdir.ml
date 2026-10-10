(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-mkdir: Plan 9's mkdir (principia's utilities/files/mkdir.c):
 * each directory made, which must not be there. -p: with the
 * directories of its path that are missing, and none is an error when
 * there already; -m mode: its permissions, in octal (777 without).
 *
 * cs-history:
 * For its first twelve years Unix had no call to make a directory.
 * mkdir was a program that ran as root (by the set-user-id bit):
 * mknod to make an empty directory, which only root may, then two
 * link's for its . and its .. -- three calls, and a directory half
 * made if the program was killed between them. The mkdir call came
 * with 4.2BSD (1983), with rename, for the same reason.
 *
 * plan9-is-cleaner:
 * Here a directory is made by create, the call that makes a file,
 * with one more bit in the mode (DMDIR); and . and .. are not
 * entries anyone writes: the server answers for them. *)

type caps = < Cap.open_out; Cap.readdir; Cap.stderr >

exception Usage

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  try
    let parents = ref false and mode = ref 0o777 and failed = ref false in
    (* the options: letters after a -, in the first arguments; -m's
     * value is the letters after it, or the next argument *)
    let rec options = function
      | "--" :: rest -> rest
      | a :: rest when String.length a > 1 && a.[0] = '-' ->
          let rec letters k rest =
            if k >= String.length a then options rest
            else match a.[k] with
              | 'p' -> parents := true; letters (k + 1) rest
              | 'm' ->
                  let v, rest =
                    if k + 1 < String.length a then String.sub a (k + 1) (String.length a - k - 1), rest
                    else match rest with v :: rest -> v, rest | [] -> raise Usage in
                  (match int_of_string_opt ("0o" ^ v) with Some m when m >= 0 && m <= 0o777 -> mode := m | _ -> raise Usage);
                  options rest
              | _ -> raise Usage in
          letters 1 rest
      | rest -> rest in
    let exists s = match Sys_plan9.dirstat caps s with _ -> true | exception Unix.Unix_error _ -> false in
    (* false when it could not be made *)
    let makedir s =
      let said msg = Console.eprint caps msg; failed := true; false in
      if exists s then said (Printf.sprintf "mkdir: %s already exists\n" s)
      else match FS.mkdir caps s !mode with
        | () -> true
        | exception Unix.Unix_error (e, _, _) -> said (Printf.sprintf "mkdir: can't create %s: %s\n" s (Unix.error_message e)) in
    (* -p: the path's directories from the first, each made when it is
     * not there (a / at the start is not one's end) *)
    let mkdirp s =
      let rec from k =
        match String.index_from_opt s k '/' with
        | Some j -> let d = String.sub s 0 j in if exists d || makedir d then from (j + 1)
        | None -> if not (exists s) then ignore (makedir s) in
      if s <> "" then from 1 in
    List.iter (fun s -> if !parents then mkdirp s else ignore (makedir s)) (options (List.tl (Array.to_list argv)));
    if !failed then Exit.Err "error" else Exit.OK
  with Usage -> Console.eprint caps "usage: mkdir [-p] [-m mode] dir...\n"; Exit.Err "usage"

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
