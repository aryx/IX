(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-sed: Plan 9's sed (principia's utilities/text/misc/sed.c), the
 * stream editor: each line of the files, or of the standard input, is
 * put in the pattern space, the script's commands that its addresses
 * choose are run on it, and it is written (not with -n).
 *
 *   sed [-n] [-g] [-e script] [-f file] [script] [file ...]
 *
 * An address: a line's number, $ (the last line), /regexp/ (Regex:
 * regexp(7)'s, mini-ed's and mini-grep's); two, a,b: from one to the
 * other; a ! after: the lines that are not. The commands (a ; or a
 * newline between two):
 *   p print     d delete, next line    q print and end     = the number
 *   s/re/new/[g][p][w file]   & the match, \1..\9 its groups (-g: all g)
 *   y/abc/xyz/  each character for the one at its place
 *   a\ i\ c\    text after, before, in place of (the text on the next lines)
 *   n N         the next line, in place of or added to the pattern space
 *   g G h H x   the hold space: copied from, added from, to, added to, exchanged
 *   D P         of a pattern space of several lines, the first: deleted, printed
 *   l           printed with what cannot be seen made visible
 *   r file  w file      a file's text after, the pattern space to a file
 *   :label  b label  t label   a jump; t when an s changed the line
 *   { ... }     several commands for one address
 *
 * As sed.c, the script is a list of commands and { b t are jumps in it.
 * Its oddities kept, each said where it is: c writes its text only
 * with a line's number or a regexp for address; N at the last line
 * writes nothing; D ends the cycle and the rest is written.
 *
 *     the lines one, two, three, four:
 *     sed -n '/two/,/three/p'      two three          a range printed
 *     sed 's/o/0/g;2q'             0ne tw0            and no more read
 *     sed -n '1!G;h;$p'            four three two one
 *
 * The last one is the hold space at work, sed's only memory from a
 * line to the next: each line but the first gets what is held added
 * after it (G), the whole is held (h), and at the last line it is
 * printed.
 *
 * cs-history:
 * Lee McMahon, Bell Labs, 1973-74. sed is ed with the person taken
 * away: the same addresses and the same commands (s, p, d, a, i, c
 * come from it), but read from a script, and run on each line as
 * it goes by where ed runs each command on a whole file held in its
 * buffer. So it edits a file of any size, and the middle of a
 * pipeline; grep had been one command of ed made a program, sed is
 * all of them. It was in the Seventh Edition (1979).
 *
 * evolution:
 * A line at a time with one buffer on the side is little: a script
 * past a few commands is a puzzle (the reversal above is a known
 * one). awk, a few years later, has fields, variables and arithmetic,
 * and took those jobs; sed is still what one types for s/old/new/. *)

type caps = < Cap.open_in; Cap.open_out; Cap.stdin; Cap.stdout; Cap.stderr >

