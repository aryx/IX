(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Textures.mli *)

type texture = { name : string; width : int; height : int; width_mask : int; source : Bytes.t; columns : int array }

type t = {
  palette : int array;
  colormaps : Bytes.t;
  textures : texture array;
  flats : Bytes.t array;
  flat_names : string array;
  texture_translation : int array;
  flat_translation : int array;
  sky_flat : int;
  sky : int;
  numbers : (string, int) Hashtbl.t;
}

(* a patch's posts drawn into a texture's column, at [at] in [tex], from
 * the patch's column at [column], its top at [top] (R_DrawColumnInCache) *)
let draw_post (tex : Bytes.t) (height : int) (at : int) (patch : string) (column : int) (top : int) : unit =
  let i = ref column in
  while Wad.u8 patch !i <> 0xff do
    let delta = Wad.u8 patch !i and len = Wad.u8 patch (!i + 1) in
    let src = !i + 3 in
    let pos = top + delta and count = ref len in
    (* (id's bug, kept: above the top, the rows lost at the bottom, the
     * source not moved) *)
    let pos = if pos < 0 then (count := !count + pos; 0) else pos in
    if pos + !count > height then count := height - pos;
    for k = 0 to !count - 1 do Bytes.set tex (at + pos + k) patch.[src + k] done;
    i := !i + len + 4
  done

let power_mask (n : int) : int =
  let j = ref 1 in
  while !j * 2 <= n do j := !j * 2 done;
  !j - 1

(* the rows a column is read for (R_DrawColumn's & 127): what follows
 * the last column is zeros *)
let rows = 128

(* R_GenerateLookup, R_GenerateComposite: the texture's columns that
 * one patch covers are that patch's bytes, where its first post's
 * pixels start; the others are put together, column after column *)
let make_texture (tx : string) (o : int) (patches : Wad.lump option array) : texture =
  let width = Wad.short tx (o + 12) and height = Wad.short tx (o + 14) in
  let placed =
    List.init (Wad.short tx (o + 20)) (fun (p : int) ->
        let po = o + 22 + (10 * p) in
        (Wad.short tx po, Wad.short tx (po + 2), patches.(Wad.short tx (po + 4))))
    |> List.filter_map (fun ((x, y, l) : int * int * Wad.lump option) -> Option.map (fun (l : Wad.lump) -> (x, y, l.data)) l) in
  (* each column's patches *)
  let count = Array.make width 0 and only = Array.make width ("", 0) in
  List.iter
    (fun ((ox, _, d) : int * int * string) ->
      for c = 0 to Wad.short d 0 - 1 do
        let x = ox + c in
        if x >= 0 && x < width then begin
          count.(x) <- count.(x) + 1;
          only.(x) <- (d, Wad.int32 d (8 + (4 * c)) + 3)
        end
      done)
    placed;
  let composite = Array.fold_left (fun (n : int) (k : int) -> if k > 1 then n + height else n) 0 count in
  (* the patches read directly, each once, after the composite *)
  let direct = ref [] and size = ref (composite + rows) in
  Array.iteri
    (fun (x : int) (k : int) ->
      let d, _ = only.(x) in
      if k = 1 && not (List.exists (fun ((d', _) : string * int) -> d' == d) !direct) then begin
        direct := (d, !size) :: !direct;
        size := !size + String.length d + rows
      end)
    count;
  let source = Bytes.make !size '\000' in
  List.iter (fun ((d, at) : string * int) -> Bytes.blit_string d 0 source at (String.length d)) !direct;
  let next = ref 0 in
  let columns =
    Array.init width (fun (x : int) ->
        if count.(x) = 1 then
          let d, ofs = only.(x) in
          List.assq d !direct + ofs
        else begin
          (* (a column no patch covers: zeros, black; id's was what the
           * memory held) *)
          let at = !next in
          if count.(x) > 1 then next := !next + height;
          at
        end) in
  (* the composite: each patch's posts in its columns of more than one *)
  List.iter
    (fun ((ox, oy, d) : int * int * string) ->
      for c = 0 to Wad.short d 0 - 1 do
        let x = ox + c in
        if x >= 0 && x < width && count.(x) > 1 then draw_post source height columns.(x) d (Wad.int32 d (8 + (4 * c))) oy
      done)
    placed;
  { name = Wad.name8 tx o; width; height; width_mask = power_mask width; source; columns }

let load (wad : Wad.t) : t =
  let pal = Wad.get wad "PLAYPAL" in
  let palette = Array.init 256 (fun (i : int) -> (Wad.u8 pal (3 * i) lsl 16) lor (Wad.u8 pal ((3 * i) + 1) lsl 8) lor Wad.u8 pal ((3 * i) + 2)) in
  let colormaps = Bytes.of_string (Wad.get wad "COLORMAP") in
  let pn = Wad.get wad "PNAMES" in
  let patches = Array.init (Wad.int32 pn 0) (fun (k : int) -> Wad.find wad (Wad.name8 pn (4 + (8 * k)))) in
  let tx = Wad.get wad "TEXTURE1" in
  let textures = Array.init (Wad.int32 tx 0) (fun (k : int) -> make_texture tx (Wad.int32 tx (4 + (4 * k))) patches) in
  let flat_lumps = Array.of_list (Wad.between wad "F_START" "F_END") in
  let numbers = Hashtbl.create 512 in
  Array.iteri (fun (k : int) (t : texture) -> Hashtbl.replace numbers ("T" ^ t.name) k) textures;
  Array.iteri (fun (k : int) (l : Wad.lump) -> Hashtbl.replace numbers ("F" ^ l.name) k) flat_lumps;
  let number (key : string) : int = match Hashtbl.find_opt numbers key with Some k -> k | None -> -1 in
  { palette; colormaps; textures;
    flats = Array.map (fun (l : Wad.lump) -> Bytes.of_string l.data) flat_lumps;
    flat_names = Array.map (fun (l : Wad.lump) -> l.name) flat_lumps;
    texture_translation = Array.init (Array.length textures) (fun (k : int) -> k);
    flat_translation = Array.init (Array.length flat_lumps) (fun (k : int) -> k);
    sky_flat = number "FF_SKY1"; sky = max 0 (number "TSKY1"); numbers }

let texture (t : t) (name : string) : int = match Hashtbl.find_opt t.numbers ("T" ^ name) with Some k -> k | None -> -1
let flat (t : t) (name : string) : int = match Hashtbl.find_opt t.numbers ("F" ^ name) with Some k -> k | None -> -1

(* p_spec.c's animdefs: the flats', then the textures' *)
let flat_anims =
  [ [ "NUKAGE1"; "NUKAGE2"; "NUKAGE3" ]; [ "FWATER1"; "FWATER2"; "FWATER3"; "FWATER4" ]; [ "SWATER1"; "SWATER2"; "SWATER3"; "SWATER4" ];
    [ "LAVA1"; "LAVA2"; "LAVA3"; "LAVA4" ]; [ "BLOOD1"; "BLOOD2"; "BLOOD3" ] ]

let texture_anims =
  [ [ "BLODGR1"; "BLODGR2"; "BLODGR3"; "BLODGR4" ]; [ "SLADRIP1"; "SLADRIP2"; "SLADRIP3" ]; [ "BLODRIP1"; "BLODRIP2"; "BLODRIP3"; "BLODRIP4" ];
    [ "FIREWALA"; "FIREWALB"; "FIREWALL" ]; [ "GSTFONT1"; "GSTFONT2"; "GSTFONT3" ]; [ "FIRELAVA"; "FIRELAV3" ];
    [ "FIREMAG1"; "FIREMAG2"; "FIREMAG3" ]; [ "FIREBLU1"; "FIREBLU2" ]; [ "ROCKRED1"; "ROCKRED2"; "ROCKRED3" ];
    [ "BFALL1"; "BFALL2"; "BFALL3"; "BFALL4" ]; [ "SFALL1"; "SFALL2"; "SFALL3"; "SFALL4" ]; [ "WFALL1"; "WFALL2"; "WFALL3"; "WFALL4" ];
    [ "DBRAIN1"; "DBRAIN2"; "DBRAIN3"; "DBRAIN4" ] ]

let animate (t : t) (tic : int) : unit =
  let run (number : string -> int) (translation : int array) (anims : string list list) : unit =
    List.iter
      (fun (names : string list) ->
        let frames = Array.of_list (List.map number names) in
        let n = Array.length frames in
        (* (a WAD that has some frames and not others: none animated) *)
        if Array.for_all (fun (k : int) -> k >= 0) frames then
          Array.iteri (fun (i : int) (k : int) -> translation.(k) <- frames.(((tic / 8) + i) mod n)) frames)
      anims in
  run (flat t) t.flat_translation flat_anims;
  run (texture t) t.texture_translation texture_anims

let switch_of (t : t) (k : int) : int option =
  if k < 0 then None
  else
    let n = t.textures.(k).name in
    if String.length n > 3 && (String.sub n 0 3 = "SW1" || String.sub n 0 3 = "SW2") then
      let other = (if n.[2] = '1' then "SW2" else "SW1") ^ String.sub n 3 (String.length n - 3) in
      let o = texture t other in
      if o >= 0 then Some o else None
    else None
