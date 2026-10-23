(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Info.mli *)

type action =
  | Nothing
  | Look
  | Chase
  | Face_target
  | Pos_attack
  | SPos_attack
  | Troop_attack
  | Sarg_attack
  | Pain
  | Scream
  | XScream
  | Fall
  | Explode
  | Weapon_ready
  | Lower
  | Raise
  | Punch
  | Fire_pistol
  | Fire_shotgun
  | Saw
  | Refire
  | Light0
  | Light1
  | Light2

type state = {
  sname : string;
  sprite : string;
  frame : int;
  bright : bool;
  tics : int;
  action : action;
  next : string;
}

(* info.c's states, a row each as id wrote them: {SPR_POSS,0,10,
 * {A_Look},S_POSS_STND2} is s "POSS_STND" "POSS" "A" 10 Look
 * "POSS_STND2"; a frame "A+" is bright (32768 + 0) *)
let table : state list =
  let s (sname : string) (sprite : string) (f : string) (tics : int)
      (action : action) (next : string) : state =
    let frame = Char.code f.[0] - Char.code 'A' in
    { sname; sprite; frame; bright = String.length f > 1; tics; action; next }
  in
  [ (* the weapons *)
    s "LIGHTDONE" "SHTG" "E" 0 Light0 "";
    s "PUNCH" "PUNG" "A" 1 Weapon_ready "PUNCH";
    s "PUNCHDOWN" "PUNG" "A" 1 Lower "PUNCHDOWN";
    s "PUNCHUP" "PUNG" "A" 1 Raise "PUNCHUP";
    s "PUNCH1" "PUNG" "B" 4 Nothing "PUNCH2";
    s "PUNCH2" "PUNG" "C" 4 Punch "PUNCH3";
    s "PUNCH3" "PUNG" "D" 5 Nothing "PUNCH4";
    s "PUNCH4" "PUNG" "C" 4 Nothing "PUNCH5";
    s "PUNCH5" "PUNG" "B" 5 Refire "PUNCH";
    s "PISTOL" "PISG" "A" 1 Weapon_ready "PISTOL";
    s "PISTOLDOWN" "PISG" "A" 1 Lower "PISTOLDOWN";
    s "PISTOLUP" "PISG" "A" 1 Raise "PISTOLUP";
    s "PISTOL1" "PISG" "A" 4 Nothing "PISTOL2";
    s "PISTOL2" "PISG" "B" 6 Fire_pistol "PISTOL3";
    s "PISTOL3" "PISG" "C" 4 Nothing "PISTOL4";
    s "PISTOL4" "PISG" "B" 5 Refire "PISTOL";
    s "PISTOLFLASH" "PISF" "A+" 7 Light1 "LIGHTDONE";
    s "SGUN" "SHTG" "A" 1 Weapon_ready "SGUN";
    s "SGUNDOWN" "SHTG" "A" 1 Lower "SGUNDOWN";
    s "SGUNUP" "SHTG" "A" 1 Raise "SGUNUP";
    s "SGUN1" "SHTG" "A" 3 Nothing "SGUN2";
    s "SGUN2" "SHTG" "A" 7 Fire_shotgun "SGUN3";
    s "SGUN3" "SHTG" "B" 5 Nothing "SGUN4";
    s "SGUN4" "SHTG" "C" 5 Nothing "SGUN5";
    s "SGUN5" "SHTG" "D" 4 Nothing "SGUN6";
    s "SGUN6" "SHTG" "C" 5 Nothing "SGUN7";
    s "SGUN7" "SHTG" "B" 5 Nothing "SGUN8";
    s "SGUN8" "SHTG" "A" 3 Nothing "SGUN9";
    s "SGUN9" "SHTG" "A" 7 Refire "SGUN";
    s "SGUNFLASH1" "SHTF" "A+" 4 Light1 "SGUNFLASH2";
    s "SGUNFLASH2" "SHTF" "B+" 3 Light2 "LIGHTDONE";
    s "SAW" "SAWG" "C" 4 Weapon_ready "SAWB";
    s "SAWB" "SAWG" "D" 4 Weapon_ready "SAW";
    s "SAWDOWN" "SAWG" "C" 1 Lower "SAWDOWN";
    s "SAWUP" "SAWG" "C" 1 Raise "SAWUP";
    s "SAW1" "SAWG" "A" 4 Saw "SAW2";
    s "SAW2" "SAWG" "B" 4 Saw "SAW3";
    s "SAW3" "SAWG" "B" 0 Refire "SAW";
    (* what shots leave *)
    s "BLOOD1" "BLUD" "C" 8 Nothing "BLOOD2";
    s "BLOOD2" "BLUD" "B" 8 Nothing "BLOOD3";
    s "BLOOD3" "BLUD" "A" 8 Nothing "";
    s "PUFF1" "PUFF" "A+" 4 Nothing "PUFF2";
    s "PUFF2" "PUFF" "B" 4 Nothing "PUFF3";
    s "PUFF3" "PUFF" "C" 4 Nothing "PUFF4";
    s "PUFF4" "PUFF" "D" 4 Nothing "";
    s "TBALL1" "BAL1" "A+" 4 Nothing "TBALL2";
    s "TBALL2" "BAL1" "B+" 4 Nothing "TBALL1";
    s "TBALLX1" "BAL1" "C+" 6 Nothing "TBALLX2";
    s "TBALLX2" "BAL1" "D+" 6 Nothing "TBALLX3";
    s "TBALLX3" "BAL1" "E+" 6 Nothing "";
    (* the zombieman *)
    s "POSS_STND" "POSS" "A" 10 Look "POSS_STND2";
    s "POSS_STND2" "POSS" "B" 10 Look "POSS_STND";
    s "POSS_RUN1" "POSS" "A" 4 Chase "POSS_RUN2";
    s "POSS_RUN2" "POSS" "A" 4 Chase "POSS_RUN3";
    s "POSS_RUN3" "POSS" "B" 4 Chase "POSS_RUN4";
    s "POSS_RUN4" "POSS" "B" 4 Chase "POSS_RUN5";
    s "POSS_RUN5" "POSS" "C" 4 Chase "POSS_RUN6";
    s "POSS_RUN6" "POSS" "C" 4 Chase "POSS_RUN7";
    s "POSS_RUN7" "POSS" "D" 4 Chase "POSS_RUN8";
    s "POSS_RUN8" "POSS" "D" 4 Chase "POSS_RUN1";
    s "POSS_ATK1" "POSS" "E" 10 Face_target "POSS_ATK2";
    s "POSS_ATK2" "POSS" "F" 8 Pos_attack "POSS_ATK3";
    s "POSS_ATK3" "POSS" "E" 8 Nothing "POSS_RUN1";
    s "POSS_PAIN" "POSS" "G" 3 Nothing "POSS_PAIN2";
    s "POSS_PAIN2" "POSS" "G" 3 Pain "POSS_RUN1";
    s "POSS_DIE1" "POSS" "H" 5 Nothing "POSS_DIE2";
    s "POSS_DIE2" "POSS" "I" 5 Scream "POSS_DIE3";
    s "POSS_DIE3" "POSS" "J" 5 Fall "POSS_DIE4";
    s "POSS_DIE4" "POSS" "K" 5 Nothing "POSS_DIE5";
    s "POSS_DIE5" "POSS" "L" (-1) Nothing "";
    s "POSS_XDIE1" "POSS" "M" 5 Nothing "POSS_XDIE2";
    s "POSS_XDIE2" "POSS" "N" 5 XScream "POSS_XDIE3";
    s "POSS_XDIE3" "POSS" "O" 5 Fall "POSS_XDIE4";
    s "POSS_XDIE4" "POSS" "P" 5 Nothing "POSS_XDIE5";
    s "POSS_XDIE5" "POSS" "Q" 5 Nothing "POSS_XDIE6";
    s "POSS_XDIE6" "POSS" "R" 5 Nothing "POSS_XDIE7";
    s "POSS_XDIE7" "POSS" "S" 5 Nothing "POSS_XDIE8";
    s "POSS_XDIE8" "POSS" "T" 5 Nothing "POSS_XDIE9";
    s "POSS_XDIE9" "POSS" "U" (-1) Nothing "";
    (* the shotgun guy *)
    s "SPOS_STND" "SPOS" "A" 10 Look "SPOS_STND2";
    s "SPOS_STND2" "SPOS" "B" 10 Look "SPOS_STND";
    s "SPOS_RUN1" "SPOS" "A" 3 Chase "SPOS_RUN2";
    s "SPOS_RUN2" "SPOS" "A" 3 Chase "SPOS_RUN3";
    s "SPOS_RUN3" "SPOS" "B" 3 Chase "SPOS_RUN4";
    s "SPOS_RUN4" "SPOS" "B" 3 Chase "SPOS_RUN5";
    s "SPOS_RUN5" "SPOS" "C" 3 Chase "SPOS_RUN6";
    s "SPOS_RUN6" "SPOS" "C" 3 Chase "SPOS_RUN7";
    s "SPOS_RUN7" "SPOS" "D" 3 Chase "SPOS_RUN8";
    s "SPOS_RUN8" "SPOS" "D" 3 Chase "SPOS_RUN1";
    s "SPOS_ATK1" "SPOS" "E" 10 Face_target "SPOS_ATK2";
    s "SPOS_ATK2" "SPOS" "F+" 10 SPos_attack "SPOS_ATK3";
    s "SPOS_ATK3" "SPOS" "E" 10 Nothing "SPOS_RUN1";
    s "SPOS_PAIN" "SPOS" "G" 3 Nothing "SPOS_PAIN2";
    s "SPOS_PAIN2" "SPOS" "G" 3 Pain "SPOS_RUN1";
    s "SPOS_DIE1" "SPOS" "H" 5 Nothing "SPOS_DIE2";
    s "SPOS_DIE2" "SPOS" "I" 5 Scream "SPOS_DIE3";
    s "SPOS_DIE3" "SPOS" "J" 5 Fall "SPOS_DIE4";
    s "SPOS_DIE4" "SPOS" "K" 5 Nothing "SPOS_DIE5";
    s "SPOS_DIE5" "SPOS" "L" (-1) Nothing "";
    s "SPOS_XDIE1" "SPOS" "M" 5 Nothing "SPOS_XDIE2";
    s "SPOS_XDIE2" "SPOS" "N" 5 XScream "SPOS_XDIE3";
    s "SPOS_XDIE3" "SPOS" "O" 5 Fall "SPOS_XDIE4";
    s "SPOS_XDIE4" "SPOS" "P" 5 Nothing "SPOS_XDIE5";
    s "SPOS_XDIE5" "SPOS" "Q" 5 Nothing "SPOS_XDIE6";
    s "SPOS_XDIE6" "SPOS" "R" 5 Nothing "SPOS_XDIE7";
    s "SPOS_XDIE7" "SPOS" "S" 5 Nothing "SPOS_XDIE8";
    s "SPOS_XDIE8" "SPOS" "T" 5 Nothing "SPOS_XDIE9";
    s "SPOS_XDIE9" "SPOS" "U" (-1) Nothing "";
    (* the imp *)
    s "TROO_STND" "TROO" "A" 10 Look "TROO_STND2";
    s "TROO_STND2" "TROO" "B" 10 Look "TROO_STND";
    s "TROO_RUN1" "TROO" "A" 3 Chase "TROO_RUN2";
    s "TROO_RUN2" "TROO" "A" 3 Chase "TROO_RUN3";
    s "TROO_RUN3" "TROO" "B" 3 Chase "TROO_RUN4";
    s "TROO_RUN4" "TROO" "B" 3 Chase "TROO_RUN5";
    s "TROO_RUN5" "TROO" "C" 3 Chase "TROO_RUN6";
    s "TROO_RUN6" "TROO" "C" 3 Chase "TROO_RUN7";
    s "TROO_RUN7" "TROO" "D" 3 Chase "TROO_RUN8";
    s "TROO_RUN8" "TROO" "D" 3 Chase "TROO_RUN1";
    s "TROO_ATK1" "TROO" "E" 8 Face_target "TROO_ATK2";
    s "TROO_ATK2" "TROO" "F" 8 Face_target "TROO_ATK3";
    s "TROO_ATK3" "TROO" "G" 6 Troop_attack "TROO_RUN1";
    s "TROO_PAIN" "TROO" "H" 2 Nothing "TROO_PAIN2";
    s "TROO_PAIN2" "TROO" "H" 2 Pain "TROO_RUN1";
    s "TROO_DIE1" "TROO" "I" 8 Nothing "TROO_DIE2";
    s "TROO_DIE2" "TROO" "J" 8 Scream "TROO_DIE3";
    s "TROO_DIE3" "TROO" "K" 6 Nothing "TROO_DIE4";
    s "TROO_DIE4" "TROO" "L" 6 Fall "TROO_DIE5";
    s "TROO_DIE5" "TROO" "M" (-1) Nothing "";
    s "TROO_XDIE1" "TROO" "N" 5 Nothing "TROO_XDIE2";
    s "TROO_XDIE2" "TROO" "O" 5 XScream "TROO_XDIE3";
    s "TROO_XDIE3" "TROO" "P" 5 Nothing "TROO_XDIE4";
    s "TROO_XDIE4" "TROO" "Q" 5 Fall "TROO_XDIE5";
    s "TROO_XDIE5" "TROO" "R" 5 Nothing "TROO_XDIE6";
    s "TROO_XDIE6" "TROO" "S" 5 Nothing "TROO_XDIE7";
    s "TROO_XDIE7" "TROO" "T" 5 Nothing "TROO_XDIE8";
    s "TROO_XDIE8" "TROO" "U" (-1) Nothing "";
    (* the demon *)
    s "SARG_STND" "SARG" "A" 10 Look "SARG_STND2";
    s "SARG_STND2" "SARG" "B" 10 Look "SARG_STND";
    s "SARG_RUN1" "SARG" "A" 2 Chase "SARG_RUN2";
    s "SARG_RUN2" "SARG" "A" 2 Chase "SARG_RUN3";
    s "SARG_RUN3" "SARG" "B" 2 Chase "SARG_RUN4";
    s "SARG_RUN4" "SARG" "B" 2 Chase "SARG_RUN5";
    s "SARG_RUN5" "SARG" "C" 2 Chase "SARG_RUN6";
    s "SARG_RUN6" "SARG" "C" 2 Chase "SARG_RUN7";
    s "SARG_RUN7" "SARG" "D" 2 Chase "SARG_RUN8";
    s "SARG_RUN8" "SARG" "D" 2 Chase "SARG_RUN1";
    s "SARG_ATK1" "SARG" "E" 8 Face_target "SARG_ATK2";
    s "SARG_ATK2" "SARG" "F" 8 Face_target "SARG_ATK3";
    s "SARG_ATK3" "SARG" "G" 8 Sarg_attack "SARG_RUN1";
    s "SARG_PAIN" "SARG" "H" 2 Nothing "SARG_PAIN2";
    s "SARG_PAIN2" "SARG" "H" 2 Pain "SARG_RUN1";
    s "SARG_DIE1" "SARG" "I" 8 Nothing "SARG_DIE2";
    s "SARG_DIE2" "SARG" "J" 8 Scream "SARG_DIE3";
    s "SARG_DIE3" "SARG" "K" 4 Nothing "SARG_DIE4";
    s "SARG_DIE4" "SARG" "L" 4 Fall "SARG_DIE5";
    s "SARG_DIE5" "SARG" "M" 4 Nothing "SARG_DIE6";
    s "SARG_DIE6" "SARG" "N" (-1) Nothing "";
    (* the barrel *)
    s "BAR1" "BAR1" "A" 6 Nothing "BAR2";
    s "BAR2" "BAR1" "B" 6 Nothing "BAR1";
    s "BEXP" "BEXP" "A+" 5 Nothing "BEXP2";
    s "BEXP2" "BEXP" "B+" 5 Scream "BEXP3";
    s "BEXP3" "BEXP" "C+" 5 Nothing "BEXP4";
    s "BEXP4" "BEXP" "D+" 10 Explode "BEXP5";
    s "BEXP5" "BEXP" "E+" 10 Nothing "" ]

