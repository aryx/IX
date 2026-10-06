(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Out.mli *)

let to_stderr = ref false
let listf = ref false
let listn = ref false

let buf = Buffer.create 128
let col = ref 0

let flush () =
  let s = Buffer.contents buf in
  Buffer.clear buf;
  let fd = if !to_stderr then Unix.stderr else Unix.stdout in
  let rec write off = if off < String.length s then write (off + Unix.write_substring fd s off (String.length s - off)) in
  write 0

let hex = "0123456789abcdef"

let putchr (c : int) =
  let add = Buffer.add_char buf in
  let c =
    if not !listf then c
    else if c = Char.code '\n' then begin
      let n = Buffer.length buf in
      if n > 0 && Buffer.nth buf (n - 1) = ' ' then (add '\\'; add 'n');
      c
    end
    else begin
      if !col > 64 then (col := 8; add '\\'; add '\n'; add '\t');
      incr col;
      match Char.chr (min c 255) with
      | ('\b' | '\t' | '\\') as ch when c < 128 ->
          add '\\';
          incr col;
          Char.code (match ch with '\b' -> 'b' | '\t' -> 't' | _ -> '\\')
      | _ when c < 32 || c >= 127 ->
          add '\\';
          add 'x';
          List.iter (fun s -> add hex.[(c lsr s) land 15]) [ 12; 8; 4 ];
          col := !col + 5;
          Char.code hex.[c land 15]
      | _ -> c
    end
  in
  Utf8.add buf c;
  if c = Char.code '\n' then flush ()

let putst s =
  col := 0;
  let i = ref 0 in
  while !i < String.length s do
    let c, n = Utf8.decode s !i in
    putchr c;
    i := !i + n
  done;
  putchr (Char.code '\n')

let rec putd n =
  if n >= 10 then putd (n / 10);
  putchr (Char.code '0' + (n mod 10))
