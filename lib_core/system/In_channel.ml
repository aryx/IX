(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* See In_channel.mli *)

type t = in_channel

let with_open openfile file f =
  let ic = openfile file in
  Fun.protect ~finally:(fun () -> close_in ic) (fun () -> f ic)

let with_open_bin file f = with_open open_in_bin file f
let with_open_text file f = with_open open_in file f

let input_line ic = try Some (Pervasives.input_line ic) with End_of_file -> None

(* by pieces: a terminal or a pipe has no length to ask for *)
let input_all ic =
  let b = Buffer.create 4096 in
  let piece = Bytes.create 4096 in
  let rec go () =
    let n = input ic piece 0 4096 in
    if n > 0 then begin Buffer.add_substring b piece 0 n; go () end
  in
  go ();
  Buffer.contents b