let states : (string, state) Hashtbl.t =
  let h = Hashtbl.create 256 in
  List.iter (fun (st : state) -> Hashtbl.replace h st.sname st) table;
  h

let state (name : string) : state option =
  if name = "" then None else Hashtbl.find_opt states name

let solid = 0x2
let shootable = 0x4
let noblockmap = 0x10
let ambush = 0x20
let justhit = 0x40
let justattacked = 0x80
let nogravity = 0x200
let dropoff = 0x400
let missile = 0x10000
let noblood = 0x80000
let corpse = 0x100000
let countkill = 0x400000

type mobjinfo = {
  doomednum : int;
  spawnstate : string;
  spawnhealth : int;
  seestate : string;
  seesound : string;
  reactiontime : int;
  attacksound : string;
  painstate : string;
  painchance : int;
  painsound : string;
  meleestate : string;
  missilestate : string;
  deathstate : string;
  xdeathstate : string;
  deathsound : string;
  speed : float;
  radius : float;
  height : float;
  mass : int;
  damage : int;
  activesound : string;
  flags : int;
}

(* info.c's mobjinfo, the rows of these things *)
let monster (n : int) (name : string) : mobjinfo =
  { doomednum = n; spawnstate = name ^ "_STND"; spawnhealth = 0;
    seestate = name ^ "_RUN1"; seesound = ""; reactiontime = 8;
    attacksound = ""; painstate = name ^ "_PAIN"; painchance = 0;
    painsound = "popain"; meleestate = ""; missilestate = "";
    deathstate = name ^ "_DIE1"; xdeathstate = name ^ "_XDIE1";
    deathsound = ""; speed = 8.; radius = 20.; height = 56.; mass = 100;
    damage = 0; activesound = "posact";
    flags = solid lor shootable lor countkill }

let possessed =
  { (monster 3004 "POSS") with
    spawnhealth = 20; seesound = "posit1"; attacksound = "pistol";
    painchance = 200; missilestate = "POSS_ATK1"; deathsound = "podth1" }

let shotguy =
  { (monster 9 "SPOS") with
    spawnhealth = 30; seesound = "posit2"; painchance = 170;
    missilestate = "SPOS_ATK1"; deathsound = "podth2" }

let troop =
  { (monster 3001 "TROO") with
    spawnhealth = 60; seesound = "bgsit1"; painchance = 200;
    meleestate = "TROO_ATK1"; missilestate = "TROO_ATK1";
    deathsound = "bgdth1"; activesound = "bgact" }

let sergeant =
  { (monster 3002 "SARG") with
    spawnhealth = 150; seesound = "sgtsit"; attacksound = "sgtatk";
    painchance = 180; painsound = "dmpain"; meleestate = "SARG_ATK1";
    xdeathstate = ""; deathsound = "sgtdth"; speed = 10.; radius = 30.;
    mass = 400; activesound = "dmact" }

let barrel =
  { doomednum = 2035; spawnstate = "BAR1"; spawnhealth = 20; seestate = "";
    seesound = ""; reactiontime = 8; attacksound = ""; painstate = "";
    painchance = 0; painsound = ""; meleestate = ""; missilestate = "";
    deathstate = "BEXP"; xdeathstate = ""; deathsound = "barexp";
    speed = 0.; radius = 10.; height = 42.; mass = 100; damage = 0;
    activesound = ""; flags = solid lor shootable lor noblood }

let troopshot =
  { barrel with
    doomednum = -1; spawnstate = "TBALL1"; spawnhealth = 1000;
    seesound = "firsht"; deathstate = "TBALLX1"; deathsound = "firxpl";
    speed = 10.; radius = 6.; height = 8.; damage = 3;
    flags = noblockmap lor missile lor dropoff lor nogravity }

let puff =
  { troopshot with
    spawnstate = "PUFF1"; seesound = ""; deathstate = ""; deathsound = "";
    speed = 0.; damage = 0; flags = noblockmap lor nogravity }

let blood = { puff with spawnstate = "BLOOD1"; flags = noblockmap }

(* (and the demon's twin in the dark, the spectre (58), as the demon:
 * Doom draws it fuzzy, here not) *)
let of_doomednum (n : int) : mobjinfo option =
  match n with
  | 3004 -> Some possessed
  | 9 -> Some shotguy
  | 3001 -> Some troop
  | 3002 -> Some sergeant
  | 58 -> Some { sergeant with doomednum = 58 }
  | 2035 -> Some barrel
  | _ -> None

type weapon = Fist | Pistol | Shotgun | Chainsaw

type ammo = Clip | Shell

type weaponinfo = {
  ammo : ammo option;
  upstate : string;
  downstate : string;
  readystate : string;
  atkstate : string;
  flashstate : string;
}

let weaponinfo (w : weapon) : weaponinfo =
  let wi (ammo : ammo option) (name : string) (atk : string)
      (flash : string) : weaponinfo =
    { ammo; upstate = name ^ "UP"; downstate = name ^ "DOWN";
      readystate = name; atkstate = atk; flashstate = flash } in
  match w with
  | Fist -> wi None "PUNCH" "PUNCH1" ""
  | Pistol -> wi (Some Clip) "PISTOL" "PISTOL1" "PISTOLFLASH"
  | Shotgun -> wi (Some Shell) "SGUN" "SGUN1" "SGUNFLASH1"
  | Chainsaw -> wi None "SAW" "SAW1" ""

(* (the infos' sounds, with the other two of a "posit1" and "bgsit1"
 * (A_Look's choice), the deaths' (A_Scream's), and those the code
 * makes: the weapons', the items', the doors', the player's) *)
let sounds =
  [ "pistol"; "shotgn"; "punch"; "sawup"; "sawidl"; "sawful"; "sawhit";
    "itemup"; "wpnup"; "getpow"; "oof"; "noway"; "plpain"; "pldeth";
    "pdiehi"; "slop"; "doropn"; "dorcls"; "bdopn"; "bdcls"; "pstart";
    "pstop"; "stnmov"; "swtchn"; "swtchx"; "posit1"; "posit2"; "posit3";
    "bgsit1"; "bgsit2"; "sgtsit"; "posact"; "bgact"; "dmact"; "popain";
    "dmpain"; "podth1"; "podth2"; "podth3"; "bgdth1"; "bgdth2"; "sgtdth";
    "claw"; "sgtatk"; "firsht"; "firxpl"; "barexp" ]

let sprites =
  List.fold_left
    (fun (acc : string list) (st : state) ->
      if List.mem st.sprite acc then acc else acc @ [ st.sprite ])
    [] table
  (* (the shotgun, dropped by its guy, and the clip by the zombieman) *)
  @ [ "SHOT"; "CLIP" ]

(* m_random.c's rndtable *)
let rndtable =
  [| 0; 8; 109; 220; 222; 241; 149; 107; 75; 248; 254; 140; 16; 66; 74;
     21; 211; 47; 80; 242; 154; 27; 205; 128; 161; 89; 77; 36; 95; 110;
     85; 48; 212; 140; 211; 249; 22; 79; 200; 50; 28; 188; 52; 140; 202;
     120; 68; 145; 62; 70; 184; 190; 91; 197; 152; 224; 149; 104; 25; 178;
     252; 182; 202; 182; 141; 197; 4; 81; 181; 242; 145; 42; 39; 227; 156;
     198; 225; 193; 219; 93; 122; 175; 249; 0; 175; 143; 70; 239; 46; 246;
     163; 53; 163; 109; 168; 135; 2; 235; 25; 92; 20; 145; 138; 77; 69;
     166; 78; 176; 173; 212; 166; 113; 94; 161; 41; 50; 239; 49; 111; 164;
     70; 60; 2; 37; 171; 75; 136; 156; 11; 56; 42; 146; 138; 229; 73; 146;
     77; 61; 98; 196; 135; 106; 63; 197; 195; 86; 96; 203; 113; 101; 170;
     247; 181; 113; 80; 250; 108; 7; 255; 237; 129; 226; 79; 107; 112; 166;
     103; 241; 24; 223; 239; 120; 198; 58; 60; 82; 128; 3; 184; 66; 143;
     224; 145; 224; 81; 206; 163; 45; 63; 90; 168; 114; 59; 33; 159; 95;
     28; 139; 123; 98; 125; 196; 15; 70; 194; 253; 54; 14; 109; 226; 71;
     17; 161; 93; 186; 87; 244; 138; 20; 52; 123; 251; 26; 36; 17; 46; 52;
     231; 232; 76; 31; 221; 84; 37; 216; 165; 212; 106; 197; 242; 98; 43;
     39; 175; 254; 145; 190; 84; 118; 222; 187; 136; 120; 163; 236; 249 |]

let prndindex = ref 0

let p_random () : int =
  prndindex := (!prndindex + 1) land 255;
  rndtable.(!prndindex)

let p_random2 () : int =
  let a = p_random () in
  a - p_random ()
