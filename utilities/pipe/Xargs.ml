(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-xargs: Plan 9's xargs (principia's utilities/pipe/xargs.c): a
 * command run with the standard input's lines as arguments after its
 * own, 10 lines at a time (-n lines: so many); as many times as it
 * takes. -p procs: so many of them at once (1). A line is one
 * argument, its blanks too. Nothing is run when there is no line.
 *
 *     walk -f | grep '\.c$' | xargs wc -l      wc run on ten files,
 *                                              then on the next ten
 *
 * cs-history:
 * Why it exists: what exec passes to a program had a limit, a few
 * thousand bytes in the first Unix systems, so rm `{find ...} failed
 * ("arg list too long") just when there was much to remove. xargs
 * cuts the list into commands that fit. It is from the Programmer's
 * Workbench Unix of the 1970s (from memory).
 *
 * others:
 * Unix's xargs cuts its input at blanks and reads quotes and
 * backslashes in it, so a file's name with a space in it is two
 * arguments; hence find -print0 and xargs -0, the names ended by a
 * zero byte (GNU's). Plan 9's takes a line for an argument, and only
 * a newline in a name defeats it. It counts lines and not bytes: ten
 * names fit. *)

type caps = < Cap.fork; Cap.exec; Cap.wait; Cap.stdin; Cap.stderr >

exception Usage

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  try
    let lines = ref 10 and procs = ref 1 in
    let number v = match int_of_string_opt v with Some n -> n | None -> 0 in
    let rec options = function
      | "--" :: rest -> rest
      | a :: rest when String.length a > 1 && a.[0] = '-' && (a.[1] = 'n' || a.[1] = 'p') ->
          let v, rest = if String.length a > 2 then String.sub a 2 (String.length a - 2), rest else match rest with v :: rest -> v, rest | [] -> raise Usage in
          (if a.[1] = 'n' then lines := number v else procs := number v);
          options rest
      | a :: _ when String.length a > 1 && a.[0] = '-' -> raise Usage
      | rest -> rest in
    let command = options (List.tl (Array.to_list argv)) in
    if command = [] then raise Usage;
    let all = Buffer.create 8192 and buf = Bytes.create 8192 in
    let fd = Console.stdin_fd caps in
    let rec read () = match Unix.read fd buf 0 8192 with 0 -> () | n -> Buffer.add_subbytes all buf 0 n; read () | exception Unix.Unix_error _ -> () in
    read ();
    let text = Buffer.contents all in
    let input = String.split_on_char '\n' text in
    let input = if text = "" || text.[String.length text - 1] = '\n' then List.filteri (fun k _ -> k < List.length input - 1) input else input in
    let wait () = try ignore (CapUnix.wait caps ()) with Unix.Unix_error _ -> () in
    let run args =
      let prog = List.hd command and argv = Array.of_list (command @ args) in
      match CapUnix.fork caps () with
      | 0 ->
          (* the command, as it is named; then in /bin when its name is no path *)
          let why = match CapUnix.execv caps prog argv with _ -> "" | exception Unix.Unix_error (e, _, _) -> Unix.error_message e in
          let rooted p = String.length prog >= String.length p && String.sub prog 0 (String.length p) = p in
          let why = if rooted "/" || rooted "./" || rooted "../" then why
            else match CapUnix.execv caps ("/bin/" ^ prog) argv with _ -> "" | exception Unix.Unix_error (e, _, _) -> Unix.error_message e in
          Console.eprint caps (Printf.sprintf "%s: exec: %s\n" Sys.argv.(0) why);
          Sys_plan9.exits ("exec: " ^ why)
      | _ -> () in
    (* so many lines a run; one that has ended is waited for before a
     * new one when as many as asked are running *)
    let rec go input started =
      if input <> [] then begin
        if started >= !procs then wait ();
        let n = max 1 !lines in
        run (List.filteri (fun k _ -> k < n) input);
        go (List.filteri (fun k _ -> k >= n) input) (started + 1)
      end
      else for _k = 1 to min started !procs do wait () done in
    go input 0;
    Exit.OK
  with Usage -> Console.eprint caps "usage: xargs [ -n lines ] [ -p procs ] args ...\n"; Exit.Err "usage"

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
