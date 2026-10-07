(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Input.mli *)

type caps = < Cap.open_in; Cap.stdin; Cap.stderr >

(* what was read of a descriptor and not yet taken (a Biobuf); -e's
 * text has no descriptor *)
type source = { fd : Unix.file_descr option; buf : Bytes.t; mutable pos : int; mutable len : int }

let size = 8192
let of_fd fd = { fd = Some fd; buf = Bytes.create size; pos = 0; len = 0 }

let program = ref "hoc"
let args : string list ref = ref []
let file : string option ref = ref None
let lineno = ref 1
let last = ref (Char.code '\n')

(* the standard input's is kept from one - to the next *)
let nothing = { fd = None; buf = Bytes.empty; pos = 0; len = 0 }
let stdin_source = ref nothing
let current = ref nothing

let start (caps : < caps; .. >) name arguments =
  program := name;
  stdin_source := of_fd (Console.stdin_fd caps);
  args := if arguments = [] then [ "-" ] else arguments

let rec more (caps : < caps; .. >) =
  match !args with
  | [] -> false
  | arg :: rest ->
      args := rest;
      (match !current.fd with Some fd when !current != !stdin_source -> Unix.close fd | _ -> ());
      lineno := 1;
      let text s = current := { fd = None; buf = Bytes.of_string (s ^ "\n"); pos = 0; len = String.length s + 1 }; file := Some "-e"; true in
      if arg = "-" then (current := !stdin_source; file := None; true)
      else if arg = "-e" then
        (match rest with
         | expr :: rest -> args := rest; text expr
         | [] -> Console.eprint caps (Printf.sprintf "%s: no argument for -e\n" !program); false)
      else if String.length arg > 2 && String.sub arg 0 2 = "-e" then text (String.sub arg 2 (String.length arg - 2))
      else
        match FS.open_in_fd caps arg with
        | fd -> current := of_fd fd; file := Some arg; true
        | exception Unix.Unix_error _ -> Console.eprint caps (Printf.sprintf "%s: can't open %s\n" !program arg); more caps

let rec getc () =
  let s = !current in
  if s.pos < s.len then begin
    s.pos <- s.pos + 1;
    Char.code (Bytes.get s.buf (s.pos - 1))
  end else
    match s.fd with
    | None -> -1
    | Some fd ->
        (match Unix.read fd s.buf 0 size with
         | 0 -> -1
         | n -> s.pos <- 0; s.len <- n; getc ()
         | exception Unix.Unix_error _ -> -1)

let ungetc () = !current.pos <- !current.pos - 1

let number next =
  let c = ref (next ()) in
  let digit () = !c >= Char.code '0' && !c <= Char.code '9' in
  let sign () = !c = Char.code '-' || !c = Char.code '+' in
  let num = ref 0. and digits = ref 0 and exp = ref 0 and neg = ref false and exp_neg = ref false in
  let digits_to count =
    while digit () do
      num := (!num *. 10.) +. float_of_int (!c - Char.code '0');
      if count then incr digits;
      c := next ()
    done in
  if sign () then (neg := !c = Char.code '-'; c := next ());
  digits_to false;
  if !c = Char.code '.' then c := next ();
  digits_to true;
  if !c = Char.code 'e' || !c = Char.code 'E' then begin
    c := next ();
    if sign () then begin
      if !c = Char.code '-' then (digits := - !digits; exp_neg := true);
      c := next ()
    end;
    while digit () do exp := (!exp * 10) + !c - Char.code '0'; c := next () done
  end;
  exp := !exp - !digits;
  if !exp < 0 then (exp := - !exp; exp_neg := not !exp_neg);
  let power = 10. ** float_of_int !exp in
  let v = if !exp_neg then !num /. power else !num *. power in
  ((if !neg then -. v else v), !c)

let recover () =
  while !last <> Char.code '\n' && !last >= 0 do
    last := getc ();
    if !last = Char.code '\n' then incr lineno
  done;
  let s = !current in
  s.pos <- s.len;
  match s.fd with
  | Some fd -> (try ignore (Unix.lseek fd 0 Unix.SEEK_END) with Unix.Unix_error _ -> ())
  | None -> ()
