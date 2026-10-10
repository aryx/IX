(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-tail: Plan 9's tail (principia's utilities/pipe/tail.c): the
 * end of a file, or of the standard input: its last 10 lines.
 * -N, -n N: the last N lines; +N: from line N; -Nc, -c N: bytes, not
 * lines (b: of 1024); -r: the lines last first (all of them when no N);
 * -f: then what is written to the file after, looked for every 5
 * seconds, for ever. As tail.c, the letters may follow the number
 * (-20f, +3c).
 *
 * Not tail.c's way: it seeks to the file's end and reads back; here
 * the file is read whole, and what is asked cut from it. *)

type caps = < Cap.open_in; Cap.stdin; Cap.stdout; Cap.stderr >

exception Usage
(* what, and the system's reason if any *)
exception Fatal of string * string

type options = { mutable count : int option; mutable from_start : bool; mutable bytes : bool; mutable reversed : bool; mutable follow : bool }

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  let fatal what why = Console.eprint caps (Printf.sprintf "tail: %s: %s\n" what why); Exit.Err what in
  try
    let o = { count = None; from_start = false; bytes = false; reversed = false; follow = false } in
    let digit c = c >= '0' && c <= '9' in
    (* a number, after a sign or not: the count, + for "from the start".
     * false when s is no number *)
    let number s =
      let k = if s <> "" && (s.[0] = '-' || s.[0] = '+') then 1 else 0 in
      if k >= String.length s || not (digit s.[k]) then false
      else begin
        if k = 1 && s.[0] = '+' then o.from_start <- true;
        if o.count <> None then raise (Fatal ("excess option", ""));
        let rec last j = if j < String.length s && digit s.[j] then last (j + 1) else j in
        (match int_of_string_opt (String.sub s k (last k - k)) with Some n -> o.count <- Some n | None -> raise (Fatal ("too big", "")));
        true
      end in
    (* the letters after a number: b, c or l (the unit), then r or f *)
    let suffix s =
      let rec skip k = if k < String.length s && (digit s.[k] || s.[k] = '+' || s.[k] = '-') then skip (k + 1) else k in
      let k = skip 0 in
      let at k = if k < String.length s then s.[k] else '\000' in
      let k = match at k with
        | 'b' -> o.count <- Option.map (fun n -> n * 1024) o.count; o.bytes <- true; k + 1
        | 'c' -> o.bytes <- true; k + 1
        | 'l' -> k + 1
        | _ -> k in
      match at k with 'r' -> o.reversed <- true | 'f' -> o.follow <- true | '\000' -> () | _ -> raise Usage in
    let rec options = function
      | a :: rest when a <> "" && (a.[0] = '-' || a.[0] = '+') ->
          if number a then begin suffix a; options rest end
          else if a.[0] = '-' && String.length a > 1 then
            match a.[1] with
            | ('c' | 'n') as c ->
                if c = 'c' then o.bytes <- true;
                if number (String.sub a 2 (String.length a - 2)) then options rest
                else (match rest with v :: rest when number v -> options rest | _ -> raise Usage)
            | 'r' -> o.reversed <- true; options rest
            | 'f' -> o.follow <- true; options rest
            | '-' -> rest
            | _ -> a :: rest
          else a :: rest
      | rest -> rest in
    let files = options (List.tl (Array.to_list argv)) in
    if o.reversed && (o.bytes || o.follow || o.from_start) then raise (Fatal ("incompatible options", ""));
    let fd = match files with
      | [] -> Console.stdin_fd caps
      | [ file ] -> (try FS.open_in_fd caps file with Unix.Unix_error (e, _, _) -> raise (Fatal (file, Unix.error_message e)))
      | _ -> raise Usage in
    let out = Console.stdout_fd caps and buf = Bytes.create 8192 in
    let write s = if s <> "" then ignore (Unix.write_substring out s 0 (String.length s)) in
    let rec rest_of all = match Unix.read fd buf 0 8192 with 0 -> Buffer.contents all | n -> Buffer.add_subbytes all buf 0 n; rest_of all in
    let text = rest_of (Buffer.create 8192) in
    let len = String.length text in
    (* where the line after so many newlines starts, from a place *)
    let rec forward at lines = if lines <= 0 || at >= len then at else forward (match String.index_from_opt text at '\n' with Some k -> k + 1 | None -> len) (lines - 1) in
    (* where the last so many lines start: a last line without its newline is one *)
    let backward lines =
      let rec go at lines = if lines <= 0 || at <= 0 then at else match String.rindex_from_opt text (at - 1) '\n' with Some k -> if lines = 1 then k + 1 else go k (lines - 1) | None -> 0 in
      go (if len > 0 && text.[len - 1] = '\n' then len - 1 else len) lines in
    (if o.reversed then begin
       (* each line, the last first; its newline given to a last one without *)
       let lines = String.split_on_char '\n' text in
       let lines = if len = 0 || text.[len - 1] = '\n' then List.filteri (fun k _ -> k < List.length lines - 1) lines else lines in
       let lines = List.rev lines in
       let lines = match o.count with Some n -> List.filteri (fun k _ -> k < n) lines | None -> lines in
       write (String.concat "" (List.map (fun l -> l ^ "\n") lines))
     end
     else begin
       let count = match o.count with Some n -> n | None -> 10 in
       let start =
         if o.bytes then (if o.from_start then min count len else max 0 (len - count))
         else if o.from_start then forward 0 (count - 1)
         (* (-0: tail.c counts no line back and then shows the file from its start) *)
         else if count = 0 then 0
         else backward count in
       write (String.sub text start (len - start))
     end);
    (* what is written after, when the file is one that can be gone
     * over (not a pipe): asked for every 5 seconds *)
    let seekable = match Unix.lseek fd 0 Unix.SEEK_CUR with _ -> true | exception Unix.Unix_error _ -> false in
    if o.follow && seekable then
      while true do
        write (rest_of (Buffer.create 256));
        Unix.sleepf 5.0
      done;
    Exit.OK
  with
  | Usage -> Console.eprint caps "usage: tail [-n N] [-c N] [-f] [-r] [+-N[bc][fr]] [file]\n"; Exit.Err "usage"
  | Fatal (what, why) -> fatal what why

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
