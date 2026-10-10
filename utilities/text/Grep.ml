(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-grep: Plan 9's grep (principia's utilities/text/grep; xix's
 * utilities/text/grep is the author's in OCaml): the lines of each
 * file, or of the standard input, that a regular expression matches,
 * Plan 9's (Regex: regexp(7)'s, the one of mini-ed). Several patterns
 * (-e pattern, more than once; -f file, a pattern a line; a pattern of
 * several lines) are alternatives.
 *
 * -v: the lines that do not match; -i: whatever the letters' case; -n:
 * each with its line's number; -c: only how many; -l, -L: only the
 * names of the files with a match, without one; -s: nothing, the
 * status only; -h: no file's name before a line (with several files
 * it is there); -b is grep.c's (its output's buffer: no meaning here).
 *
 * Not grep.c's way: it makes one automaton of all the patterns and
 * runs it over the bytes as they are read; here a line is matched by
 * each pattern in turn, simpler and slower.
 *
 * cs-history:
 * The name is a command of ed: g/re/p, on all the lines (g, global)
 * that the regular expression matches, print. ed could do it only to
 * a file small enough for its buffer, so Ken Thompson made the
 * command a program that reads its input a line at a time (the
 * Fourth Edition, 1973). He had it for himself first: when Doug
 * McIlroy asked for such a tool he showed it the next day, hence
 * the tale of grep written overnight. The matcher was
 * already his: "Regular Expression Search Algorithm"
 * (Communications of the ACM, 1968), which follows all the ways a
 * pattern can match at once, so never goes back in the text.
 *
 * evolution:
 * Then there were three. egrep (Alfred Aho) took the whole notation,
 * | and parentheses too, and built a deterministic automaton before
 * reading; fgrep took strings only, many at once (Aho and Corasick's
 * automaton, 1975); grep kept ed's notation, with \( \) to remember.
 * POSIX made them options, -E and -F. Plan 9 went back to one grep,
 * with the whole notation and an automaton built as the text asks
 * for its states. GNU's (Mike Haertel) added what makes it fast on a
 * plain word: Boyer and Moore's search, which does not look at every
 * byte.
 *
 * References: grep(1), regexp(7); Russ Cox, "Regular Expression
 * Matching Can Be Simple And Fast" (2007), for Thompson's method
 * against the one that goes back, and the history; Regex.mli for the
 * matcher here. *)

type caps = < Cap.open_in; Cap.stdin; Cap.stdout; Cap.stderr >

exception Usage
exception Fatal of string * string

let usage = "usage: grep [-bchiLlnsv] [-e pattern] [-f patternfile] [file ...]\n"

(* all of a descriptor; None: an error while reading it *)
let contents (fd : Unix.file_descr) =
  let all = Buffer.create 8192 and buf = Bytes.create 8192 in
  let rec go () = match Unix.read fd buf 0 8192 with 0 -> Some (Buffer.contents all) | n -> Buffer.add_subbytes all buf 0 n; go () in
  go ()

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  try
    let flags = Hashtbl.create 8 and patterns = ref [] and given = ref false in
    let flag c = Hashtbl.mem flags c in
    let read_file file =
      match FS.open_in_fd caps file with
      | fd -> Fun.protect ~finally:(fun () -> Unix.close fd) (fun () -> contents fd)
      | exception Unix.Unix_error (e, _, _) -> raise (Fatal (Printf.sprintf "grep: can't open %s: %s\n" file (Unix.error_message e), "open")) in
    (* the options: letters after a -, in the first arguments; -e's and
     * -f's value is the letters after it, or the next argument *)
    let rec options = function
      | "--" :: rest -> rest
      | a :: rest when String.length a > 1 && a.[0] = '-' ->
          let rec letters k rest =
            if k >= String.length a then options rest
            else match a.[k] with
              | ('e' | 'f') as c ->
                  let v, rest =
                    if k + 1 < String.length a then String.sub a (k + 1) (String.length a - k - 1), rest
                    else match rest with v :: rest -> v, rest | [] -> raise Usage in
                  given := true;
                  patterns := !patterns @ (if c = 'e' then [ v ] else [ (match read_file v with Some text -> text | None -> "") ]);
                  options rest
              | c when String.contains "bchiLlnsv" c -> Hashtbl.replace flags c (); letters (k + 1) rest
              | _ -> raise Usage in
          letters 1 rest
      | rest -> rest in
    let files = options (List.tl (Array.to_list argv)) in
    let files = if !given then files else match files with p :: rest -> patterns := [ p ]; rest | [] -> raise Usage in
    let fold s = if flag 'i' then String.lowercase_ascii s else s in
    (* a pattern a line; an empty one matches every line *)
    let lines_of text = List.filter (fun l -> l <> "") (String.split_on_char '\n' text) in
    let texts = List.concat_map (fun p -> if p = "" then [ "" ] else lines_of p) !patterns in
    let regexps = List.map (fun p ->
      if p = "" then None
      else try Some (Regex.compile (fold p)) with Regex.Error m -> raise (Fatal (Printf.sprintf "grep: %s: %s\n" p m, "syntax"))) texts in
    let matches line = List.exists (function None -> true | Some re -> Regex.exec re (fold line) 0 <> None) regexps in
    let out = Buffer.create 4096 in
    (* one file: whether a line was taken *)
    let search name text named =
      let named = named && not (flag 'h') in
      let quiet = flag 'c' || flag 's' || flag 'l' || flag 'L' in
      (* the lines: a last one with no newline is one too, written
       * without one unless the file's name is before it (grep.c's) *)
      let lines = String.split_on_char '\n' text in
      let ended = text = "" || text.[String.length text - 1] = '\n' in
      let lines = if ended then List.filteri (fun k _ -> k < List.length lines - 1) lines else lines in
      let last = List.length lines in
      let count = ref 0 in
      List.iteri (fun k line ->
        if matches line <> flag 'v' then begin
          incr count;
          if not quiet then begin
            if named then Buffer.add_string out (name ^ ":");
            if flag 'n' then Buffer.add_string out (Printf.sprintf "%d: " (k + 1));
            Buffer.add_string out line;
            if ended || k + 1 < last || named then Buffer.add_char out '\n'
          end
        end) lines;
      if flag 'c' then Buffer.add_string out ((if named then name ^ ":" else "") ^ string_of_int !count ^ "\n");
      if (flag 'l' && !count <> 0) || (flag 'L' && !count = 0) then Buffer.add_string out (name ^ "\n");
      Console.print caps (Buffer.contents out); flush (Console.stdout caps); Buffer.clear out;
      !count <> 0 in
    let found = match files with
      | [] -> (match contents (Console.stdin_fd caps) with Some text -> search "stdin" text false | None -> false | exception Unix.Unix_error _ -> false)
      | _ ->
          List.fold_left (fun found file ->
            match read_file file with
            | Some text -> search file text (List.length files > 1) || found
            | None -> found
            | exception Fatal (msg, _) -> Console.eprint caps msg; found
            | exception Unix.Unix_error (e, _, _) -> Console.eprint caps (Printf.sprintf "grep: read error on %s: %s\n" file (Unix.error_message e)); found) false files in
    if found then Exit.OK else Exit.Err "no matches"
  with
  | Usage -> Console.eprint caps usage; Exit.Err "usage"
  | Fatal (msg, words) -> Console.eprint caps msg; Exit.Err words

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
