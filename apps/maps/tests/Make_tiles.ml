(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* The tests' tiles: [Make_tiles dir zmax] writes dir/z/x/y.png for every
 * zoom up to zmax, each a square with its own z/x/y written on it. So the
 * frames are exact, nothing of OSM's is copied, and a wrong tile shows at
 * once. *)

let digits =
  [| "111101101101111"; "010110010010111"; "111001111100111"; "111001111001111"; "101101111001001";
     "111100111001111"; "111100111101111"; "111001001001001"; "111101111101111"; "111101111001111" |]

let slash = "001001010100100"

let tile (z : int) (x : int) (y : int) : Rgba_image.t =
  let size = Tiles.size in
  let img = Rgba_image.create ~width:size ~height:size in
  let set (px : int) (py : int) ((r, g, b) : int * int * int) : unit =
    let i = 4 * ((py * size) + px) in
    Bytes.set img.rgba i (Char.chr r);
    Bytes.set img.rgba (i + 1) (Char.chr g);
    Bytes.set img.rgba (i + 2) (Char.chr b);
    Bytes.set img.rgba (i + 3) '\255'
  in
  let back = if (x + y) land 1 = 0 then (250, 240, 200) else (190, 225, 240) in
  for py = 0 to size - 1 do
    for px = 0 to size - 1 do
      set px py (if px = 0 || py = 0 then (40, 40, 40) else back)
    done
  done;
  let cell = 5 in
  let letter (at : int) (bits : string) : unit =
    String.iteri
      (fun (i : int) (c : char) ->
        if c = '1' then
          for dy = 0 to cell - 1 do
            for dx = 0 to cell - 1 do
              set (16 + at + ((i mod 3) * cell) + dx) (100 + ((i / 3) * cell) + dy) (0, 0, 0)
            done
          done)
      bits
  in
  let label = Printf.sprintf "%d/%d/%d" z x y in
  String.iteri
    (fun (i : int) (c : char) ->
      letter (i * 4 * cell) (if c = '/' then slash else digits.(Char.code c - Char.code '0')))
    label;
  img

let () =
  let dir = Sys.argv.(1) and zmax = int_of_string Sys.argv.(2) in
  for z = 0 to zmax do
    for x = 0 to (1 lsl z) - 1 do
      let d = Printf.sprintf "%s/%d/%d" dir z x in
      ignore (Sys.command ("mkdir -p " ^ d));
      for y = 0 to (1 lsl z) - 1 do
        let oc = open_out_bin (Printf.sprintf "%s/%d.png" d y) in
        output_string oc (Png.encode ~alpha:false ~filter:(Some 0) (tile z x y));
        close_out oc
      done
    done
  done
