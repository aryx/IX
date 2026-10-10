(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-wc: Plan 9's wc (principia's utilities/misc/wc.c; xix's
 * utilities/files/wc.ml is the author's in OCaml): each file's lines,
 * words and bytes, or the standard input's, and their total when there
 * are several. -l, -w, -c: only those; -r: the characters (UTF-8's,
 * not the bytes); -b: the bytes that are no character. A word is what
 * is between spaces, Unicode's. *)

type caps = < Cap.open_in; Cap.stdin; Cap.stdout; Cap.stderr >

exception Usage

(* lines, words, characters, bad ones, bytes *)
type counts = { mutable lines : int; mutable words : int; mutable runes : int; mutable bad : int; mutable bytes : int }

(* libc's isspacerune *)
let is_space r =
  (r >= 0x9 && r <= 0xd) || r = 0x20 || r = 0x85 || r = 0xa0 || r = 0x1680 || (r >= 0x2000 && r <= 0x200b)
  || r = 0x2028 || r = 0x2029 || r = 0x202f || r = 0x205f || r = 0x3000 || r = 0xfeff

let count (text : string) : counts =
  let c = { lines = 0; words = 0; runes = 0; bad = 0; bytes = String.length text } in
  let rec go at in_word =
    if at < c.bytes then begin
      let r, n = Utf8.decode text at in
      c.runes <- c.runes + 1;
      if r = 0xFFFD then begin c.bad <- c.bad + 1; go (at + n) in_word end
      else begin
        if r = Char.code '\n' then c.lines <- c.lines + 1;
        if not in_word && not (is_space r) then c.words <- c.words + 1;
        go (at + n) (not (is_space r))
      end
    end in
  go 0 false;
  c

(* all of a descriptor (what cannot be read, a directory, is its end) *)
let contents (fd : Unix.file_descr) =
  let all = Buffer.create 8192 and buf = Bytes.create 8192 in
  let rec go () = match Unix.read fd buf 0 8192 with 0 -> () | n -> Buffer.add_subbytes all buf 0 n; go () | exception Unix.Unix_error _ -> () in
  go (); Buffer.contents all

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  try
    let asked = ref [] in
    let rec options = function
      | "--" :: rest -> rest
      | a :: rest when String.length a > 1 && a.[0] = '-' ->
          String.iteri (fun k c -> if k > 0 then (if String.contains "lwrbc" c then asked := c :: !asked else raise Usage)) a;
          options rest
      | rest -> rest in
    let files = options (List.tl (Array.to_list argv)) in
    let asked = if !asked = [] then [ 'l'; 'w'; 'c' ] else !asked in
    (* the columns in wc.c's order, whatever the options' *)
    let report (c : counts) name =
      let columns = List.filter_map (fun (letter, v) -> if List.mem letter asked then Some (Printf.sprintf "%7d" v) else None)
          [ 'l', c.lines; 'w', c.words; 'r', c.runes; 'b', c.bad; 'c', c.bytes ] in
      Console.print caps (String.concat " " (columns @ (match name with Some n -> [ n ] | None -> [])) ^ "\n") in
    match files with
    | [] -> report (count (contents (Console.stdin_fd caps))) None; Exit.OK
    | _ ->
        let total = { lines = 0; words = 0; runes = 0; bad = 0; bytes = 0 } and failed = ref false in
        List.iter (fun file ->
          match FS.open_in_fd caps file with
          | exception Unix.Unix_error (e, _, _) -> Console.eprint caps (Printf.sprintf "%s: %s\n" file (Unix.error_message e)); failed := true
          | fd ->
              let c = Fun.protect ~finally:(fun () -> Unix.close fd) (fun () -> count (contents fd)) in
              total.lines <- total.lines + c.lines; total.words <- total.words + c.words; total.runes <- total.runes + c.runes;
              total.bad <- total.bad + c.bad; total.bytes <- total.bytes + c.bytes;
              report c (Some file)) files;
        if List.length files > 1 then report total (Some "total");
        if !failed then Exit.Err "can't open" else Exit.OK
  with Usage -> Console.eprint caps (Printf.sprintf "Usage: %s [-lwrbc] [file ...]\n" argv.(0)); Exit.Err "usage"

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
