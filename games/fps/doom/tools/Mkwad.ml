(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-mkwad: mini-doom's WAD made from Freedoom's source tree (its
 * git repository, github.com/freedoom/freedoom: levels/, patches/,
 * flats/, lumps/), the few lumps the given levels need:
 *
 *   PLAYPAL   the palette (lumps/playpal/playpal-base.lmp), one of
 *             Doom's fourteen: the others are its tints (pain, items)
 *   COLORMAP  34 maps of 256 indices: 32 levels of light, each the
 *             palette blended towards black by (32 - i) / 32 then the
 *             nearest colour of the palette; the inverse one; black
 *             (Freedoom's lumps/colormap/colormap script, the same
 *             numbers)
 *   E1M1 ...  each level's lumps as levels/e1m1.wad has them, its
 *             nodes built
 *   TEXTURE1, PNAMES  the textures the levels' sides name, from
 *             lumps/textures/textures.cfg (with DOOM1_VERSIONS: Doom
 *             1's sky), and the switches' other face, the animations'
 *             other frames
 *   the patches they are made of, each a PNG of patches/ made Doom's
 *             picture (columns of posts, its transparent pixels left
 *             out), its colours the palette's nearest
 *   F_START ... F_END  the flats the sectors name, 64 by 64 bytes
 *   S_START ... S_END  the sprites of the levels' things, and those of
 *             the states mini-doom has (Info: the weapons, the shots'
 *             puffs and blood, the fireballs, the barrel's blast)
 *   DSPISTOL ...  the sounds mini-doom makes (Info.sounds), each
 *             sounds/ds*.wav (8 bits, one channel) made DMX's lump
 *   D_E1M1 ...  each level's music, musics/d_*.mid, as MIDI (Freedoom's
 *             WADs keep it so; id's kept MUS)
 *
 * usage: mini-mkwad freedoom-dir out.wad E1M1 [MAP...]
 *
 * deutex is what Freedoom builds its WADs with (and its own
 * build-textures script, in Python); this is the part of both that a
 * walk through a level needs, in OCaml (no Python in ix's build). *)

let usage = "usage: mini-mkwad freedoom-dir out.wad E1M1 [MAP...]"

(*****************************************************************************)
(* The palette and its light *)
(*****************************************************************************)

let palette_of (pal : string) : (float * float * float) array =
  Array.init 256 (fun (i : int) -> (float (Wad.u8 pal (3 * i)), float (Wad.u8 pal ((3 * i) + 1)), float (Wad.u8 pal ((3 * i) + 2))))

(* the nearest colour, the first of equals (colormap's search_palette) *)
let nearest (pal : (float * float * float) array) ((r, g, b) : float * float * float) : int =
  let best = ref 0 and best_d = ref infinity in
  Array.iteri
    (fun (i : int) ((r', g', b') : float * float * float) ->
      let d = ((r -. r') *. (r -. r')) +. ((g -. g') *. (g -. g')) +. ((b -. b') *. (b -. b')) in
      if d < !best_d then begin best := i; best_d := d end)
    pal;
  !best

let colormap (pal : (float * float * float) array) : string =
  let b = Buffer.create (34 * 256) in
  let add (f : int -> float * float * float) : unit = for c = 0 to 255 do Buffer.add_char b (Char.chr (nearest pal (f c))) done in
  for i = 0 to 31 do
    let k = float (32 - i) /. 32. in
    add (fun (c : int) -> let r, g, bl = pal.(c) in (r *. k, g *. k, bl *. k))
  done;
  (* (Python's round: halves to even) *)
  let round_even (v : float) : float =
    let f = Float.floor v in
    if v -. f > 0.5 then f +. 1. else if v -. f < 0.5 then f else if Float.rem f 2. = 0. then f else f +. 1. in
  add (fun (c : int) ->
      let r, g, bl = pal.(c) in
      let inv = 255. -. round_even ((r *. 0.2126) +. (g *. 0.7152) +. (bl *. 0.0722)) in
      (inv, inv, inv));
  add (fun (_ : int) -> (0., 0., 0.));
  Buffer.contents b

(* a picture's pixels as the palette's indices, -1 where transparent
 * (its alpha, or deutex's cyan) *)
let indices (pal : (float * float * float) array) (cache : (int, int) Hashtbl.t) (img : Rgba_image.t) : int array =
  Array.init (img.width * img.height) (fun (i : int) ->
      let c (k : int) : int = Char.code (Bytes.get img.rgba ((4 * i) + k)) in
      let r = c 0 and g = c 1 and b = c 2 in
      if c 3 < 128 || (r = 0 && g = 255 && b = 255) then -1
      else
        let key = (r lsl 16) lor (g lsl 8) lor b in
        match Hashtbl.find_opt cache key with
        | Some k -> k
        | None ->
            let k = nearest pal (float r, float g, float b) in
            Hashtbl.replace cache key k;
            k)

(*****************************************************************************)
(* Pictures *)
(*****************************************************************************)

(* Doom's picture (a patch, a sprite): its size and offsets, where each
 * column starts, then each column's posts (a run of opaque pixels: its
 * first row, its length, a byte unused, the pixels, a byte unused),
 * 255 its end. A post starts at row 254 at most. *)
let patch_of (w : int) (h : int) ((left, top) : int * int) (px : int array) : string =
  let cols = Buffer.create 4096 in
  let starts = Array.make w 0 in
  for x = 0 to w - 1 do
    starts.(x) <- (8 + (4 * w)) + Buffer.length cols;
    let y = ref 0 in
    while !y < h do
      if px.((!y * w) + x) < 0 then incr y
      else begin
        let y0 = !y in
        while !y < h && px.((!y * w) + x) >= 0 && !y - y0 < 128 do incr y done;
        if y0 > 254 then failwith "a picture taller than Doom's posts can say";
        Buffer.add_char cols (Char.chr y0);
        Buffer.add_char cols (Char.chr (!y - y0));
        Buffer.add_char cols '\000';
        for k = y0 to !y - 1 do Buffer.add_char cols (Char.chr px.((k * w) + x)) done;
        Buffer.add_char cols '\000'
      end
    done;
    Buffer.add_char cols '\255'
  done;
  let b = Buffer.create (8 + (4 * w) + Buffer.length cols) in
  Wad.add_short b w;
  Wad.add_short b h;
  Wad.add_short b left;
  Wad.add_short b top;
  Array.iter (Wad.add_int32 b) starts;
  Buffer.add_buffer b cols;
  Buffer.contents b

(* a PNG's offsets, ZDoom's grAb chunk (two ints, big-endian) *)
let grab (png : string) : int * int =
  match List.assoc_opt "grAb" (Png.chunks png) with
  | Some d when String.length d = 8 ->
      let be (i : int) : int =
        let v = (Char.code d.[i] lsl 24) lor (Char.code d.[i + 1] lsl 16) lor (Char.code d.[i + 2] lsl 8) lor Char.code d.[i + 3] in
        if v >= 0x80000000 then v - 0x100000000 else v in
      (be 0, be 4)
  | _ -> (0, 0)

(*****************************************************************************)
(* Textures *)
(*****************************************************************************)

(* a texture: its size and its patches, each at an offset *)
type texture = { tname : string; width : int; height : int; patches : (string * int * int) list }

let words (l : string) : string list = List.filter (fun (w : string) -> w <> "") (String.split_on_char ' ' (String.map (fun (c : char) -> if c = '\t' then ' ' else c) l))

(* a file's lines through the few lines of cpp Freedoom's have
 * (#ifdef, #ifndef, #else, #endif; #define and #include left out),
 * [defined] defined, each line's words, its remark (;) cut *)
let cpp (defined : string list) (text : string) : string list list =
  let stack = ref [] in
  let on () : bool = List.for_all (fun (b : bool) -> b) !stack in
  List.filter_map
    (fun (line : string) ->
      let line = match String.index_opt line ';' with Some i -> String.sub line 0 i | None -> line in
      match words line with
      | "#ifdef" :: d :: _ -> stack := List.mem d defined :: !stack; None
      | "#ifndef" :: d :: _ -> stack := not (List.mem d defined) :: !stack; None
      | "#else" :: _ -> (match !stack with b :: rest -> stack := not b :: rest | [] -> failwith "#else alone"); None
      | "#endif" :: _ -> (match !stack with _ :: rest -> stack := rest | [] -> failwith "#endif alone"); None
      | ("#define" | "#undef" | "#include") :: _ -> None
      | w when on () -> Some w
      | _ -> None)
    (String.split_on_char '\n' text)

(* textures.cfg, DOOM1_VERSIONS defined *)
let textures_of (cfg : string) : texture list =
  let acc = ref [] in
  List.iter
    (fun (w : string list) ->
      match w with
      | "*" :: p :: x :: y :: _ -> (
          match !acc with
          | t :: rest -> acc := { t with patches = t.patches @ [ (String.uppercase_ascii p, int_of_string x, int_of_string y) ] } :: rest
          | [] -> failwith "a patch before any texture")
      (* (and a remark after, at times: "SLADAGN 64 128 : AGM version of sladwall.") *)
      | n :: w :: h :: _ when int_of_string_opt w <> None -> acc := { tname = String.uppercase_ascii n; width = int_of_string w; height = int_of_string h; patches = [] } :: !acc
      | [] -> ()
      | _ -> failwith ("textures.cfg: " ^ String.concat " " w))
    (cpp [ "DOOM1_VERSIONS" ] cfg);
  (* (a name defined twice: the last, as the C preprocessor's file read
   * by deutex keeps; there is none once #ifdef is followed) *)
  List.rev !acc

(* Doom's animations (p_spec.c's animdefs): a frame used, all its
 * frames kept; and a switch's other face (p_switch.c's alphSwitchList,
 * SW1 and SW2) *)
let flat_anims =
  [ [ "NUKAGE1"; "NUKAGE2"; "NUKAGE3" ]; [ "FWATER1"; "FWATER2"; "FWATER3"; "FWATER4" ]; [ "SWATER1"; "SWATER2"; "SWATER3"; "SWATER4" ];
    [ "LAVA1"; "LAVA2"; "LAVA3"; "LAVA4" ]; [ "BLOOD1"; "BLOOD2"; "BLOOD3" ] ]

let texture_anims =
  [ [ "BLODGR1"; "BLODGR2"; "BLODGR3"; "BLODGR4" ]; [ "SLADRIP1"; "SLADRIP2"; "SLADRIP3" ]; [ "BLODRIP1"; "BLODRIP2"; "BLODRIP3"; "BLODRIP4" ];
    [ "FIREWALA"; "FIREWALB"; "FIREWALL" ]; [ "GSTFONT1"; "GSTFONT2"; "GSTFONT3" ]; [ "FIRELAVA"; "FIRELAV3" ];
    [ "FIREMAG1"; "FIREMAG2"; "FIREMAG3" ]; [ "FIREBLU1"; "FIREBLU2" ]; [ "ROCKRED1"; "ROCKRED2"; "ROCKRED3" ];
    [ "BFALL1"; "BFALL2"; "BFALL3"; "BFALL4" ]; [ "SFALL1"; "SFALL2"; "SFALL3"; "SFALL4" ]; [ "WFALL1"; "WFALL2"; "WFALL3"; "WFALL4" ];
    [ "DBRAIN1"; "DBRAIN2"; "DBRAIN3"; "DBRAIN4" ] ]

let with_anims (anims : string list list) (names : string list) : string list =
  List.concat_map (fun (n : string) -> match List.find_opt (List.mem n) anims with Some a -> a | None -> [ n ]) names

let with_switches (names : string list) : string list =
  List.concat_map
    (fun (n : string) ->
      if String.length n > 3 && (String.sub n 0 3 = "SW1" || String.sub n 0 3 = "SW2") then
        let rest = String.sub n 3 (String.length n - 3) in
        [ "SW1" ^ rest; "SW2" ^ rest ]
      else [ n ])
    names

let uniq (l : string list) : string list =
  List.rev (List.fold_left (fun (acc : string list) (x : string) -> if List.mem x acc then acc else x :: acc) [] l)

(*****************************************************************************)
(* Sounds *)
(*****************************************************************************)

(* a WAV of 8 bits, one channel, as DMX's sound lump: 3, the rate, the
 * length with the pads, the first sample 16 times, the samples, the
 * last 16 times (what deutex makes of it) *)
let dmx_of_wav (name : string) (wav : string) : string =
  let le32 (i : int) : int = Wad.int32 wav i in
  let rec chunks (i : int) (acc : (string * int * int) list)
      : (string * int * int) list =
    if i + 8 > String.length wav then acc
    else
      let n = le32 (i + 4) in
      chunks (i + 8 + n + (n land 1)) ((String.sub wav i 4, i + 8, n) :: acc) in
  let all = chunks 12 [] in
  let find (id : string) : int * int =
    match List.find_opt (fun ((c, _, _) : string * int * int) -> c = id) all with
    | Some (_, at, n) -> (at, n)
    | None -> failwith (name ^ ": no " ^ id ^ " chunk") in
  let fmt, _ = find "fmt " and data, n = find "data" in
  if Wad.short wav (fmt + 2) <> 1 || Wad.short wav (fmt + 14) <> 8 then
    failwith (name ^ ": not 8 bits, one channel");
  let samples = String.sub wav data n in
  let b = Buffer.create (n + 40) in
  Wad.add_short b 3;
  Wad.add_short b (le32 (fmt + 4));
  Wad.add_int32 b (n + 32);
  Buffer.add_string b (String.make 16 (if n > 0 then samples.[0] else '\128'));
  Buffer.add_string b samples;
  Buffer.add_string b (String.make 16 (if n > 0 then samples.[n - 1] else '\128'));
  Buffer.contents b

(*****************************************************************************)
(* Entry point *)
(*****************************************************************************)

(* buildcfg.txt's [sprites]: each sprite's lump, its offsets (Phase 1:
 * Freedoom's Doom, not Doom II's nor FreeDM's) *)
let sprites_of (cfg : string) : (string * int * int) list =
  let section = ref "" in
  List.filter_map
    (fun (w : string list) ->
      match w with
      | [ s ] when String.length s > 2 && s.[0] = '[' -> section := s; None
      | n :: x :: y :: _ when !section = "[sprites]" -> (
          match (int_of_string_opt x, int_of_string_opt y) with Some x, Some y -> Some (String.uppercase_ascii n, x, y) | _ -> None)
      | _ -> None)
    (cpp [ "PHASE1" ] cfg)

let level_lumps = [ "THINGS"; "LINEDEFS"; "SIDEDEFS"; "VERTEXES"; "SEGS"; "SSECTORS"; "NODES"; "SECTORS"; "REJECT"; "BLOCKMAP" ]

let make (caps : < Cap.open_in ; Cap.open_out ; Cap.stdout ; .. >) (dir : string) (out : string) (maps : string list) : unit =
  let read (path : string) : string = FS.read caps (Fpath.v (Filename.concat dir path)) in
  let pal_bytes = read "lumps/playpal/playpal-base.lmp" in
  let pal = palette_of pal_bytes in
  let cache = Hashtbl.create 1024 in
  (* the levels, and what their sides and sectors name *)
  let levels =
    List.map
      (fun (m : string) ->
        let wad = Wad.parse (read (Printf.sprintf "levels/%s.wad" (String.lowercase_ascii m))) in
        (m, List.map (fun (n : string) -> { Wad.name = n; data = Wad.get wad n }) level_lumps))
      maps in
  let names_in (lump : string) (size : int) (offsets : int list) : string list =
    List.concat_map
      (fun ((_, lumps) : string * Wad.lump list) ->
        let d = (List.find (fun (l : Wad.lump) -> l.name = lump) lumps).data in
        List.concat (List.init (String.length d / size) (fun (k : int) -> List.map (fun (o : int) -> Wad.name8 d ((k * size) + o)) offsets)))
      levels
    |> List.filter (fun (n : string) -> n <> "" && n <> "-") in
  (* (SKY1: episode 1's sky, which no side names; F_SKY1 the flat that
   * says the sky is there) *)
  (* (AASHITTY first: Doom's texture 0 is drawn as none, and Freedoom
   * keeps a texture nobody uses there) *)
  let wanted_textures = uniq (with_switches (with_anims texture_anims ("AASHITTY" :: "SKY1" :: names_in "SIDEDEFS" 30 [ 4; 12; 20 ]))) in
  let wanted_flats = uniq (with_anims flat_anims ("F_SKY1" :: names_in "SECTORS" 26 [ 4; 12 ])) in
  let all = textures_of (read "lumps/textures/textures.cfg") in
  let textures =
    List.filter_map
      (fun (n : string) ->
        match List.find_opt (fun (t : texture) -> t.tname = n) (List.rev all) with
        | Some t -> Some t
        | None -> Console.print caps (Printf.sprintf "no texture %s in textures.cfg\n" n); None)
      wanted_textures in
  let pnames = uniq (List.concat_map (fun (t : texture) -> List.map (fun ((p, _, _) : string * int * int) -> p) t.patches) textures) in
  let picture (path : string) : string =
    let png = read path in
    let img = Png.decode png in
    patch_of img.width img.height (grab png) (indices pal cache img) in
  let patches = List.map (fun (p : string) -> { Wad.name = p; data = picture (Printf.sprintf "patches/%s.png" (String.lowercase_ascii p)) }) pnames in
  let flats =
    List.map
      (fun (f : string) ->
        let img = Png.decode (read (Printf.sprintf "flats/%s.png" (String.lowercase_ascii f))) in
        if img.width <> 64 || img.height <> 64 then failwith (f ^ ": a flat is 64 by 64");
        let px = indices pal cache img in
        { Wad.name = f; data = String.init 4096 (fun (i : int) -> Char.chr (max 0 px.(i))) })
      wanted_flats in
  (* the sprites of every thing of the levels *)
  let kinds = List.concat_map (fun ((_, lumps) : string * Wad.lump list) ->
    let d = (List.find (fun (l : Wad.lump) -> l.name = "THINGS") lumps).data in
    List.init (String.length d / 10) (fun (k : int) -> Wad.short d ((10 * k) + 6))) levels in
  let names = uniq (Things.sprite_names kinds @ Info.sprites) in
  let sprites =
    List.filter_map
      (fun ((n, x, y) : string * int * int) ->
        if String.length n >= 6 && List.mem (String.sub n 0 4) names then begin
          let png = read (Printf.sprintf "sprites/%s.png" (String.lowercase_ascii n)) in
          let img = Png.decode png in
          Some { Wad.name = n; data = patch_of img.width img.height (x, y) (indices pal cache img) }
        end
        else None)
      (sprites_of (read "buildcfg.txt")) in
  let texture1 =
    let b = Buffer.create 16384 in
    let n = List.length textures in
    Wad.add_int32 b n;
    let sizes = List.map (fun (t : texture) -> 22 + (10 * List.length t.patches)) textures in
    ignore (List.fold_left (fun (pos : int) (s : int) -> Wad.add_int32 b pos; pos + s) (4 + (4 * n)) sizes);
    List.iter
      (fun (t : texture) ->
        Wad.add_name8 b t.tname;
        Wad.add_int32 b 0;
        Wad.add_short b t.width;
        Wad.add_short b t.height;
        Wad.add_int32 b 0;
        Wad.add_short b (List.length t.patches);
        List.iter
          (fun ((p, x, y) : string * int * int) ->
            let rec idx (k : int) (l : string list) : int = match l with q :: rest -> if q = p then k else idx (k + 1) rest | [] -> assert false in
            Wad.add_short b x; Wad.add_short b y; Wad.add_short b (idx 0 pnames); Wad.add_short b 1; Wad.add_short b 0)
          t.patches)
      textures;
    Buffer.contents b in
  let pnames_lump =
    let b = Buffer.create 4096 in
    Wad.add_int32 b (List.length pnames);
    List.iter (Wad.add_name8 b) pnames;
    Buffer.contents b in
  let sounds =
    List.map
      (fun (n : string) ->
        let path = Printf.sprintf "sounds/ds%s.wav" n in
        let data = dmx_of_wav path (read path) in
        { Wad.name = String.uppercase_ascii ("ds" ^ n); data })
      Info.sounds in
  let musics =
    List.filter_map
      (fun ((m, _) : string * Wad.lump list) ->
        let path = Printf.sprintf "musics/d_%s.mid" (String.lowercase_ascii m) in
        try Some { Wad.name = "D_" ^ m; data = read path }
        with Sys_error _ | Unix.Unix_error _ -> None)
      levels in
  let lumps =
    [ { Wad.name = "PLAYPAL"; data = pal_bytes }; { Wad.name = "COLORMAP"; data = colormap pal } ]
    @ List.concat_map (fun ((m, l) : string * Wad.lump list) -> { Wad.name = m; data = "" } :: l) levels
    @ [ { Wad.name = "TEXTURE1"; data = texture1 }; { Wad.name = "PNAMES"; data = pnames_lump } ]
    @ [ { Wad.name = "P_START"; data = "" } ] @ patches @ [ { Wad.name = "P_END"; data = "" } ]
    @ [ { Wad.name = "F_START"; data = "" } ] @ flats @ [ { Wad.name = "F_END"; data = "" } ]
    @ [ { Wad.name = "S_START"; data = "" } ] @ sprites @ [ { Wad.name = "S_END"; data = "" } ]
    @ sounds @ musics in
  let bytes = Wad.write "IWAD" lumps in
  FS.write caps (Fpath.v out) bytes;
  Console.print caps
    (Printf.sprintf "%s: %d levels, %d textures of %d patches, %d flats\n" out
       (List.length levels) (List.length textures) (List.length patches)
       (List.length flats)
     ^ Printf.sprintf "%d sprites' pictures, %d sounds, %d musics, %d bytes\n"
         (List.length sprites) (List.length sounds) (List.length musics)
         (String.length bytes))

let () =
  Cap.main (fun caps ->
      Exit.exit caps @@ Exit.catch @@ fun () ->
      (match Array.to_list (CapSys.argv caps) with
      | _ :: dir :: out :: (_ :: _ as maps) -> make caps dir out (List.map String.uppercase_ascii maps)
      | _ -> failwith usage);
      Exit.OK)
