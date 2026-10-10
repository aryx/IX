(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's mini-chrome's languages/javascript/library/Js_json.ml (its 8af888e) (docs/plans/plan_browser.md) *)

(* See Js_json.mli *)
open Js_value

let parse (s : string) : value =
  let n = String.length s in
  let pos = ref 0 in
  let fail () =
    throw "SyntaxError"
      (if !pos >= n then "Unexpected end of JSON input" else Printf.sprintf "Unexpected token '%c', at position %d of the JSON" s.[!pos] !pos)
  in
  let rec skip () = if !pos < n && (s.[!pos] = ' ' || s.[!pos] = '\n' || s.[!pos] = '\t' || s.[!pos] = '\r') then (incr pos; skip ()) in
  let expect (c : char) = skip (); if !pos < n && s.[!pos] = c then incr pos else fail () in
  let word (w : string) (v : value) : value =
    if !pos + String.length w <= n && String.sub s !pos (String.length w) = w then (pos := !pos + String.length w; v) else fail ()
  in
  (* "...": its escapes decoded, a \uXXXX as UTF-8 *)
  let string () : string =
    expect '"';
    let b = Buffer.create 16 in
    let rec go () =
      if !pos >= n then fail ()
      else
        match s.[!pos] with
        | '"' -> incr pos
        | '\\' when !pos + 1 < n ->
            (match s.[!pos + 1] with
            | 'n' -> Buffer.add_char b '\n'
            | 't' -> Buffer.add_char b '\t'
            | 'r' -> Buffer.add_char b '\r'
            | 'b' -> Buffer.add_char b '\b'
            | 'f' -> Buffer.add_char b '\012'
            | 'u' when !pos + 5 < n -> (
                match int_of_string_opt ("0x" ^ String.sub s (!pos + 2) 4) with
                | Some code -> Buffer.add_string b (Js_lexer.utf_8 code); pos := !pos + 4
                | None -> fail ())
            | ('"' | '\\' | '/') as c -> Buffer.add_char b c
            | _ -> fail ());
            pos := !pos + 2;
            go ()
        | c when c < ' ' -> fail ()
        | c -> Buffer.add_char b c; incr pos; go ()
    in
    go ();
    Js_utf16.joined (Buffer.contents b)
  in
  let number () : value =
    let start = !pos in
    while !pos < n && (match s.[!pos] with '0' .. '9' | '-' | '+' | '.' | 'e' | 'E' -> true | _ -> false) do incr pos done;
    match float_of_string_opt (String.sub s start (!pos - start)) with Some f when !pos > start -> Number f | _ -> pos := start; fail ()
  in
  (* items between [open_] (read already) and [close], separated by commas *)
  let items (close : char) item =
    skip ();
    if !pos < n && s.[!pos] = close then (incr pos; [])
    else
      let rec more acc =
        let acc = item () :: acc in
        skip ();
        if !pos < n && s.[!pos] = ',' then (incr pos; more acc) else (expect close; List.rev acc)
      in
      more []
  in
  let rec value () : value =
    skip ();
    if !pos >= n then fail ()
    else
      match s.[!pos] with
      | '{' ->
          incr pos;
          let o = new_object () in
          List.iter (fun (k, v) -> set_own o k v) (items '}' (fun () -> skip (); let k = string () in expect ':'; (k, value ())));
          Object o
      | '[' -> incr pos; Object (new_array (items ']' value))
      | '"' -> String (string ())
      | 't' -> word "true" (Bool true)
      | 'f' -> word "false" (Bool false)
      | 'n' -> word "null" Null
      | _ -> number ()
  in
  let v = value () in
  skip ();
  if !pos < n then fail () else v
