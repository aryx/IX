(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See CLI.mli *)
open Ast

type caps = < Run.caps; Cap.argv >

let usage = " [-F fieldsep] [-d] [-mf n] [-mr n] [-safe] [-v var=value] [-f programfile | 'program'] [file ...]\n"

let help = {|usage: mini-awk [-F fieldsep] [-v var=value] [-f programfile | 'program'] [file ...]
Plan 9's awk: a program of pattern { action } rules, run on each line of the
files (or of the standard input), a line split in fields $1, $2... $NF:
  mini-awk '{ print $2, $1 }' file               two columns exchanged
  mini-awk -F: '$3 > 100 { n++ } END { print n }' /etc/passwd
  mini-awk '/error/ { count[$1]++ } END { for (k in count) print k, count[k] }' log
  mini-awk 'BEGIN { printf "%5.2f %s\n", 3.14159, toupper("pi") }'
  mini-awk 'NR == 10, NR == 20' file             the lines 10 to 20
A pattern: an expression, a /regexp/, BEGIN, END, or two for a range. Actions:
print, printf (> file, >> file, | "command"), if else, while, do, for (;;),
for (k in array), break, continue, next, nextfile, exit, delete, getline,
close, and functions (function f(a, b) { ... return x }).
Built in: length substr index match split sub gsub sprintf toupper tolower utf
sin cos atan2 exp log sqrt int rand srand system fflush; NF NR FNR FS OFS RS
ORS FILENAME SUBSEP RSTART RLENGTH CONVFMT ENVIRON ARGC ARGV.
-F t: a tab; -v: an assignment done before BEGIN; a var=value among the files:
one done when it is reached.
|}

