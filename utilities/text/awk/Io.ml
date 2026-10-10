(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Io.mli *)
open Ast

type caps = < Cap.open_in; Cap.open_out; Cap.stdin; Cap.stdout; Cap.stderr; Cap.fork; Cap.exec; Cap.wait; Cap.env >

type mode = Read | Write | Append | Command_in | Command_out

(* a descriptor with what was read of it and not taken, or what was
 * written to it and not sent (a Biobuf); a command's has its process *)
type stream = {
  fd : Unix.file_descr;
  input : Bytes.t;
  mutable pos : int;
  mutable len : int;
  output : Buffer.t;
  pid : int option;
}

let size = 8192
let stream fd pid = { fd; input = Bytes.create size; pos = 0; len = 0; output = Buffer.create 256; pid }

let stdin = stream Unix.stdin None
let stdout = stream Unix.stdout None
let stderr = stream Unix.stderr None
let is_stdout s = s == stdout

let rec getc s =
  if s.pos < s.len then (s.pos <- s.pos + 1; Char.code (Bytes.get s.input (s.pos - 1)))
  else match Unix.read s.fd s.input 0 size with
    | 0 -> -1
    | n -> s.pos <- 0; s.len <- n; getc s
    | exception Unix.Unix_error _ -> -1

let write s text = Buffer.add_string s.output text

let flush s =
  if Buffer.length s.output > 0 then begin
    Procs.write_all s.fd (Buffer.contents s.output);
    Buffer.clear s.output
  end

(* run.c's files: a name, how it was opened, its stream *)
let files : (string * mode * stream) list ref =
  ref [ ("/dev/stdin", Read, stdin); ("/dev/stdout", Write, stdout); ("/dev/stderr", Write, stderr) ]

let max_files = 40

let writing mode = mode = Write || mode = Command_out

let flush_all () = List.iter (fun (_, mode, s) -> if writing mode then flush s) !files

let written name =
  List.find_map (fun (n, mode, s) -> if n = name && writing mode then Some s else None) !files

(* the shell a command is given to, as the C: rc *)
let shell (caps : < caps; .. >) cmd ~stdin ~stdout = Procs.spawn caps "/bin/rc" [ "-c"; cmd ] ~stdin ~stdout

let open_ (caps : < caps; .. >) mode name =
  if name = "" then raise (Cell.Fatal "null file name in print or getline");
  (* (an Append is kept as a Write: > and >> of one name are one file) *)
  let kept = if mode = Append then Write else mode in
  match List.find_opt (fun (n, m, _) -> n = name && m = kept) !files with
  | Some (_, _, s) -> Some s
  | None ->
      if List.length !files >= max_files then raise (Cell.Fatal (name ^ " makes too many open files"));
      flush stdout;
      let opened =
        try
          match mode with
          | Write -> Some (stream (FS.open_out_fd caps name 0o666) None)
          | Append -> Some (stream (FS.open_append_fd caps name 0o666) None)
          | Read -> Some (if name = "-" then stdin else stream (FS.open_in_fd caps name) None)
          | Command_out ->
              let r, w = Unix.pipe ~cloexec:true () in
              let pid = shell caps name ~stdin:r ~stdout:Unix.stdout in
              Unix.close r;
              Some (stream w (Some pid))
          | Command_in ->
              let r, w = Unix.pipe ~cloexec:true () in
              let pid = shell caps name ~stdin:Unix.stdin ~stdout:w in
              Unix.close w;
              Some (stream r (Some pid))
        with Unix.Unix_error _ | Sys_error _ -> None in
      Option.iter (fun s -> files := !files @ [ (name, kept, s) ]) opened;
      opened

let finish (caps : < caps; .. >) ((_, mode, s) : string * mode * stream) =
  if writing mode then flush s;
  if s != stdin && s != stdout && s != stderr then (try Unix.close s.fd with Unix.Unix_error _ -> ());
  Option.iter (fun pid -> ignore (Procs.waitpid caps pid)) s.pid

let close (caps : < caps; .. >) name =
  let closed, kept = List.partition (fun (n, _, _) -> n = name) !files in
  List.iter (finish caps) closed;
  files := kept

let close_all (caps : < caps; .. >) = List.iter (finish caps) !files; files := []

let system (caps : < caps; .. >) cmd =
  flush stdout;
  let pid = shell caps cmd ~stdin:Unix.stdin ~stdout:Unix.stdout in
  match Procs.waitpid caps pid with Unix.WEXITED 0 -> 0 | _ -> 1

let read_record s =
  Cell.remember_fs ();
  let rs = Cell.getsval Cell.rs in
  let b = Buffer.create 128 in
  let newline = Char.code '\n' in
  let sep = if rs = "" then newline else Char.code rs.[0] in
  (* a paragraph: the newlines before it are passed *)
  if rs = "" then begin
    let rec skip () = let c = getc s in if c = newline then skip () else if c >= 0 then s.pos <- s.pos - 1 in
    skip ()
  end;
  let rec line () =
    let c = getc s in
    if c <> sep && c >= 0 then (Buffer.add_char b (Char.chr c); line ())
    else if rs <> "" || c < 0 then c
    else begin
      (* two newlines in a row end a paragraph *)
      let c = getc s in
      if c = newline || c < 0 then c else (Buffer.add_char b '\n'; Buffer.add_char b (Char.chr c); line ())
    end in
  let last = line () in
  if last < 0 && Buffer.length b = 0 then None else Some (Buffer.contents b)

let is_assignment s =
  let n = String.length s in
  let letter c = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c = '_' in
  let rec name k = if k < n && (letter s.[k] || (s.[k] >= '0' && s.[k] <= '9')) then name (k + 1) else k in
  n > 0 && letter s.[0] && (let k = name 0 in k < n && s.[k] = '=' && not (k + 1 < n && s.[k + 1] = '='))

(* tran.c's qstring: a value's escapes *)
let unquote s =
  let n = String.length s in
  let b = Buffer.create n in
  let digit k = k < n && s.[k] >= '0' && s.[k] <= '9' in
  let rec go k =
    if k < n then
      if s.[k] <> '\\' then (Buffer.add_char b s.[k]; go (k + 1))
      else if k + 1 >= n then Buffer.add_char b '\\'
      else match s.[k + 1] with
        | '\\' -> Buffer.add_char b '\\'; go (k + 2)
        | 'n' -> Buffer.add_char b '\n'; go (k + 2)
        | 't' -> Buffer.add_char b '\t'; go (k + 2)
        | 'b' -> Buffer.add_char b '\b'; go (k + 2)
        | 'f' -> Buffer.add_char b '\012'; go (k + 2)
        | 'r' -> Buffer.add_char b '\r'; go (k + 2)
        | '0' .. '9' ->
            let rec digits j v = if j < k + 4 && digit j then digits (j + 1) ((8 * v) + Char.code s.[j] - 48) else (j, v) in
            let j, v = digits (k + 1) 0 in
            Buffer.add_char b (Char.chr (v land 255)); go j
        | c -> Buffer.add_char b c; go (k + 2) in
  go 0;
  Buffer.contents b

let assign s =
  let k = String.index s '=' in
  let c = Cell.install Cell.symtab (String.sub s 0 k) Cell.unset in
  Cell.setsval c "";
  c.v <- Scalar (Cell.of_input (unquote (String.sub s (k + 1) (String.length s - k - 1))))

(* lib.c's getrec: the file being read, and which argument is next *)
let current : stream option ref = ref None
let argno = ref 1
let started = ref false

let argument n =
  match Cell.lookup Cell.symtab "ARGV" with
  | Some { v = Array t; _ } -> (match Cell.lookup t (string_of_int n) with Some c -> Cell.getsval c | None -> "")
  | _ -> ""

let argc () = match Cell.lookup Cell.symtab "ARGC" with Some c -> int_of_float (Cell.getfval c) | None -> 0

let next_file () =
  (match !current with Some s when s != stdin -> (try Unix.close s.fd with Unix.Unix_error _ -> ()) | _ -> ());
  current := None;
  incr argno

let rec next_record (caps : < caps; .. >) =
  if not !started then begin
    started := true;
    (* the assignments before the first file; with no file at all, the standard input *)
    let rec first k =
      if k >= argc () then current := Some stdin
      else if is_assignment (argument k) then (assign (argument k); incr argno; first (k + 1))
      else Cell.setsval Cell.filename (argument k) in
    first 1
  end;
  if not (!argno < argc () || (match !current with Some s -> s == stdin | None -> false)) then None
  else match !current with
    | None ->
        let file = argument !argno in
        if file = "" then (incr argno; next_record caps)
        else if is_assignment file then (assign file; incr argno; next_record caps)
        else begin
          Cell.setsval Cell.filename file;
          current := Some (if file = "-" then stdin
            else try stream (FS.open_in_fd caps file) None
              with Unix.Unix_error _ | Sys_error _ -> raise (Cell.Fatal ("can't open file " ^ file)));
          Cell.setfval Cell.fnr 0.;
          next_record caps
        end
    | Some s ->
        match read_record s with
        | Some r ->
            Cell.setfval Cell.nr (Cell.getfval Cell.nr +. 1.);
            Cell.setfval Cell.fnr (Cell.getfval Cell.fnr +. 1.);
            Some r
        | None -> next_file (); next_record caps
