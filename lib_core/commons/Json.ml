(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Json.mli *)

open Common

type t = Null | Bool of bool | Int of int | String of string | List of t list | Assoc of (string * t) list

exception Error of string

let error fmt = Printf.ksprintf (fun m -> raise (Error m)) fmt

(*****************************************************************************)
(* Printing *)
(*****************************************************************************)

let quote s =
  let b = Buffer.create (String.length s + 2) in
  Buffer.add_char b '"';
  String.iter (fun c ->
    match c with
    | '"' -> Buffer.add_string b "\\\""
    | '\\' -> Buffer.add_string b "\\\\"
    | '\n' -> Buffer.add_string b "\\n"
    | '\r' -> Buffer.add_string b "\\r"
    | '\t' -> Buffer.add_string b "\\t"
    | c when Char.code c < 0x20 -> Buffer.add_string b (Printf.sprintf "\\u%04x" (Char.code c))
    | c -> Buffer.add_char b c) s;
  Buffer.add_char b '"';
  Buffer.contents b

let rec to_text = function
  | Null -> "null"
  | Bool b -> string_of_bool b
  | Int n -> string_of_int n
  | String s -> quote s
  | List l -> "[" ^ String.concat "," (List.map to_text l) ^ "]"
  | Assoc fs -> "{" ^ String.concat "," (List.map (fun (k, v) -> quote k ^ ":" ^ to_text v) fs) ^ "}"

(*****************************************************************************)
(* Parsing *)
(*****************************************************************************)

let of_text s =
  let n = String.length s and i = ref 0 in
  let rec blanks () = if !i < n && String.contains " \t\r\n" s.[!i] then (incr i; blanks ()) in
  let peek () = blanks (); if !i < n then s.[!i] else error "unexpected end" in
  let expect c = if peek () = c then incr i else error "'%c' expected at %d" c !i in
  let word w v = if !i + String.length w <= n && String.sub s !i (String.length w) = w then (i := !i + String.length w; v) else error "bad token at %d" !i in
  let str () =
    expect '"';
    let b = Buffer.create 16 in
    let rec go () =
      if !i >= n then error "unterminated string";
      let c = s.[!i] in
      incr i;
      if c = '"' then Buffer.contents b
      else if c <> '\\' then (Buffer.add_char b c; go ())
      else begin
        if !i >= n then error "unterminated string";
        let e = s.[!i] in
        incr i;
        (match e with
         | 'n' -> Buffer.add_char b '\n' | 't' -> Buffer.add_char b '\t' | 'r' -> Buffer.add_char b '\r'
         | 'b' -> Buffer.add_char b '\b' | 'f' -> Buffer.add_char b '\012'
         | 'u' when !i + 4 <= n -> Utf8.add b (int_of_string ("0x" ^ String.sub s !i 4)); i := !i + 4
         | c -> Buffer.add_char b c);
        go ()
      end
    in
    go ()
  in
  let rec value () =
    match peek () with
    | '{' ->
        incr i;
        if peek () = '}' then (incr i; Assoc [])
        else
          let rec fields acc =
            let k = str () in
            expect ':';
            let acc = (k, value ()) :: acc in
            match peek () with ',' -> incr i; fields acc | _ -> expect '}'; Assoc (List.rev acc)
          in
          fields []
    | '[' ->
        incr i;
        if peek () = ']' then (incr i; List [])
        else
          let rec items acc =
            let acc = value () :: acc in
            match peek () with ',' -> incr i; items acc | _ -> expect ']'; List (List.rev acc)
          in
          items []
    | '"' -> String (str ())
    | 't' -> word "true" (Bool true)
    | 'f' -> word "false" (Bool false)
    | 'n' -> word "null" Null
    | c when c = '-' || (c >= '0' && c <= '9') ->
        let start = !i in
        incr i;
        while !i < n && s.[!i] >= '0' && s.[!i] <= '9' do incr i done;
        Int (int_of_string (String.sub s start (!i - start)))
    | c -> error "unexpected '%c' at %d" c !i
  in
  let v = value () in
  blanks ();
  if !i < n then error "garbage after the value at %d" !i;
  v

(*****************************************************************************)
(* Access *)
(*****************************************************************************)

let member k = function Assoc fs -> (List.assoc_opt k fs ||| Null) | _ -> error "%s: not an object" k
let string = function String s -> s | _ -> error "a string expected"
let int = function Int n -> n | _ -> error "an integer expected"
let bool = function Bool b -> b | _ -> error "a boolean expected"
let list = function List l -> l | _ -> error "an array expected"
