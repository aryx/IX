(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-uniq is Plan 9's uniq (principia's utilities/text/misc/uniq.c).
 * It reads a file, or the standard input, and of the lines that follow
 * each other and are the same it writes one (the first).
 * - -u writes only the lines that are alone;
 * - -d writes only one of each group of lines that are not alone;
 * - -c writes each line with how many there were;
 * - -N compares the lines without their first N fields (the fields are
 *   parted by spaces and tabs);
 * - +N compares them without N more characters.
 * As in uniq.c, a last line without its newline is not read.
 *
 * design:
 * uniq looks only at lines that follow each other. So it keeps one
 * line in memory, whatever the input's size, and it leaves the job of
 * bringing the same lines together to the program that knows how,
 * sort. Each tool does one thing, and the pipe makes the program:
 *
 *     echo the cat and the dog and the bird |
 *       tr -cs A-Za-z '\012' | sort | uniq -c | sort -rn | sed 2q
 *        3 the
 *        2 and
 *
 * cs-history:
 * That line, with one more tr A-Z a-z, is Doug McIlroy's. In 1986,
 * for his column in the Communications of the ACM, Jon Bentley asked
 * Donald Knuth for a program in his literate style that finds the n
 * most frequent words of a text. Knuth wrote several pages of Pascal,
 * with a data structure made for the task. McIlroy, asked to review
 * it, praised it and gave these six commands in its place, each of
 * them a tool that was already there. ("Programming Pearls: A
 * Literate Program", June 1986.) *)

type caps = < Cap.open_in; Cap.stdin; Cap.stdout; Cap.stderr >

exception Fatal of string

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  try
    let fields = ref 0 and letters = ref 0 and mode = ref ' ' in
    let number s = let rec last k = if k < String.length s && s.[k] >= '0' && s.[k] <= '9' then last (k + 1) else k in
      match int_of_string_opt (String.sub s 0 (last 0)) with Some n -> n | None -> 0 in
    let rec options = function
      | a :: rest when a <> "" && a.[0] = '-' ->
          if String.length a > 1 && a.[1] >= '0' && a.[1] <= '9' then fields := number (String.sub a 1 (String.length a - 1))
          else mode := (if String.length a > 1 then a.[1] else ' ');
          options rest
      | a :: rest when a <> "" && a.[0] = '+' -> letters := number (String.sub a 1 (String.length a - 1)); options rest
      | rest -> rest in
    let fd = match options (List.tl (Array.to_list argv)) with
      | [] -> Console.stdin_fd caps
      | [ file ] -> (try FS.open_in_fd caps file with Unix.Unix_error _ -> raise (Fatal ("cannot open " ^ file)))
      | _ :: extra :: _ -> raise (Fatal ("unexpected argument " ^ extra)) in
    let all = Buffer.create 8192 and buf = Bytes.create 8192 in
    let rec read () = match Unix.read fd buf 0 8192 with 0 -> () | n -> Buffer.add_subbytes all buf 0 n; read () | exception Unix.Unix_error _ -> () in
    read ();
    let lines = String.split_on_char '\n' (Buffer.contents all) in
    let lines = List.filteri (fun k _ -> k < List.length lines - 1) lines in
    (* what of a line is compared: after its first fields and letters *)
    let key s =
      let n = String.length s in
      let blank k = s.[k] = ' ' || s.[k] = '\t' in
      let rec field k left =
        if left = 0 then k
        else begin
          let rec spaces k = if k < n && blank k then spaces (k + 1) else k in
          let rec word k = if k < n && not (blank k) then word (k + 1) else k in
          field (word (spaces k)) (left - 1)
        end in
      let k = min n (field 0 !fields + !letters) in
      String.sub s k (n - k) in
    let out = Buffer.create 8192 in
    let group line count =
      if (!mode = 'u' && count > 1) || (!mode = 'd' && count = 1) then ()
      else Buffer.add_string out ((if !mode = 'c' then Printf.sprintf "%4d " count else "") ^ line ^ "\n") in
    (* a group's first line and how many it has so far, then the lines left *)
    let rec go first count = function
      | line :: rest when key line = key first -> go first (count + 1) rest
      | line :: rest -> group first count; go line 1 rest
      | [] -> group first count in
    (match lines with first :: rest -> go first 1 rest | [] -> ());
    Console.print caps (Buffer.contents out);
    Exit.OK
  with Fatal msg -> Console.eprint caps (Printf.sprintf "%s: %s\n" argv.(0) msg); Exit.Err msg

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
