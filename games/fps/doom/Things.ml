(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Things.mli *)

type info = {
  doomednum : int;
  sprite : string;
  frames : (char * bool) array;
  tics : int;
  radius : float;
  height : float;
  solid : bool;
  hanging : bool;
  monster : bool;
}

(* "AB+": the frames' letters, each followed by its "+" if bright *)
let letters (s : string) : (char * bool) array =
  let acc = ref [] in
  String.iteri (fun (i : int) (c : char) -> if c <> '+' then acc := (c, i + 1 < String.length s && s.[i + 1] = '+') :: !acc) s;
  Array.of_list (List.rev !acc)

(* info.c's mobjinfo, the spawn states, for Doom's (and Doom II's
 * common) things: a decoration, an item, a monster; a thing's frames
 * said as "AB+" (A, then B bright) *)
let table : info list =
  let d (n : int) (sprite : string) (frames : string) (tics : int) (radius : float) (height : float) (solid : bool) : info =
    { doomednum = n; sprite; frames = letters frames; tics; radius; height; solid; hanging = false; monster = false } in
  let item (n : int) (sprite : string) (frames : string) : info = d n sprite frames 6 20. 16. false in
  let hang (n : int) (sprite : string) (frames : string) (height : float) (solid : bool) : info =
    { (d n sprite frames 8 16. height solid) with hanging = true } in
  let monster (n : int) (sprite : string) (radius : float) (height : float) : info =
    { (d n sprite "AB" 10 radius height true) with monster = true } in
  [ (* items *)
    item 2001 "SHOT" "A"; item 2002 "MGUN" "A"; item 2003 "LAUN" "A"; item 2004 "PLAS" "A"; item 2005 "CSAW" "A"; item 2006 "BFUG" "A";
    item 2007 "CLIP" "A"; item 2008 "SHEL" "A"; item 2010 "ROCK" "A"; item 2047 "CELL" "A"; item 2048 "AMMO" "A"; item 2049 "SBOX" "A";
    item 2046 "BROK" "A"; item 17 "CELP" "A"; item 8 "BPAK" "A";
    item 2011 "STIM" "A"; item 2012 "MEDI" "A"; item 2014 "BON1" "ABCDCB"; item 2015 "BON2" "ABCDCB"; item 2018 "ARM1" "AB+";
    item 2019 "ARM2" "AB+"; item 2013 "SOUL" "A+B+C+D+C+B+"; item 2022 "PINV" "A+B+C+D+"; item 2023 "PSTR" "A+"; item 2024 "PINS" "A+B+C+D+";
    item 2025 "SUIT" "A+"; item 2026 "PMAP" "A+B+C+D+C+B+"; item 2045 "PVIS" "A+B";
    (* the keys: 10 tics, the second frame bright *)
    d 5 "BKEY" "AB+" 10 20. 16. false; d 6 "YKEY" "AB+" 10 20. 16. false; d 13 "RKEY" "AB+" 10 20. 16. false;
    d 38 "RSKU" "AB+" 10 20. 16. false; d 39 "YSKU" "AB+" 10 20. 16. false; d 40 "BSKU" "AB+" 10 20. 16. false;
    (* decorations *)
    d 2035 "BAR1" "AB" 6 10. 42. true; d 70 "FCAN" "A+B+C+" 4 16. 16. true;
    d 48 "ELEC" "A" 1 16. 16. true; d 30 "COL1" "A" 1 16. 16. true; d 31 "COL2" "A" 1 16. 16. true; d 32 "COL3" "A" 1 16. 16. true;
    d 33 "COL4" "A" 1 16. 16. true; d 36 "COL5" "AB" 14 16. 16. true; d 37 "COL6" "A" 1 16. 16. true; d 41 "CEYE" "A+B+C+B+" 6 16. 16. true;
    d 42 "FSKU" "A+B+C+" 6 16. 16. true; d 43 "TRE1" "A" 1 16. 16. true; d 47 "SMIT" "A" 1 16. 16. true; d 54 "TRE2" "A" 1 32. 16. true;
    d 34 "CAND" "A+" 1 20. 16. false; d 35 "CBRA" "A+" 1 16. 16. true; d 44 "TBLU" "A+B+C+D+" 4 16. 16. true;
    d 45 "TGRN" "A+B+C+D+" 4 16. 16. true; d 46 "TRED" "A+B+C+D+" 4 16. 16. true; d 55 "SMBT" "A+B+C+D+" 4 16. 16. true;
    d 56 "SMGT" "A+B+C+D+" 4 16. 16. true; d 57 "SMRT" "A+B+C+D+" 4 16. 16. true; d 2028 "COLU" "A+" 1 16. 16. true;
    d 85 "TLMP" "A+B+C+D+" 4 16. 16. true; d 86 "TLP2" "A+B+C+D+" 4 16. 16. true;
    hang 49 "GOR1" "ABCB" 68. true; hang 50 "GOR2" "A" 84. true; hang 51 "GOR3" "A" 84. true; hang 52 "GOR4" "A" 68. true;
    hang 53 "GOR5" "A" 52. true; hang 63 "GOR1" "ABCB" 68. false; hang 59 "GOR2" "A" 84. false; hang 61 "GOR3" "A" 52. false;
    hang 60 "GOR4" "A" 68. false; hang 62 "GOR5" "A" 52. false;
    (* the dead, the gore *)
    d 10 "PLAY" "W" 1 20. 16. false; d 12 "PLAY" "W" 1 20. 16. false; d 15 "PLAY" "N" 1 20. 16. false; d 18 "POSS" "L" 1 20. 16. false;
    d 19 "SPOS" "L" 1 20. 16. false; d 20 "TROO" "M" 1 20. 16. false; d 21 "SARG" "N" 1 20. 16. false; d 22 "HEAD" "L" 1 20. 16. false;
    d 24 "POL5" "A" 1 20. 16. false; d 25 "POL1" "A" 1 16. 16. true; d 26 "POL6" "AB" 6 16. 16. true; d 27 "POL4" "A" 1 16. 16. true;
    d 28 "POL2" "A" 1 16. 16. true; d 29 "POL3" "A+B+" 6 16. 16. true;
    (* the monsters, standing *)
    monster 3004 "POSS" 20. 56.; monster 9 "SPOS" 20. 56.; monster 3001 "TROO" 20. 56.; monster 3002 "SARG" 30. 56.;
    monster 58 "SARG" 30. 56.; { (monster 3006 "SKUL" 16. 56.) with frames = letters "A+B+" }; monster 3005 "HEAD" 31. 56.;
    monster 3003 "BOSS" 24. 64.; monster 16 "CYBR" 40. 110.; monster 7 "SPID" 128. 100. ]

let info (n : int) : info option = List.find_opt (fun (i : info) -> i.doomednum = n) table

let sprite_names (kinds : int list) : string list =
  List.fold_left
    (fun (acc : string list) (k : int) -> match info k with Some i when not (List.mem i.sprite acc) -> i.sprite :: acc | _ -> acc)
    [] kinds
  |> List.rev

type mobj = {
  mx : float;
  my : float;
  mutable mz : float;
  mangle : float;
  kind : info;
  sector : Level.sector;
  phase : int;
  mutable alive : bool;
}

let spawn (level : Level.t) (monsters : bool) : mobj list =
  List.filter_map
    (fun ((k, th) : int * Level.thing) ->
      (* (the skills' bits: 1 the easy ones, 2 medium, 4 hard; 16 the
       * multiplayer's only) *)
      if th.tflags land 2 = 0 || th.tflags land 16 <> 0 then None
      else
        match info th.kind with
        | Some i when monsters || not i.monster ->
            let s = Level.sector_at level th.tx th.ty in
            Some
              { mx = th.tx; my = th.ty; mz = (if i.hanging then s.ceiling -. i.height else s.floor); mangle = th.tangle; kind = i; sector = s;
                phase = k * 7; alive = true }
        | _ -> None)
    (List.mapi (fun (k : int) (th : Level.thing) -> (k, th)) (Array.to_list level.things))

type frame = { lumps : string array; flip : bool array; rotates : bool }

type sprites = (string, frame) Hashtbl.t

(* R_InitSpriteDefs: each lump of S_START to S_END is a sprite's frame
 * at a rotation, or two (its last two letters: the mirrored one) *)
let load (wad : Wad.t) : sprites =
  let frames : sprites = Hashtbl.create 256 in
  let install (name : string) (letter : char) (rot : char) (data : string) (flip : bool) : unit =
    let key = name ^ String.make 1 letter in
    let f = match Hashtbl.find_opt frames key with Some f -> f | None -> { lumps = Array.make 8 ""; flip = Array.make 8 false; rotates = rot <> '0' } in
    let f = { f with rotates = rot <> '0' } in
    if rot = '0' then
      for r = 0 to 7 do f.lumps.(r) <- data; f.flip.(r) <- flip done
    else begin
      let r = Char.code rot - Char.code '1' in
      if r >= 0 && r < 8 then begin f.lumps.(r) <- data; f.flip.(r) <- flip end
    end;
    Hashtbl.replace frames key f in
  List.iter
    (fun (l : Wad.lump) ->
      let n = l.name in
      if String.length n >= 6 then begin
        let name = String.sub n 0 4 in
        install name n.[4] n.[5] l.data false;
        if String.length n >= 8 then install name n.[6] n.[7] l.data true
      end)
    (Wad.between wad "S_START" "S_END" @ Wad.between wad "SS_START" "SS_END");
  frames

let frame (sprites : sprites) (m : mobj) (tic : int) : (frame * bool) option =
  let letters = m.kind.frames in
  let n = Array.length letters in
  let c, bright = letters.((((tic + m.phase) / m.kind.tics) mod n + n) mod n) in
  Option.map (fun (f : frame) -> (f, bright)) (Hashtbl.find_opt sprites (m.kind.sprite ^ String.make 1 c))
