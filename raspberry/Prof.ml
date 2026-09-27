(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* See Prof.mli *)

let on = ref false
let period = ref 1024
let left = ref 1024
let counts : (int, int ref) Hashtbl.t = Hashtbl.create 4096

let start ~every = on := true; period := every; left := every

(* a countdown, not a modulo: the sampling costs a decrement and a test *)
let tick pc =
  decr left;
  if !left = 0 then begin
    left := !period;
    match Hashtbl.find_opt counts pc with
    | Some n -> incr n
    | None -> Hashtbl.add counts pc (ref 1)
  end

let contents () =
  let l = Hashtbl.fold (fun pc n acc -> (pc, !n) :: acc) counts [] in
  let l = List.sort (fun (_, a) (_, b) -> compare b a) l in
  String.concat "" (List.map (fun (pc, n) -> Printf.sprintf "%x %d\n" pc n) l)