(* the program's text: the files of -f one after the other, or the argument *)
type source = { texts : (string option * string) list; all : string }

(* an offset's file and line *)
let where (src : source) offset =
  let rec find start = function
    | [ (name, text) ] -> (name, text, offset - start)
    | (name, text) :: rest -> if offset < start + String.length text then (name, text, offset - start) else find (start + String.length text) rest
    | [] -> (None, "", 0) in
  let name, text, at = find 0 src.texts in
  let line = ref 1 in
  String.iteri (fun k c -> if k < at && c = '\n' then incr line) text;
  (name, !line)

(* lib.c's eprint: the line being read, the last token marked *)
let context (src : source) stop =
  let t = src.all in
  let n = String.length t in
  let stop = min stop n in
  if n = 0 || stop = 0 then ""
  else begin
    let p = ref (stop - 1) in
    if !p > 0 && t.[!p] = '\n' then decr p;
    while !p > 0 && t.[!p] <> '\n' do decr p done;
    while !p < n && t.[!p] = '\n' do incr p done;
    let q = ref (stop - 1) in
    while !q >= !p && t.[!q] <> ' ' && t.[!q] <> '\t' && t.[!q] <> '\n' do decr q done;
    let mid = max !p !q in
    let rest = if not !Lexer.looked_ahead then "" else match String.index_from_opt t stop '\n' with Some e -> String.sub t stop (e - stop) | None -> String.sub t stop (n - stop) in
    Printf.sprintf " context is\n\t%s >>> %s <<< %s\n" (String.sub t !p (mid - !p)) (String.sub t mid (max 0 (stop - mid))) rest
  end

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  let cmd = argv.(0) in
  let args = List.tl (Array.to_list argv) in
  (* (awk's standard error is a Biobuf: what a warning says comes out at
   * the end, or with the next print to /dev/stderr) *)
  let eprint s = Io.flush Io.stdout; Io.write Io.stderr s in
  let finish code = Io.flush Io.stdout; Io.flush Io.stderr; code in
  (* lib.c's error: where the input and the program are; None: before
   * the program is read *)
  let trailer (src : source option) offset running =
    let record =
      if src <> None && Cell.getfval Cell.nr > 0. then begin
        let file = Cell.getsval Cell.filename and n = int_of_float (Cell.getfval Cell.fnr) in
        if file <> "-" then Printf.sprintf " input record %s:%d\n" file n else Printf.sprintf " input record number %d\n" n
      end else "" in
    match src with
    | None -> "\n" ^ record ^ "\n"
    | Some src ->
        let name, line = where src offset in
        "\n" ^ record
        ^ (match name with Some f when not running -> Printf.sprintf " source %s:%d\n" f line | _ -> Printf.sprintf " source line %d\n" line)
        ^ (if running then "" else context src offset) in
  let fatal src offset running msg = eprint (Printf.sprintf "%s: %s%s" cmd msg (trailer src offset running)); finish (Exit.Code 1) in
  if args = [] then (eprint ("usage: " ^ cmd ^ usage); finish (Exit.Code 1))
  else if args = [ "-h" ] || args = [ "--help" ] then (Console.print caps help; Exit.OK)
  else begin
    Cell.warning := (fun msg -> eprint (Printf.sprintf "%s: %s%s" cmd msg (trailer None 0 false)));
    (* the options: -f's files, -F's separator (set after the program is read) *)
    let rec options files fs = function
      | "--" :: rest -> (files, fs, rest)
      | "-safe" :: rest -> options files fs rest
      | "-f" :: file :: rest -> options (files @ [ file ]) fs rest
      | [ "-f" ] -> raise (Cell.Fatal "no program filename")
      | "-F" :: sep :: rest -> options files (Some (if sep = "t" then "\t" else sep)) rest
      | [ "-F" ] -> !Cell.warning "field separator FS is empty"; (files, fs, [])
      | "-v" :: v :: rest -> if Io.is_assignment v then Io.assign v; options files fs rest
      | a :: rest when String.length a > 1 && a.[0] = '-' ->
          if a.[1] = 'F' then begin
            let sep = String.sub a 2 (String.length a - 2) in
            options files (Some (if sep = "t" then "\t" else sep)) rest
          end
          else if a.[1] = 'd' || a.[1] = 's' || a.[1] = 'v' || a.[1] = 'f' then options files fs rest
          else (!Cell.warning (Printf.sprintf "unknown option %s ignored" a); options files fs rest)
      | rest -> (files, fs, rest) in
    match options [] None args with
    | exception Cell.Fatal msg -> fatal None 0 false msg
    | files, fs, rest ->
        match (if files = [] then (match rest with [] -> None | p :: rest -> Some ([ (None, p) ], rest))
               else Some (List.map (fun f ->
                 (Some f, if f = "-" then Procs.read_all (Console.stdin_fd caps)
                  (* (said as the C, which opens the file when it reads its first character) *)
                  else try FS.read caps (Fpath.v f) with Sys_error _ | Unix.Unix_error _ ->
                    raise (Cell.Fatal (Printf.sprintf "can't open file %s\n source %s:1\n context is\n\t >>>  <<< " f f)))) files, rest)) with
        | exception Cell.Fatal msg -> eprint (Printf.sprintf "%s: %s\n" cmd msg); finish (Exit.Code 1)
        | None -> fatal None 0 false "no program given"
        | Some (texts, rest) ->
            let src = { texts; all = String.concat "" (List.map snd texts) } in
            (* ARGV and ARGC, ENVIRON *)
            let argv_table = Cell.array (Cell.install Cell.symtab "ARGV" Cell.unset) in
            List.iteri (fun k a -> ignore (Cell.install argv_table (string_of_int k) (Scalar (Cell.of_input a)))) (cmd :: rest);
            ignore (Cell.install Cell.symtab "ARGC" (Scalar (Cell.of_float (float_of_int (1 + List.length rest)))));
            let environ = Cell.array (Cell.install Cell.symtab "ENVIRON" Cell.unset) in
            List.iter (fun (k, v) -> ignore (Cell.install environ k (Scalar (Cell.of_input v)))) (Procs.split_env (CapUnix.environment caps ()));
            let lexbuf = Lexing.from_string src.all in
            let syntax msg =
              (* where: the end of the rule an action refused, or of the last token *)
              let stop, rest = match !Scope.error_end with
                | Some e -> (e, e < String.length src.all && not (String.contains " \t\n" src.all.[e]))
                | None -> (lexbuf.lex_curr_p.pos_cnum, !Lexer.looked_ahead) in
              Lexer.looked_ahead := rest;
              let at_end = !Lexer.at_end || (!Scope.error_end = None && stop >= String.length src.all && !Lexer.looked_ahead) in
              let name, line = where src (max 0 (stop - 1)) in
              let line = if stop > 0 && stop <= String.length src.all && src.all.[stop - 1] = '\n' then line + 1 else line in
              (* lib.c's bracecheck: what is open at the error and in the text after it *)
              let missing count opening closing =
                let n = ref count in
                String.iteri (fun k c -> if k >= lexbuf.lex_curr_p.pos_cnum then (if c = opening then incr n else if c = closing then decr n)) src.all;
                if !n = 1 then Printf.sprintf "\tmissing %c\n" closing
                else if !n > 1 then Printf.sprintf "\t%d missing %c's\n" !n closing
                else if !n = -1 then Printf.sprintf "\textra %c\n" closing
                else if !n < -1 then Printf.sprintf "\t%d extra %c's\n" (- !n) closing
                else "" in
              eprint (Printf.sprintf "%s: %s at %s%s\n%s%s%s%s" cmd msg
                        (* (at the text's end the C has no file's name any more) *)
                        (match name with Some f when not at_end -> Printf.sprintf "%s:%d" f line | _ -> Printf.sprintf "line %d" line)
                        (match !Scope.function_name with Some f -> " in function " ^ f | None -> "")
                        (if at_end then " context is\n\t >>>  <<< \n" else context src stop)
                        (missing !Lexer.braces '{' '}') (missing !Lexer.brackets '[' ']') (missing !Lexer.parens '(' ')'));
              finish (Exit.Code 1) in
            match Parser.program Lexer.token lexbuf with
            | exception (Parser.Error | Parsing.Parse_error) -> syntax "syntax error"
            | exception Cell.Syntax msg -> syntax msg
            | exception Cell.Fatal msg -> fatal (Some src) lexbuf.lex_curr_p.pos_cnum false msg
            | exception Regex.Error msg -> fatal (Some src) lexbuf.lex_curr_p.pos_cnum false msg
            | program ->
                Option.iter (fun sep -> Cell.setsval Cell.fs (Io.unquote sep)) fs;
                Cell.warning := (fun msg -> eprint (Printf.sprintf "%s: %s%s" cmd msg (trailer (Some src) !Run.position true)));
                match Run.run caps program with
                | () -> finish (if !Run.status = "" then Exit.OK else Exit.Code 1)
                | exception Cell.Fatal msg -> let code = fatal (Some src) !Run.position true msg in Io.close_all caps; code
                | exception Regex.Error msg -> let code = fatal (Some src) !Run.position true msg in Io.close_all caps; code
  end
