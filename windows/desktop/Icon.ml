(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Icon.mli *)

type t = { w : int; h : int; pixels : string }

let is_palette l = String.length l = 8 && l.[1] = ' ' && int_of_string_opt ("0x" ^ String.sub l 2 6) <> None

let parse text =
  let lines = List.filter (fun l -> l <> "" && l.[0] <> '#') (List.map String.trim (String.split_on_char '\n' text)) in
  let palette, rows = List.partition is_palette lines in
  let colour = List.map (fun l -> (l.[0], int_of_string ("0x" ^ String.sub l 2 6))) palette in
  match rows with
  | [] -> None
  | first :: _ ->
      let w = String.length first and h = List.length rows in
      if List.exists (fun r -> String.length r <> w) rows then None
      else if List.exists (fun r -> String.exists (fun c -> c <> '.' && not (List.mem_assoc c colour)) r) rows then None
      else begin
        let b = Bytes.make (w * h * 4) '\000' in
        List.iteri (fun y r ->
            String.iteri (fun x c ->
                if c <> '.' then begin
                  let v = List.assoc c colour and o = ((y * w) + x) * 4 in
                  Bytes.set b o '\255';
                  Bytes.set b (o + 1) (Char.chr (v land 255));
                  Bytes.set b (o + 2) (Char.chr ((v lsr 8) land 255));
                  Bytes.set b (o + 3) (Char.chr ((v lsr 16) land 255))
                end) r) rows;
        Some { w; h; pixels = Bytes.to_string b }
      end

let doubled i =
  let b = Bytes.create (i.w * i.h * 16) in
  for y = 0 to (2 * i.h) - 1 do
    for x = 0 to (2 * i.w) - 1 do
      Bytes.blit_string i.pixels ((((y / 2) * i.w) + (x / 2)) * 4) b (((y * 2 * i.w) + x) * 4) 4
    done
  done;
  { w = 2 * i.w; h = 2 * i.h; pixels = Bytes.to_string b }
