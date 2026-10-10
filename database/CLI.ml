(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See CLI.mli *)

let usage = "Usage: chidb [-c COMMAND] [DATABASE]\n"

(* --help: how, by examples, each one as it runs *)
let help = {|usage: mini-chidb [-c COMMAND] [-v] [-h] [DATABASE]
chidb's twin: SQL compiled to a register machine over B-trees of fixed pages.
A statement a line at the prompt chidb> (printed even when the input is not a
terminal, as chidb's is), until the end of the input; or -c, the one command:
  mini-chidb books.cdb
  chidb> CREATE TABLE books (id INTEGER PRIMARY KEY, title TEXT, year INTEGER);
  chidb> INSERT INTO books VALUES (1, 'SICP', 1985);
  chidb> SELECT * FROM books WHERE year > 1980;
  1|SICP|1985
  mini-chidb -c 'SELECT title FROM books;' books.cdb
.help lists the dot commands (.open FILE, .headers on, .mode column, .opt "SQL").
-h: chidb's usage line; -v, repeated: more traces.
|}

(* getopt's "c:vh", GNU's: options anywhere, -vv, -cCOMMAND *)
type args = { command : string option; verbosity : int; files : string list }

exception Bad_option of string   (* getopt's message *)

let parse_args prog argv =
  let rec go acc = function
    | [] -> { acc with files = List.rev acc.files }
    | "--" :: rest -> { acc with files = List.rev_append acc.files rest }
    | a :: rest when String.length a > 1 && a.[0] = '-' ->
        let rec letters acc i rest =
          if i >= String.length a then go acc rest
          else match a.[i] with
            | 'v' -> letters { acc with verbosity = acc.verbosity + 1 } (i + 1) rest
            | 'h' -> print_string usage; exit 0
            | 'c' ->
                if i + 1 < String.length a then go { acc with command = Some (String.sub a (i + 1) (String.length a - i - 1)) } rest
                else (match rest with
                  | c :: rest -> go { acc with command = Some c } rest
                  | [] -> raise (Bad_option (Printf.sprintf "%s: option requires an argument -- 'c'" prog)))
            | c -> raise (Bad_option (Printf.sprintf "%s: invalid option -- '%c'" prog c))
        in
        letters acc 1 rest
    | f :: rest -> go { acc with files = f :: acc.files } rest
  in
  go { command = None; verbosity = 0; files = [] } argv

let main (caps : < Shell.caps; Cap.argv; .. >) =
  let argv = Array.to_list (CapSys.argv caps) in
  if List.mem "--help" argv then (Console.print caps help; exit 0);
  match parse_args (List.hd argv) (List.tl argv) with
  | exception Bad_option m -> prerr_endline m; print_string "ERROR: Unknown option -?\n"; 255
  | args ->
      if args.verbosity > 0 then Logs.set_level (Some (if args.verbosity = 1 then Logs.Info else Logs.Debug));
      let t = Shell.create (caps :> Shell.caps) in
      if (match args.files with f :: _ -> not (Shell.open_db t f) | [] -> false) then 1
      else begin
        (match args.command with
         | Some c -> if c <> "" then Shell.handle t c
         | None ->
             let rec loop () =
               print_string "chidb> ";
               flush stdout;
               match In_channel.input_line stdin with
               | None -> print_string "\n"
               | Some line -> if line <> "" then Shell.handle t line; loop ()
             in
             loop ());
        flush stdout;
        Shell.close t;
        0
      end
