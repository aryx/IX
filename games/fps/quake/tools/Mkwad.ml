(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-mkwad2: a WAD2 of Quake's textures made from a directory of
 * PNGs (LibreQuake's texture-wads/lq_tech/ ...), what qbsp reads the
 * textures a map names from (the map's "wad" key) and copies into the
 * .bsp. A WAD2 is Doom's WAD grown up:
 *
 *   0   "WAD2", the number of lumps, where the directory is
 *   12  the lumps: here each a miptex
 *   ... the directory, 32 bytes a lump: where, its size twice (packed
 *       and not: never packed), its type ('D', a miptex), a byte of
 *       compression (none), two bytes of nothing, its name (16)
 *
 *   a miptex: its name (16), width, height, four offsets, then the
 *   texture four times, each half the size of the one before (the
 *   mips: 1, 1/4, 1/16, 1/64 of its bytes), a byte a pixel
 *
 * The name of a texture is its file's, but for what a file name cannot
 * say: star_water is *water (a liquid, drawn warped), plus_0button is
 * +0button (an animation's frame), and x_fbr.png is x with its
 * fullbright colours kept (LibreQuake's, as qpakman reads them).
 * Fullbright colours are the palette's last 32 (224 to 255): the
 * colormap keeps them bright in the dark (lamps, screens), so a
 * texture without _fbr is given the nearest colour of the other 224.
 * A transparent pixel (a texture whose name starts with {: a grate)
 * is 255.
 *
 * The mips as id's qlumpy made them: each pixel of a mip the average
 * of the 2 by 2, 4 by 4, 8 by 8 pixels it covers, made the palette's
 * nearest colour.
 *
 * usage: mini-mkwad2 palette.lmp out.wad png-dir... *)

let usage = "usage: mini-mkwad2 palette.lmp out.wad png-dir..."

let palette_of (pal : string) : (int * int * int) array =
  Array.init 256 (fun (i : int) ->
      ( Char.code pal.[3 * i],
        Char.code pal.[(3 * i) + 1],
        Char.code pal.[(3 * i) + 2] ))

(* the nearest colour of the first [n], the first of equals *)
let nearest (pal : (int * int * int) array) (n : int) (r : int) (g : int)
    (b : int) : int =
  let best = ref 0 and best_d = ref max_int in
  for i = 0 to n - 1 do
    let r', g', b' = pal.(i) in
    let d =
      ((r - r') * (r - r')) + ((g - g') * (g - g')) + ((b - b') * (b - b'))
    in
    if d < !best_d then begin
      best := i;
      best_d := d
    end
  done;
  !best

let texture_name (file : string) : string * bool =
  let stem = Filename.remove_extension file in
  let fbr = Filename.check_suffix stem "_fbr" in
  let stem = if fbr then Filename.chop_suffix stem "_fbr" else stem in
  let prefixed (p : string) (c : string) (s : string) : string option =
    let n = String.length p in
    if String.length s > n && String.sub s 0 n = p then
      Some (c ^ String.sub s n (String.length s - n))
    else None
  in
  let name =
    match prefixed "star_" "*" stem with
    | Some s -> s
    | None -> (
        match prefixed "plus_" "+" stem with Some s -> s | None -> stem)
  in
  (name, fbr)

(* a texture's four mips, a byte a pixel *)
let miptex (pal : (int * int * int) array) (name : string) (fbr : bool)
    (img : Rgba_image.t) : string =
  let w = img.width and h = img.height in
  if w mod 16 <> 0 || h mod 16 <> 0 then
    failwith (Printf.sprintf "%s: %d by %d, not multiples of 16" name w h);
  let colours = if fbr then 256 else 224 in
  let transparent = String.length name > 0 && name.[0] = '{' in
  let cache = Hashtbl.create 256 in
  let index (r : int) (g : int) (b : int) : int =
    let key = (r lsl 16) lor (g lsl 8) lor b in
    match Hashtbl.find_opt cache key with
    | Some i -> i
    | None ->
        let i =
          nearest pal (if transparent then min colours 255 else colours) r g b
        in
        Hashtbl.add cache key i;
        i
  in
  let px (x : int) (y : int) (c : int) : int =
    Char.code (Bytes.get img.rgba ((4 * ((y * w) + x)) + c))
  in
  let mip (k : int) : string =
    let s = 1 lsl k in
    let mw = w / s and mh = h / s in
    String.init (mw * mh) (fun (i : int) ->
        let x0 = i mod mw * s and y0 = i / mw * s in
        let r = ref 0 and g = ref 0 and b = ref 0 and seen = ref 0 in
        for y = y0 to y0 + s - 1 do
          for x = x0 to x0 + s - 1 do
            if px x y 3 >= 128 then begin
              r := !r + px x y 0;
              g := !g + px x y 1;
              b := !b + px x y 2;
              incr seen
            end
          done
        done;
        (* (transparent where most of the block is) *)
        if transparent && 2 * !seen < s * s then '\255'
        else if !seen = 0 then Char.chr (index 0 0 0)
        else Char.chr (index (!r / !seen) (!g / !seen) (!b / !seen)))
  in
  let mips = List.init 4 mip in
  let b = Buffer.create (w * h * 2) in
  Bspfile.add_name b 16 name;
  Bspfile.add_int32 b w;
  Bspfile.add_int32 b h;
  ignore
    (List.fold_left
       (fun (pos : int) (m : string) ->
         Bspfile.add_int32 b pos;
         pos + String.length m)
       40 mips);
  List.iter (Buffer.add_string b) mips;
  Buffer.contents b

let wad2 (lumps : (string * string) list) : string =
  let b = Buffer.create 1_000_000 in
  let size =
    List.fold_left
      (fun (n : int) ((_, d) : string * string) -> n + String.length d)
      0 lumps
  in
  Buffer.add_string b "WAD2";
  Bspfile.add_int32 b (List.length lumps);
  Bspfile.add_int32 b (12 + size);
  List.iter (fun ((_, d) : string * string) -> Buffer.add_string b d) lumps;
  ignore
    (List.fold_left
       (fun (pos : int) ((name, d) : string * string) ->
         Bspfile.add_int32 b pos;
         Bspfile.add_int32 b (String.length d);
         Bspfile.add_int32 b (String.length d);
         Buffer.add_string b "D\000\000\000";
         Bspfile.add_name b 16 name;
         pos + String.length d)
       12 lumps);
  Buffer.contents b

let make (caps : < Cap.open_in ; Cap.open_out ; Cap.readdir ; Cap.stdout ; .. >)
    (palette : string) (out : string) (dirs : string list) : unit =
  let pal = palette_of (FS.read caps (Fpath.v palette)) in
  let lumps =
    List.concat_map
      (fun (dir : string) ->
        let files =
          List.sort compare
            (List.map
               (fun (e : Sys_plan9.dir) -> e.name)
               (Sys_plan9.dirread caps dir))
        in
        List.filter_map
          (fun (f : string) ->
            if not (Filename.check_suffix f ".png") then None
            else begin
              let name, fbr = texture_name f in
              if String.length name > 15 then begin
                Console.print caps
                  (Printf.sprintf "%s: a name longer than 15, left out\n" f);
                None
              end
              else
                Some
                  ( name,
                    miptex pal name fbr
                      (Png.decode
                         (FS.read caps (Fpath.v (Filename.concat dir f)))) )
            end)
          files)
      dirs
  in
  let bytes = wad2 lumps in
  FS.write caps (Fpath.v out) bytes;
  Console.print caps
    (Printf.sprintf "%s: %d textures, %d bytes\n" out (List.length lumps)
       (String.length bytes))

let () =
  Cap.main (fun caps ->
      Exit.exit caps @@ Exit.catch
      @@ fun () ->
      (match Array.to_list (CapSys.argv caps) with
      | _ :: palette :: out :: (_ :: _ as dirs) -> make caps palette out dirs
      | _ -> failwith usage);
      Exit.OK)