(* sed.c's quit: said after "sed: ", the status "error" *)
exception Quit of string
(* (the same, already said) *)
exception Said

type address = None_ | Line of int | Last | Re of Regex.t

type piece = Text of string | Whole | Group of int

type action =
  | Append of string | Change of string | Insert of string | Read of string
  | Delete | Delete_first | Number | Get | Get_more | Hold | Hold_more | Exchange
  | Jump of int ref | Jump_if of int ref          (* an index in the script; -1: its end *)
  | List | Next | Next_more | Print | Print_first | Quit_ | Write of Unix.file_descr
  | Subst of Regex.t * piece list * bool * int * Unix.file_descr option  (* all of them; printed: 0, 1 (p), 2 (P) *)
  | Translate of (int, int) Hashtbl.t

type command = { a1 : address; a2 : address; negated : bool; mutable active : int; action : action }

(*****************************************************************************)
(* The script *)
(*****************************************************************************)

(* a script's logical lines: a \ keeps what follows it, a newline too
 * (a's text, a command over two lines) *)
let logical_lines text =
  let lines = ref [] and b = Buffer.create 80 in
  let n = String.length text in
  let rec go k =
    if k >= n then (if Buffer.length b > 0 then lines := Buffer.contents b :: !lines)
    else if text.[k] = '\\' && k + 1 < n then begin Buffer.add_char b '\\'; Buffer.add_char b text.[k + 1]; go (k + 2) end
    else if text.[k] = '\n' then begin lines := Buffer.contents b :: !lines; Buffer.clear b; go (k + 1) end
    else begin Buffer.add_char b text.[k]; go (k + 1) end in
  go 0;
  List.rev !lines

let compile (caps : < caps; .. >) (scripts : string list) (all : bool) : command array =
  let script = ref [] and count = ref 0 in
  let labels = Hashtbl.create 8 and wanted = ref [] and opened = ref [] and files = Hashtbl.create 4 in
  let last_re = ref None in
  let add c = script := c :: !script; incr count in
  let file name =
    match Hashtbl.find_opt files name with
    | Some fd -> fd
    | None ->
        let fd = try FS.open_out_fd caps name 0o666 with Unix.Unix_error _ -> raise (Quit ("Cannot create " ^ name)) in
        Hashtbl.replace files name fd; fd in
  List.iter (fun line ->
    let n = String.length line in
    let at k = if k < n then line.[k] else '\000' in
    let garbled what = raise (Quit (Printf.sprintf "%s command garbled: %s" what line)) in
    let rec blanks k = if at k = ' ' || at k = '\t' then blanks (k + 1) else k in
    (* a regexp from k to its delimiter (\delimiter is it, \n a newline):
     * None for an empty one, the one before; and where it ends *)
    let regexp k delim =
      let b = Buffer.create 16 in
      let rec go k =
        if k >= n then raise (Quit ("Too much text: " ^ line))
        else if line.[k] = delim then k + 1
        else if line.[k] = '\\' && k + 1 < n then begin
          (if line.[k + 1] = delim then Buffer.add_char b delim
           else if line.[k + 1] = 'n' then Buffer.add_char b '\n'
           else begin Buffer.add_char b '\\'; Buffer.add_char b line.[k + 1] end);
          go (k + 2)
        end
        else begin Buffer.add_char b line.[k]; go (k + 1) end in
      let k = go k in
      if Buffer.length b = 0 then None, k
      else begin
        let re = try Regex.compile (Buffer.contents b) with Regex.Error m -> raise (Quit (Printf.sprintf "%s: %s" m line)) in
        last_re := Some re; Some re, k
      end in
    let address k =
      match at k with
      | '$' -> Last, k + 1
      | '/' -> (match regexp (k + 1) '/' with
                | Some re, k -> Re re, k
                | None, k -> (match !last_re with Some re -> Re re, k | None -> raise (Quit "First RE may not be null")))
      | '0' .. '9' ->
          let rec digits j = if at j >= '0' && at j <= '9' then digits (j + 1) else j in
          let j = digits k in
          let v = int_of_string (String.sub line k (j - k)) in
          if v = 0 then raise (Quit "line number 0 is illegal");
          Line v, j
      | _ -> None_, k in
    (* what follows a command to the line's end: a text (its \ taken
     * out, the blanks at its start and after its newlines too), a name *)
    let text k =
      let b = Buffer.create 32 in
      let rec go k =
        if k < n then begin
          let c, k = if line.[k] = '\\' then (if k + 1 < n then line.[k + 1], k + 2 else '\000', n) else line.[k], k + 1 in
          if c <> '\000' then begin Buffer.add_char b c; go (if c = '\n' then blanks k else k) end
        end in
      go (blanks k); Buffer.contents b in
    let rec command k =
      let k = blanks k in
      (* (a ; before a command, and an empty line or a comment) *)
      let k = if at k = ';' then blanks (k + 1) else k in
      if k >= n || at k = '#' then ()
      else begin
        let a1, k = address k in
        let a2, k = if a1 <> None_ && (at k = ',' || at k = ';') then address (k + 1) else None_, k in
        let k = blanks k in
        let rec bangs k neg = if at k = '!' then bangs (k + 1) true else k, neg in
        let k, negated = bangs k false in
        let one () = if a2 <> None_ then raise (Quit ("Only one address allowed: " ^ line)) in
        let none () = if a1 <> None_ then raise (Quit ("No addresses allowed: " ^ line)) in
        let put action = add { a1; a2; negated; active = 0; action } in
        (* a's, i's and c's text: after a \ and a newline *)
        let lines_after k what = let k = if at k = '\\' then k + 1 else k in if at k <> '\n' then garbled what; text (k + 1) in
        let label k = let k = blanks k in let rec last j = if j < n && line.[j] <> ';' then last (j + 1) else j in let j = last k in String.sub line k (j - k), j in
        let jump k make =
          let name, j = label k in
          let target = ref (-1) in
          if name <> "" then wanted := (name, target) :: !wanted;
          put (make target); after j
        and simple action = put action; after (k + 1) in
        match at k with
        | '{' ->
            (* the commands to its } are jumped over when the address does not choose the line *)
            let target = ref (-1) in
            add { a1; a2; negated = not negated; active = 0; action = Jump target };
            opened := target :: !opened;
            command (k + 1)
        | '}' ->
            none ();
            (match !opened with t :: rest -> t := !count; opened := rest | [] -> raise (Quit "Too many }'s"));
            command (k + 1)
        | '=' -> one (); simple Number
        | ':' ->
            none ();
            let name, j = label (k + 1) in
            if name = "" then garbled ":";
            if Hashtbl.mem labels name then raise (Quit ("Duplicate labels: " ^ line));
            Hashtbl.replace labels name !count;
            after j
        | 'a' -> one (); put (Append (lines_after (k + 1) "a"))
        | 'i' -> one (); put (Insert (lines_after (k + 1) "i"))
        | 'c' -> put (Change (lines_after (k + 1) "c"))
        | 'r' -> one (); if at (k + 1) <> ' ' then garbled "r"; put (Read (text (k + 2)))
        | 'w' -> if at (k + 1) <> ' ' then garbled "w"; put (Write (file (text (k + 2))))
        | 'b' -> jump (k + 1) (fun t -> Jump t)
        | 't' -> jump (k + 1) (fun t -> Jump_if t)
        | 'g' -> simple Get | 'G' -> simple Get_more | 'h' -> simple Hold | 'H' -> simple Hold_more | 'x' -> simple Exchange
        | 'n' -> simple Next | 'N' -> simple Next_more | 'p' -> simple Print | 'P' -> simple Print_first
        | 'd' -> simple Delete | 'D' -> simple Delete_first | 'l' -> simple List
        | 'q' -> one (); simple Quit_
        | 's' ->
            let delim = at (k + 1) in
            let re, j = regexp (k + 2) delim in
            let re = match re, !last_re with Some re, _ -> re | None, Some re -> re | None, None -> raise (Quit "First RE may not be null.") in
            (* what it becomes: & the match, \1 to \9 a group, \n a newline, \c c *)
            let pieces = ref [] and b = Buffer.create 16 in
            let flush () = if Buffer.length b > 0 then begin pieces := Text (Buffer.contents b) :: !pieces; Buffer.clear b end in
            let rec rhs j =
              if j >= n then garbled "s"
              else if line.[j] = delim then j + 1
              else if line.[j] = '\\' && j + 1 < n then begin
                (match line.[j + 1] with
                 | '1' .. '9' as d -> flush (); pieces := Group (Char.code d - 48) :: !pieces
                 | 'n' -> Buffer.add_char b '\n'
                 | c -> Buffer.add_char b c);
                rhs (j + 2)
              end
              else if line.[j] = '&' then begin flush (); pieces := Whole :: !pieces; rhs (j + 1) end
              else begin Buffer.add_char b line.[j]; rhs (j + 1) end in
            let j = rhs j in
            flush ();
            let global, j = if at j = 'g' then true, j + 1 else all, j in
            let print, j = if at j = 'p' then 1, j + 1 else 0, j in
            let print, j = if at j = 'P' then 2, j + 1 else print, j in
            if at j = 'w' then begin
              if at (j + 1) <> ' ' then garbled "s";
              put (Subst (re, List.rev !pieces, global, print, Some (file (text (j + 2)))))
            end
            else begin put (Subst (re, List.rev !pieces, global, print, None)); after j end
        | 'y' ->
            let delim = at (k + 1) in
            (* the characters of each half, a \delimiter and a \n as in a regexp *)
            let rec half j acc =
              if j >= n then garbled "y"
              else if line.[j] = delim then List.rev acc, j + 1
              else if line.[j] = '\\' && j + 1 < n && (line.[j + 1] = delim || line.[j + 1] = 'n' || line.[j + 1] = '\\') then
                half (j + 2) ((if line.[j + 1] = 'n' then 10 else Char.code line.[j + 1]) :: acc)
              else let r, w = Utf8.decode line j in half (j + w) (r :: acc) in
            let from, j = half (k + 2) [] in
            let into, j = half j [] in
            if List.length from <> List.length into then garbled "y";
            let table = Hashtbl.create 16 in
            List.iter2 (fun f t -> Hashtbl.replace table f t) from into;
            put (Translate table); after j
        | _ -> raise (Quit ("Unrecognized command: " ^ line))
      end
    (* after a command: the line's end, or a ; and another *)
    and after k =
      if k >= n then ()
      else if line.[k] = ';' then command (k + 1)
      else raise (Quit (Printf.sprintf "%s command garbled: %s" (String.sub line k (n - k)) line)) in
    command 0) (List.concat_map logical_lines scripts);
  if !opened <> [] then raise (Quit "Too many {'s");
  List.iter (fun (name, target) ->
    match Hashtbl.find_opt labels name with Some k -> target := k | None -> raise (Quit ("Undefined label: " ^ name))) !wanted;
  Array.of_list (List.rev !script)

(*****************************************************************************)
(* The lines *)
(*****************************************************************************)

(* l's: a character that cannot be seen *)
let visible r =
  match r with
  | 8 -> "\\b" | 10 -> "\\n" | 13 -> "\\r" | 9 -> "\\t" | 92 -> "\\\\"
  | r when r >= 0x20 && r < 0x7f -> String.make 1 (Char.chr r)
  | r -> Printf.sprintf "\\x%04x" (r land 0xffff)

exception Ended

let run (caps : < caps; .. >) (script : command array) (quiet : bool) (names : string list) : unit =
  let out = Buffer.create 8192 in
  let flush () = Console.print caps (Buffer.contents out); flush (Console.stdout caps); Buffer.clear out in
  let put s = Buffer.add_string out s; Buffer.add_char out '\n'; if Buffer.length out > 8192 then flush () in
  (* the files' lines, one after the other as one text: the lines left
   * of the file being read, the files left (None: the standard input) *)
  let lines = ref [] and files = ref (if names = [] then [ None ] else List.map (fun n -> Some n) names) in
  let rec next_line () =
    match !lines, !files with
    | l :: rest, _ -> lines := rest; Some l
    | [], [] -> None
    | [], name :: rest ->
        files := rest;
        let fd = match name with
          | None -> Console.stdin_fd caps
          | Some n -> (try FS.open_in_fd caps n with Unix.Unix_error _ -> raise (Quit ("Can't open " ^ n))) in
        let all = Buffer.create 8192 and buf = Bytes.create 8192 in
        let rec read () = match Unix.read fd buf 0 8192 with 0 -> () | k -> Buffer.add_subbytes all buf 0 k; read () | exception Unix.Unix_error _ -> () in
        read ();
        let text = Buffer.contents all in
        let l = String.split_on_char '\n' text in
        (* (a last line without its newline is a line) *)
        lines := (if text = "" || text.[String.length text - 1] = '\n' then List.filteri (fun k _ -> k < List.length l - 1) l else l);
        next_line () in
  let last () = !lines = [] && !files = [] in
  let space = ref "" and hold = ref "" and number = ref 0 and changed = ref false in
  (* a's texts and r's files, written after the line *)
  let pending = ref [] in
  let appends () =
    List.iter (function
      | Append t -> put t
      | Read name ->
          (match FS.open_in_fd caps name with
           | exception Unix.Unix_error _ -> ()
           | fd ->
               let buf = Bytes.create 8192 in
               let rec copy () = match Unix.read fd buf 0 8192 with 0 -> () | k -> Buffer.add_subbytes out buf 0 k; copy () | exception Unix.Unix_error _ -> () in
               copy (); Unix.close fd)
      | _ -> ()) (List.rev !pending);
    pending := [] in
  let write fd s = ignore (Unix.write_substring fd (s ^ "\n") 0 (String.length s + 1)) in
  let first_line s = match String.index_opt s '\n' with Some k -> String.sub s 0 k | None -> s in
  (* does the command's address choose this line? (sed.c's executable:
   * [active] is 1 on a range's first line, 2 after, 0 outside) *)
  let chosen (c : command) =
    let yes = not c.negated in
    let in_range =
      if c.active = 0 then None
      else begin
        if c.active = 1 then c.active <- 2;
        match c.a2 with
        | None_ -> c.active <- 0; None
        | Last -> Some yes
        | Line l -> if !number <= l then begin if l = !number then c.active <- 0; Some yes end else begin c.active <- 0; Some (not yes) end
        | Re re -> if Regex.exec re !space 0 <> None then c.active <- 0; Some yes
      end in
    match in_range with
    | Some answer -> answer
    | None ->
        match c.a1 with
        | None_ -> yes
        | Last -> if last () then yes else not yes
        | Line l -> if l = !number then begin c.active <- 1; yes end else not yes
        | Re re -> if Regex.exec re !space 0 <> None then begin c.active <- 1; yes end else not yes in
  let substitute re pieces global =
    let replace (m : (int * int) array) =
      String.concat "" (List.map (function
        | Text t -> t
        | Whole -> String.sub !space (fst m.(0)) (snd m.(0) - fst m.(0))
        | Group g ->
            if g >= Array.length m || fst m.(g) < 0 then begin flush (); Console.eprint caps (Printf.sprintf "sed: Invalid back reference \\%d\n" g); raise Ended end;
            String.sub !space (fst m.(g)) (snd m.(g) - fst m.(g))) pieces) in
    (* each match from a place on: the text between, then what it
     * becomes; after an empty match, a character further *)
    let rec go from any =
      match Regex.exec re !space from with
      | None -> any
      | Some m ->
          let s, e = m.(0) in
          let by = replace m in
          space := String.sub !space 0 s ^ by ^ String.sub !space e (String.length !space - e);
          let e = s + String.length by in
          let e = if s = snd m.(0) then e + 1 else e in
          if global && e < String.length !space then go e true else true in
    go 0 false in
  (try
     let rec cycle () =
       match next_line () with
       | None -> ()
       | Some l ->
           space := l; incr number; changed := false;
           let deleted = ref false in
           (* the commands from one on; a jump is another place in them *)
           let rec from k =
             if k >= 0 && k < Array.length script && not !deleted then begin
               let c = script.(k) in
               if not (chosen c) then from (k + 1)
               else match c.action with
                 | Append _ | Read _ -> pending := c.action :: !pending; from (k + 1)
                 (* (c's text only on a range's first line: [active] is 1 there, and
                  * 0 when the address is none or $: sed.c's) *)
                 | Change t -> deleted := true; if c.active = 1 then put t
                 | Insert t -> put t; from (k + 1)
                 | Delete -> deleted := true
                 (* (D: the first line taken out, and the cycle ends: what is left is written) *)
                 | Delete_first ->
                     (match String.index_opt !space '\n' with
                      | Some j -> space := String.sub !space (j + 1) (String.length !space - j - 1)
                      | None -> deleted := true)
                 | Number -> put (string_of_int !number); from (k + 1)
                 | Get -> space := !hold; from (k + 1)
                 | Get_more -> space := !space ^ "\n" ^ !hold; from (k + 1)
                 | Hold -> hold := !space; from (k + 1)
                 | Hold_more -> hold := !hold ^ "\n" ^ !space; from (k + 1)
                 | Exchange -> let s = !space in space := !hold; hold := s; from (k + 1)
                 | Jump target -> from !target
                 | Jump_if target -> if !changed then begin changed := false; from !target end else from (k + 1)
                 | List ->
                     (* 72 characters a line, a \ where it is cut *)
                     let b = Buffer.create 80 and width = ref 0 and at = ref 0 and final = ref 0 in
                     while !at < String.length !space do
                       let r, w = Utf8.decode !space !at in
                       at := !at + w; final := r;
                       String.iter (fun ch -> Buffer.add_char b ch; incr width; if !width > 72 then begin Buffer.add_string b "\\\n"; width := 0 end) (visible r)
                     done;
                     if !final = 32 then Buffer.add_string b "\\n";
                     put (Buffer.contents b); from (k + 1)
                 | Next ->
                     if not quiet then put !space;
                     appends ();
                     (match next_line () with
                      | Some l -> space := l; incr number; changed := false; from (k + 1)
                      | None -> deleted := true)
                 (* (N at the last line: nothing more is written, sed.c's) *)
                 | Next_more ->
                     appends ();
                     (match next_line () with
                      | Some l -> space := !space ^ "\n" ^ l; incr number; changed := false; from (k + 1)
                      | None -> deleted := true)
                 | Print -> put !space; from (k + 1)
                 | Print_first -> put (first_line !space); from (k + 1)
                 | Quit_ -> if not quiet then put !space; appends (); raise Ended
                 | Write fd -> write fd !space; from (k + 1)
                 | Subst (re, pieces, global, print, file) ->
                     if substitute re pieces global then begin
                       changed := true;
                       if print = 1 then put !space else if print = 2 then put (first_line !space);
                       (match file with Some fd -> write fd !space | None -> ())
                     end;
                     from (k + 1)
                 | Translate table ->
                     let b = Buffer.create (String.length !space) in
                     let rec each at = if at < String.length !space then begin
                       let r, w = Utf8.decode !space at in
                       Utf8.add b (match Hashtbl.find_opt table r with Some t -> t | None -> r); each (at + w) end in
                     each 0; space := Buffer.contents b; from (k + 1)
             end in
           from 0;
           if not quiet && not !deleted then put !space;
           appends ();
           cycle () in
     cycle ()
   with
   | Ended -> ()
   (* (said before what was written and not yet shown, as sed.c's output is kept) *)
   | Quit msg -> Console.eprint caps (Printf.sprintf "sed: %s\n" msg); flush (); raise Said);
  flush ()

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  try
    let quiet = ref false and all = ref false and scripts = ref [] in
    let rec options = function
      | "--" :: rest -> rest
      | a :: rest when String.length a > 1 && a.[0] = '-' ->
          let rec letters k rest =
            if k >= String.length a then options rest
            else match a.[k] with
              | 'n' -> quiet := true; letters (k + 1) rest
              | 'g' -> all := true; letters (k + 1) rest
              | ('e' | 'f') as c ->
                  let v, rest =
                    if k + 1 < String.length a then String.sub a (k + 1) (String.length a - k - 1), rest
                    else match rest with v :: rest -> v, rest | [] -> raise (Quit (if c = 'e' then "missing pattern" else "no pattern-file")) in
                  scripts := !scripts @ [ (if c = 'e' then v else try FS.read caps (Fpath.v v) with Sys_error _ | Invalid_argument _ -> raise (Quit (Printf.sprintf "Cannot open pattern-file: %s\n" v))) ];
                  options rest
              | c -> Console.eprint caps (Printf.sprintf "sed: Unknown flag: %c\n" c); letters (k + 1) rest in
          letters 1 rest
      | rest -> rest in
    match List.tl (Array.to_list argv) with
    | [] -> Exit.OK
    | args ->
        let rest = options args in
        let scripts, files = match !scripts, rest with
          | [], script :: files -> [ script ], files
          | [], [] -> raise (Quit "missing pattern")
          | scripts, files -> scripts, files in
        run caps (compile caps scripts !all) !quiet files;
        Exit.OK
  with
  | Quit msg -> Console.eprint caps (Printf.sprintf "sed: %s\n" msg); Exit.Err "error"
  | Said -> Exit.Err "error"

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
