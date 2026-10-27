(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Voice_tr808.mli *)

(* ix: the author's playground's apps/music/Voice_tr808.ml its optional arguments are said its lazy ROMs made when first asked, by hand (docs/plans/plan_audio.md) *)

(*****************************************************************************)
(* The patch *)
(*****************************************************************************)

type instrument = BD | SD | LT | MT | HT | RS | CP | CB | CY | OH | CH

let instruments = [ BD; SD; LT; MT; HT; RS; CP; CB; CY; OH; CH ]
let name = function BD -> "BD" | SD -> "SD" | LT -> "LT" | MT -> "MT" | HT -> "HT" | RS -> "RS" | CP -> "CP" | CB -> "CB" | CY -> "CY" | OH -> "OH" | CH -> "CH"

let index (i : instrument) : int =
  let rec find k = function [] -> 0 | x :: rest -> if x = i then k else find (k + 1) rest in
  find 0 instruments

(* the 909's in the 808's slots: the cowbell's is its ride, the
 * cymbal's its crash *)
let label (machine : int) (i : instrument) : string =
  match (machine, i) with 1, CB -> "RD" | 1, CY -> "CR" | _ -> name i

let machines = [ "808"; "909" ]

type drum = { level : float; tone : float; decay : float; tuning : float; snappy : float }

type patch = {
  machine : int;
  drums : drum array;
  tracks : bool array array;
  accents : bool array;
  flams : bool array;
  accent : float;
  shuffle : float;
  flam : float;
  tempo : float;
  volume : float;
}

let drum0 = { level = 0.8; tone = 0.5; decay = 0.5; tuning = 0.5; snappy = 0.5 }

let initial : patch =
  {
    machine = 0;
    drums = Array.make 11 drum0;
    tracks = Array.init 11 (fun _ -> Array.make 16 false);
    accents = Array.make 16 false;
    flams = Array.make 16 false;
    accent = 0.5;
    shuffle = 0.;
    flam = 0.3;
    tempo = 120.;
    volume = 0.7;
  }

type knob = patch Patch_text.knob

let knobs : knob list =
  List.concat_map
    (fun i ->
      let k = index i in
      let knob field get set =
        Patch_text.knob
          (name i ^ "." ^ field)
          (fun p -> get p.drums.(k))
          (fun p x ->
            let d = Array.copy p.drums in
            d.(k) <- set d.(k) x;
            { p with drums = d })
      in
      [
        knob "level" (fun d -> d.level) (fun d x -> { d with level = x });
        knob "tone" (fun d -> d.tone) (fun d x -> { d with tone = x });
        knob "decay" (fun d -> d.decay) (fun d x -> { d with decay = x });
        knob "tuning" (fun d -> d.tuning) (fun d x -> { d with tuning = x });
        knob "snappy" (fun d -> d.snappy) (fun d x -> { d with snappy = x });
      ])
    instruments
  @ [
      Patch_text.selector "machine" machines (fun p -> p.machine) (fun p x -> { p with machine = x });
      Patch_text.knob "accent" (fun p -> p.accent) (fun p x -> { p with accent = x });
      Patch_text.knob "shuffle" (fun p -> p.shuffle) (fun p x -> { p with shuffle = x });
      Patch_text.knob "flam" (fun p -> p.flam) (fun p x -> { p with flam = x });
      (* whole beats a minute, so a pattern's tempo is written exactly *)
      Patch_text.selector "tempo" (List.init 121 (fun k -> string_of_int (60 + k)))
        (fun p -> Float.to_int p.tempo - 60)
        (fun p x -> { p with tempo = float_of_int (60 + x) });
      Patch_text.knob "volume" (fun p -> p.volume) (fun p x -> { p with volume = x });
    ]

(* the tracks as text: 16 characters, x a hit, . a rest *)
let steps_to_string (s : bool array) : string = String.init 16 (fun k -> if s.(k) then 'x' else '.')
let steps_of_string (s : string) : bool array = Array.init 16 (fun k -> k < String.length s && s.[k] = 'x')

let to_string (p : patch) : string =
  Patch_text.to_string knobs p
  ^ String.concat "" (List.map (fun i -> Printf.sprintf "%s.steps = %s\n" (name i) (steps_to_string p.tracks.(index i))) instruments)
  ^ Printf.sprintf "accent.steps = %s\n" (steps_to_string p.accents)
  ^ Printf.sprintf "flam.steps = %s\n" (steps_to_string p.flams)

(* the ".steps" lines read first, the rest by Patch_text *)
let of_string (text : string) : (patch, string) result =
  let lines = String.split_on_char '\n' text in
  let steps l =
    match String.index_opt l '=' with
    | Some i ->
        let key = String.trim (String.sub l 0 i) and value = String.trim (String.sub l (i + 1) (String.length l - i - 1)) in
        let suffix = ".steps" in
        let n = String.length key and m = String.length suffix in
        if n > m && String.sub key (n - m) m = suffix then Some (String.sub key 0 (n - m), value) else None
    | None -> None
  in
  let others = List.filter (fun l -> steps l = None) lines in
  Result.map
    (fun p ->
      List.fold_left
        (fun (p : patch) l ->
          match steps l with
          | Some ("accent", v) -> { p with accents = steps_of_string v }
          | Some ("flam", v) -> { p with flams = steps_of_string v }
          | Some (who, v) -> (
              match List.find_opt (fun i -> name i = who) instruments with
              | Some i ->
                  let tracks = Array.copy p.tracks in
                  tracks.(index i) <- steps_of_string v;
                  { p with tracks }
              | None -> p)
          | None -> p)
        p lines)
    (Patch_text.of_string knobs ~initial (String.concat "\n" others))

(* ours: patterns in the styles the 808 and the 909 made *)
(* ix: these five were optional: 0, 120, 0, no accent, no flam *)
let none = "................"
let pattern ~(machine : int) ~(tempo : float) ~(shuffle : float) ~(accents : string) ~(flams : string)
    (tracks : (instrument * string) list) : patch =
  {
    initial with
    machine;
    tempo;
    shuffle;
    accents = steps_of_string accents;
    flams = steps_of_string flams;
    tracks = Array.init 11 (fun k -> match List.assoc_opt (List.nth instruments k) tracks with Some s -> steps_of_string s | None -> Array.make 16 false);
  }

let presets : (string * patch) list =
  [
    (* after Planet Rock (1982): the kick syncopated, the clap and the
     * cowbell *)
    ( "electro",
      pattern ~machine:0 ~tempo:127. ~shuffle:0. ~accents:"x...x...x...x..." ~flams:none
        [ (BD, "x.....x...x....."); (SD, "....x.......x..."); (CP, "....x.......x..."); (CH, "x.x.x.x.x.x.x.x."); (CB, "..x..x....x..x..") ] );
    (* four on the floor, the open hat between *)
    ("house", pattern ~machine:0 ~tempo:124. ~shuffle:0. ~accents:none ~flams:none [ (BD, "x...x...x...x..."); (CP, "....x.......x..."); (OH, "..x...x...x...x."); (CH, "x...x...x...x...") ]);
    (* a long kick, the snare on two and four, the hats *)
    ( "hip hop",
      { (pattern ~machine:0 ~tempo:92. ~shuffle:0. ~accents:none ~flams:none [ (BD, "x......x..x....."); (SD, "....x.......x..."); (CH, "x.x.x.x.x.x.xxx.") ]) with drums = Array.init 11 (fun k -> if k = 0 then { drum0 with decay = 0.9 } else drum0) } );
    (* the toms, the rim shot, the cowbell, a cymbal to start *)
    ( "latin",
      pattern ~machine:0 ~tempo:112. ~shuffle:0. ~accents:none ~flams:none
        [ (BD, "x..x..x.x..x..x."); (RS, "..x..x....x..x.."); (LT, "......x.......x."); (MT, "....x.......x..."); (HT, "x.......x......."); (CB, "x.x.x.x.x.x.x.x."); (CY, "x...............") ] );
    (* the 909: Chicago's four on the floor, its shuffle, the hats
     * between, a crash to open *)
    ( "909 house",
      pattern ~machine:1 ~tempo:122. ~shuffle:0.3 ~accents:"x...x...x...x..." ~flams:none
        [ (BD, "x...x...x...x..."); (CP, "....x.......x..."); (OH, "..x...x...x...x."); (CH, "x.x.x.x.x.x.x.x."); (CY, "x...............") ] );
    (* Detroit: the kick, sixteenth hats, the ride, the snare's flams *)
    ( "909 techno",
      pattern ~machine:1 ~tempo:132. ~shuffle:0. ~accents:"..x...x...x...x." ~flams:"............x..."
        [ (BD, "x...x...x...x..."); (SD, "....x.......x.xx"); (CH, "xxxxxxxxxxxxxxxx"); (CB, "..x...x...x...x.") ] );
  ]

let pattern_for_tests (tracks : (instrument * string) list) : patch = pattern ~machine:0 ~tempo:120. ~shuffle:0. ~accents:none ~flams:none tracks

(* the General MIDI drum map *)
let key = function BD -> 36 | SD -> 38 | LT -> 41 | MT -> 45 | HT -> 48 | RS -> 37 | CP -> 39 | CB -> 56 | CY -> 49 | OH -> 46 | CH -> 42
let of_key (k : int) : instrument option = List.find_opt (fun i -> key i = k) instruments

(*****************************************************************************)
(* The hits *)
(*****************************************************************************)

let rate = float_of_int Signal.rate

(* -60 dB after [t60] seconds, [age] samples in *)
let decay_env (t60 : float) (age : int) : float = exp (-6.9 *. float_of_int age /. (t60 *. rate))

(* the metal's buffers for the segment being rendered: the upper and
 * lower band-passes of the six squares, and the cowbell's two squares *)
(* ix: the buffers, the hits' out and the filters' samples in flat
 * arrays (Float.Array): by mini-ml a float stored in a float array is a
 * new block and the write barrier, each sample of each square, filter
 * and hit (old: Signal.t's) *)
type metal = {
  mutable low : Float.Array.t;
  mutable high : Float.Array.t;
  mutable bell : Float.Array.t;
}

(* a hit: it adds [m] samples of itself into [out] from [at], reading
 * the metal's buffers from 0; alive until silent *)
(* ix: a hit's add names the hit (it ends itself): a recursive value
 * there (let rec h = { ...; add } and add ...), here the hit kept in a
 * reference its add reads, which mini-ml takes *)
type hit = {
  who : instrument;
  add : metal -> Float.Array.t -> int -> int -> unit;
  mutable alive : bool;
  mutable choked : bool;
}

let drum_frequency ~(f0 : float) ~(sigh : float) ~(punch : float) ~(age : float) (level : float) : float =
  if age < 0.006 then punch *. f0 else f0 *. (1. +. (sigh *. level))

(* a sine whose frequency the circuit moves: [punch] times higher its
 * first 6 ms, then [f0] raised by [sigh] times its level (the sigh) *)
let sine_drum ~(f0 : float) ~(t60 : float) ~(sigh : float) ~(punch : float) ~(tone_hz : float) (amp : float) (who : instrument) : hit =
  let phase = ref 0. and age = ref 0 and lp = ref 0. in
  let a = 1. -. exp (-2. *. Float.pi *. tone_hz /. rate) in
  let self : hit option ref = ref None in
  let add out at m =
    let h : hit = (match !self with Some h -> h | None -> failwith "hit") in
    for i = at to at + m - 1 do
      if h.alive then begin
      let env = decay_env t60 !age in
      let f = drum_frequency ~f0 ~sigh ~punch ~age:(float_of_int !age /. rate) env in
      phase := Float.rem (!phase +. (f /. rate)) 1.;
      (* the trigger pulse, 1 ms, clicking through the tone's low-pass *)
      let click = if float_of_int !age < 0.001 *. rate then 0.5 else 0. in
      lp := !lp +. (a *. ((env *. sin (2. *. Float.pi *. !phase)) +. click -. !lp));
      Float.Array.set out i (Float.Array.get out i +. (amp *. !lp));
      incr age;
      if env < 1e-4 then h.alive <- false
      end
    done
  in
  let h : hit = { who; add = (fun _ out at m -> add out at m); alive = true; choked = false } in
  self := Some h;
  h

(* tones struck (Modal), and noise (the voice's own generator, so two
 * voices don't disturb each other's) through [filter] under [envelope] *)
let tones_and_noise ~(noise : unit -> float) ~(tones : (float * float * float) list) ~(noise_level : float)
    ~(filter : Svf.mode * float * float) ~(envelope : int -> float) (amp : float) (who : instrument) : hit =
  (* ix: the modes an array, summed by a loop: by mini-ml the fold's
   * closure took and gave its float in a block, each mode each sample
   * (old: a list, List.fold_left (fun s md -> s +. Modal.next md) 0.) *)
  let modes =
    tones
    |> List.map (fun (f, t60, a) ->
           let m = Modal.create ~frequency:f ~t60 in
           Modal.strike m a;
           m)
    |> Array.of_list
  in
  let svf = Svf.create () and age = ref 0 in
  let mode, cutoff, q = filter in
  let self : hit option ref = ref None in
  let add out at m =
    let h : hit = (match !self with Some h -> h | None -> failwith "hit") in
    let n = Float.Array.make m 0. in
    for i = 0 to m - 1 do
      Float.Array.set n i (noise ())
    done;
    Svf.process_fixed svf Zero_delay mode ~cutoff ~q n;
    (* ix: the envelope at each age once, the silence test's the next
     * sample's (old: envelope !age called again after incr age) *)
    let e = ref (envelope !age) in
    for i = 0 to m - 1 do
      if h.alive then begin
        let x = ref 0. in
        for k = 0 to Array.length modes - 1 do
          x := !x +. Modal.next modes.(k)
        done;
        let x = !x in
        Float.Array.set out (at + i)
          (Float.Array.get out (at + i)
           +. (amp *. (x +. (noise_level *. !e *. Float.Array.get n i))));
        incr age;
        e := envelope !age;
        (* silent, decided at the sample: the same whatever the blocks *)
        if !e < 1e-4 && Array.for_all (fun md -> Modal.level md < 1e-4) modes
        then h.alive <- false
      end
    done
  in
  let h : hit = { who; add = (fun _ out at m -> add out at m); alive = true; choked = false } in
  self := Some h;
  h

(* the metal: a band of the squares (a buffer of [metal]) through a
 * high-pass, under an envelope; choked, gone in 10 ms *)
let metal_hit
    ~(bands : ((metal -> Float.Array.t) * float * float * (int -> float)) list)
    (amp : float) (who : instrument) : hit =
  let filters = List.map (fun _ -> Svf.create ()) bands and age = ref 0 and choke = ref 1. in
  let self : hit option ref = ref None in
  let add metal out at m =
    let h : hit = (match !self with Some h -> h | None -> failwith "hit") in
    if h.alive then begin
      (* ix: each band's envelope at each age once, kept for the
       * silence test, which reads the next sample's (old: e !age
       * called again after incr age); the choke's factor once *)
      let mix = Float.Array.make m 0. in
      let envelopes =
        List.map2
          (fun (band, hp, q, envelope) svf ->
            let x = Float.Array.create m in
            Float.Array.blit (band metal) 0 x 0 m;
            if hp > 0. then
              Svf.process_fixed svf Zero_delay High_pass ~cutoff:hp ~q x;
            let e = Float.Array.make (m + 1) 0. in
            for i = 0 to m do
              Float.Array.set e i (envelope (!age + i))
            done;
            for i = 0 to m - 1 do
              Float.Array.set mix i
                (Float.Array.get mix i
                 +. (Float.Array.get e i *. Float.Array.get x i))
            done;
            e)
          bands filters
      in
      let choke_k = exp (-6.9 /. (0.01 *. rate)) in
      for i = 0 to m - 1 do
        if h.alive then begin
          if h.choked then choke := !choke *. choke_k;
          Float.Array.set out (at + i)
            (Float.Array.get out (at + i)
             +. (amp *. !choke *. Float.Array.get mix i));
          incr age;
          (* silent, decided at the sample: the same whatever the blocks *)
          if !choke < 1e-4
             || List.for_all
                  (fun e -> Float.Array.get e (i + 1) < 1e-4) envelopes
          then h.alive <- false
        end
      done
    end
  in
  let h : hit = { who; add = (fun metal out at m -> add metal out at m); alive = true; choked = false } in
  self := Some h;
  h

(*****************************************************************************)
(* The 909's *)
(*****************************************************************************)

let sweep_frequency ~(f_end : float) ~(start : float) ~(tau : float) ~(age : float) : float =
  f_end *. (1. +. ((start -. 1.) *. exp (-.age /. tau)))

(* the 909's kick and toms: a sine whose pitch falls from [start] times
 * [f_end] towards it; its attack a click (a 1 ms pulse, then 3 ms of
 * noise) at [click] *)
(* ix: the sweep's three numbers (f_end, start, tau) are one argument:
 * mini-ml's arm takes seven parameters at most *)
let sweep_drum ~(noise : unit -> float) ~(sweep : float * float * float) ~(t60 : float) ~(click : float) (amp : float)
    (who : instrument) : hit =
  let (f_end, start, tau) = sweep in
  let phase = ref 0. and age = ref 0 in
  let self : hit option ref = ref None in
  let add out at m =
    let h : hit = (match !self with Some h -> h | None -> failwith "hit") in
    for i = at to at + m - 1 do
      if h.alive then begin
        let s = float_of_int !age /. rate in
        let env = decay_env t60 !age in
        phase := Float.rem (!phase +. (sweep_frequency ~f_end ~start ~tau ~age:s /. rate)) 1.;
        let c = if s < 0.001 then click else if s < 0.004 then 0.5 *. click *. noise () else 0. in
        Float.Array.set out i
          (Float.Array.get out i
           +. (amp *. ((env *. sin (2. *. Float.pi *. !phase)) +. c)));
        incr age;
        if env < 1e-4 then h.alive <- false
      end
    done
  in
  let h : hit = { who; add = (fun _ out at m -> add out at m); alive = true; choked = false } in
  self := Some h;
  h

(* 6 bits: 64 levels, -31 to 31 thirty-firsts *)
let bits6 (x : float) : float = Float.round (Float.max (-1.) (Float.min 1. x) *. 31.) /. 31.

(* the 909's cymbals were recordings of real ones; Roland's are
 * Roland's, so ours are made once: [partials] inharmonic struck modes
 * (Modal) between [lo] and [hi] Hz, their decays about [t60], and a
 * hiss, normalized, then quantized to 6 bits -- the ROM *)
let record ~(seed : int) ~(partials : int) ~(lo : float) ~(hi : float) ~(t60 : float) ~(seconds : float) : Signal.t =
  let r = ref seed in
  let uniform () =
    r := Noise.lcg !r;
    0.5 *. (Noise.uniform !r +. 1.)
  in
  let modes =
    List.init partials (fun _ ->
        let m = Modal.create ~frequency:(lo *. Float.pow (hi /. lo) (uniform ())) ~t60:(t60 *. (0.5 +. uniform ())) in
        Modal.strike m (0.5 +. uniform ());
        m)
  in
  let s =
    Array.init (Signal.samples seconds) (fun i ->
        List.fold_left (fun a m -> a +. Modal.next m) 0. modes +. (0.3 *. float_of_int partials *. ((2. *. uniform ()) -. 1.) *. decay_env t60 i /. 10.))
  in
  let peak = Array.fold_left (fun a x -> Float.max a (Float.abs x)) 1e-9 s in
  Array.map (fun x -> bits6 (x /. peak)) s

(* ix: each made when first asked, kept (lazy values there) *)
let made (f : unit -> Signal.t) : unit -> Signal.t =
  let kept = ref None in
  fun () -> match !kept with Some s -> s | None -> let s = f () in kept := Some s; s

let hat_rom = made (fun () -> record ~seed:909 ~partials:40 ~lo:5000. ~hi:14000. ~t60:0.3 ~seconds:0.4)
let crash_rom = made (fun () -> record ~seed:1909 ~partials:60 ~lo:2500. ~hi:13000. ~t60:1.6 ~seconds:2.)
let ride_rom = made (fun () -> record ~seed:2909 ~partials:30 ~lo:2800. ~hi:9000. ~t60:2.5 ~seconds:2.)

let rom (i : instrument) : Signal.t = (match i with CY -> crash_rom | CB -> ride_rom | _ -> hat_rom) ()

(* a sample played from the ROM at [speed] (the tune: faster, higher
 * and shorter), under an envelope; choked, gone in 10 ms *)
let sample_hit ~(rom : unit -> Signal.t) ~(speed : float) ~(t60 : float) (amp : float) (who : instrument) : hit =
  let pos = ref 0. and age = ref 0 and choke = ref 1. in
  let self : hit option ref = ref None in
  let add out at m =
    let h : hit = (match !self with Some h -> h | None -> failwith "hit") in
    let rom = rom () and choke_k = exp (-6.9 /. (0.01 *. rate)) in
    for i = at to at + m - 1 do
      if h.alive then begin
        if h.choked then choke := !choke *. choke_k;
        let env = decay_env t60 !age in
        Float.Array.set out i
          (Float.Array.get out i
           +. (amp *. !choke *. env *. Resample.read Linear rom !pos));
        pos := !pos +. speed;
        incr age;
        if !pos >= float_of_int (Array.length rom - 1) || !choke < 1e-4 || env < 1e-4 then h.alive <- false
      end
    done
  in
  let h : hit = { who; add = (fun _ out at m -> add out at m); alive = true; choked = false } in
  self := Some h;
  h

(* the 909's instruments where they differ from the 808's; its rim shot
 * and clap the 808's (ours) *)
let strike_909 ~(noise : unit -> float) (d : drum) (who : instrument) (amp : float) : hit option =
  let tune base = base *. Float.pow 2. ((d.tuning -. 0.5) *. 0.5) in
  let speed = Float.pow 2. (d.tuning -. 0.5) in
  match who with
  (* the kick: its tune the fall's depth, its "attack" (the tone knob)
   * the click *)
  | BD ->
      Some (sweep_drum ~noise ~sweep:(50., 2. +. (5. *. d.tuning), 0.012) ~t60:(0.2 +. (1.2 *. d.decay)) ~click:d.tone (1.1 *. amp) BD)
  | LT | MT | HT ->
      let f = match who with LT -> 95. | MT -> 140. | _ -> 200. in
      Some (sweep_drum ~noise ~sweep:(tune f, 1.8, 0.04) ~t60:(0.25 +. (0.6 *. d.decay)) ~click:0.1 (0.8 *. amp) who)
  | SD ->
      Some
        (tones_and_noise ~noise
           ~tones:[ (tune 190., 0.12, 0.5); (tune 340., 0.1, 0.3) ]
           ~noise_level:(0.9 *. d.snappy)
           ~filter:(Low_pass, 2000. *. Float.pow 6. d.tone, 0.7)
           ~envelope:(decay_env 0.22) (0.8 *. amp) SD)
  (* the recordings normalized to their peaks, which a few modes in phase
   * make high: their levels raised near the 808's metal's (measured: 10
   * to 15 dB under at first), the crash less, as it lands on the first
   * kick *)
  | CH -> Some (sample_hit ~rom:hat_rom ~speed ~t60:(0.04 +. (0.2 *. d.decay)) (1.5 *. amp) CH)
  | OH -> Some (sample_hit ~rom:hat_rom ~speed ~t60:(0.2 +. d.decay) (1.5 *. amp) OH)
  | CY -> Some (sample_hit ~rom:crash_rom ~speed ~t60:2. (0.9 *. amp) CY)
  | CB -> Some (sample_hit ~rom:ride_rom ~speed ~t60:2.5 (1.3 *. amp) CB)
  | RS | CP -> None

(* an instrument struck at [amp] (its level and the accent counted) *)
let strike ~(noise : unit -> float) (p : patch) (who : instrument) (amp : float) : hit =
  let d = p.drums.(index who) in
  match if p.machine = 1 then strike_909 ~noise d who amp else None with
  | Some h -> h
  | None -> (
  let tones_and_noise = tones_and_noise ~noise in
  let tune base = base *. Float.pow 2. ((d.tuning -. 0.5) *. 0.5) in
  match who with
  | BD -> sine_drum ~f0:49.5 ~t60:(0.15 +. (1.5 *. d.decay)) ~sigh:0.12 ~punch:2.2 ~tone_hz:(200. *. Float.pow 25. d.tone) (1.2 *. amp) BD
  | LT | MT | HT ->
      let f = match who with LT -> 90. | MT -> 130. | _ -> 190. in
      let t60 = match who with LT -> 0.6 | MT -> 0.45 | _ -> 0.35 in
      sine_drum ~f0:(tune f) ~t60 ~sigh:0.08 ~punch:1.6 ~tone_hz:3000. (0.8 *. amp) who
  | SD ->
      tones_and_noise
        ~tones:[ (tune 180., 0.12, 0.5 *. (1. -. d.tone)); (tune 330., 0.1, 0.5 *. d.tone) ]
        ~noise_level:(0.8 *. d.snappy) ~filter:(High_pass, 1800., 0.7)
        ~envelope:(decay_env 0.25) (0.8 *. amp) SD
  | RS -> tones_and_noise ~tones:[ (500., 0.03, 0.6); (1700., 0.02, 0.4) ] ~noise_level:0. ~filter:(High_pass, 1000., 0.7) ~envelope:(fun _ -> 0.) (0.6 *. amp) RS
  | CP ->
      (* three hands 10 ms apart, then the tail *)
      let burst age = List.fold_left (fun s k -> let t = age - Signal.samples k in if t >= 0 then s +. decay_env 0.03 t else s) 0. [ 0.; 0.01; 0.02 ] in
      let envelope age = burst age +. if age >= Signal.samples 0.025 then 0.4 *. decay_env 0.3 (age - Signal.samples 0.025) else 0. in
      tones_and_noise ~tones:[] ~noise_level:1. ~filter:(Band_pass, 1100., 1.2) ~envelope (0.9 *. amp) CP
  | CB ->
      let envelope age = (0.6 *. decay_env 0.04 age) +. (0.4 *. decay_env 0.4 age) in
      metal_hit ~bands:[ ((fun m -> m.bell), 0., 0.7, envelope) ] (0.3 *. amp) CB
  | CH -> metal_hit ~bands:[ ((fun m -> m.high), 6000., 0.7, decay_env 0.07) ] (1.2 *. amp) CH
  | OH -> metal_hit ~bands:[ ((fun m -> m.high), 6000., 0.7, decay_env (0.25 +. d.decay)) ] (1.2 *. amp) OH
  | CY ->
      metal_hit
        ~bands:
          [
            ((fun m -> m.low), 0., 0.7, fun a -> (1. -. d.tone) *. decay_env (0.6 +. (3. *. d.decay)) a);
            ((fun m -> m.high), 0., 0.7, decay_env (0.4 +. (1.5 *. d.decay)));
            ((fun m -> m.high), 10500., 1.5, fun a -> (0.5 +. d.tone) *. decay_env (0.3 +. d.decay) a);
          ]
        (0.6 *. amp) CY)

(*****************************************************************************)
(* Playing it *)
(*****************************************************************************)

(* the six squares, 47.98% duty; the cowbell's the last two *)
let square_hz = [| 205.3; 304.4; 369.6; 522.7; 540.; 800. |]

type t = {
  mutable patch : patch;
  seq : Sequencer.t;
  mutable hits : hit list;
  mutable pending : (instrument * bool) list; (* struck live, at the next block *)
  (* the hits to come, shuffled or flammed later than their step: when
   * (samples from this block's start), what, accented, how loud *)
  mutable scheduled : (int * instrument * bool * float) list;
  squares : Vco.t array;
  bp_low : Svf.t;
  bp_high : Svf.t;
  bp_bell : Svf.t;
  metal : metal;
  mutable random : int; (* the noise's generator *)
  ring : Signal.t;
  mutable at : int;
}

let seq_pattern (p : patch) : Sequencer.step array = Array.init 16 (fun k -> Sequencer.note ~accent:p.accents.(k) ~slide:false k)

let create (patch : patch) : t =
  {
    patch;
    seq = Sequencer.create ~bpm:patch.tempo (seq_pattern patch);
    hits = [];
    pending = [];
    scheduled = [];
    squares = Array.init 6 (fun _ -> Vco.create ());
    bp_low = Svf.create ();
    bp_high = Svf.create ();
    bp_bell = Svf.create ();
    metal =
      { low = Float.Array.make 0 0.; high = Float.Array.make 0 0.;
        bell = Float.Array.make 0 0. };
    random = 1;
    ring = Array.make 2048 0.;
    at = 0;
  }

let patch (t : t) : patch = t.patch

let set_patch (t : t) (p : patch) : unit =
  if p.accents <> t.patch.accents then Sequencer.set_pattern t.seq (seq_pattern p);
  if p.tempo <> t.patch.tempo then Sequencer.set_bpm t.seq p.tempo;
  t.patch <- p

let run (t : t) (on : bool) : unit = if on then Sequencer.start t.seq else Sequencer.stop t.seq
let running (t : t) : bool = Sequencer.running t.seq
let step (t : t) : int = Sequencer.step t.seq
let hit (t : t) (who : instrument) ~(accent : bool) : unit = t.pending <- t.pending @ [ (who, accent) ]
let sounding (t : t) : int = List.length t.hits
let recent (t : t) : Signal.t = Array.init 2048 (fun i -> t.ring.((t.at + i) mod 2048))

(* ix: scale was optional: 1 *)
let start_hit ~(scale : float) (t : t) (who : instrument) (accent : bool) : unit =
  let p = t.patch in
  let amp = scale *. p.drums.(index who).level *. if accent then 1. else 1. -. (0.5 *. p.accent) in
  (* the closed hat stops the open one *)
  if who = CH then List.iter (fun h -> if h.who = OH then h.choked <- true) t.hits;
  (* each hit its own noise, seeded from the voice's generator when
   * struck: how much a hit draws can't change another's *)
  t.random <- Noise.lcg t.random;
  let state = ref t.random in
  let noise () =
    state := Noise.lcg !state;
    Noise.uniform !state
  in
  t.hits <- t.hits @ [ strike ~noise p who amp ]

let is_metal = function CB | CY | OH | CH -> true | _ -> false

(* [m] samples of the squares and their two bands, always: the 808's
 * oscillators run all the time, and a hat struck finds them where they
 * are -- stopped between hits, where they'd be would depend on how the
 * blocks fell *)
let render_metal (t : t) (m : int) : unit =
  let sum = Float.Array.make m 0. and bell = Float.Array.make m 0. in
  let buf = Float.Array.make m 0. in
  let width = Some (Float.Array.make m 0.4798) in
  Array.iteri
    (fun k osc ->
      Vco.fill ~band_limited:true ~width ~sync:None osc Vco.Pulse
        ~frequency:(Float.Array.make m square_hz.(k)) buf;
      for i = 0 to m - 1 do
        Float.Array.set sum i (Float.Array.get sum i +. Float.Array.get buf i)
      done;
      if k >= 4 then
        for i = 0 to m - 1 do
          Float.Array.set bell i
            (Float.Array.get bell i +. Float.Array.get buf i)
        done)
    t.squares;
  let low = Float.Array.copy sum and high = Float.Array.copy sum in
  Svf.process_fixed t.bp_low Zero_delay Band_pass ~cutoff:3440. ~q:1.5 low;
  Svf.process_fixed t.bp_high Zero_delay Band_pass ~cutoff:7100. ~q:1.5 high;
  Svf.process_fixed t.bp_bell Zero_delay Band_pass ~cutoff:800. ~q:0.7 bell;
  t.metal.low <- low;
  t.metal.high <- high;
  t.metal.bell <- bell

let render (t : t) (mono : Float.Array.t) (at : int) (m : int) : unit =
  if m > 0 then begin
    render_metal t m;
    List.iter (fun h -> h.add t.metal mono at m) t.hits;
    t.hits <- List.filter (fun h -> h.alive) t.hits
  end

(* ours: the patterns peaking under 1 (Unit_tr808) *)
let gain = 0.5

(* the shuffle: the even sixteenths (the second, fourth, ...) late, by
 * up to a third of a step (ours); the flam: a step struck twice, the
 * first softer, 10 to 40 ms apart (ours) *)
let shuffle_samples (p : patch) : int = Float.to_int (Float.round (p.shuffle *. Sequencer.samples_per_step p.tempo /. 3.))
let flam_samples (p : patch) : int = Signal.samples (0.01 +. (0.03 *. p.flam))

let fill (t : t) (out : Signal.stereo) : unit =
  let n = Array.length out.left in
  let p = t.patch in
  let mono = Float.Array.make n 0. in
  (* this block's hits: the live ones now, the steps' at their samples,
   * shuffled and flammed, and those scheduled by earlier blocks *)
  let hits = ref (t.scheduled @ List.map (fun (who, accent) -> (0, who, accent, 1.)) t.pending) in
  t.pending <- [];
  if running t then
    Sequencer.advance t.seq n (fun off ev ->
        match ev with
        | Sequencer.Note_on { note = k; accent; _ } ->
            let at = off + if k mod 2 = 1 then shuffle_samples p else 0 in
            List.iter
              (fun i ->
                if p.tracks.(index i).(k) then
                  hits :=
                    !hits @ if p.flams.(k) then [ (at, i, accent, 0.6); (at + flam_samples p, i, accent, 1.) ] else [ (at, i, accent, 1.) ])
              instruments
        | Note_off -> ());
  let now, later = List.partition (fun (at, _, _, _) -> at < n) (List.stable_sort (fun (a, _, _, _) (b, _, _, _) -> compare a b) !hits) in
  t.scheduled <- List.map (fun (at, i, accent, scale) -> (at - n, i, accent, scale)) later;
  let pos = ref 0 in
  List.iter
    (fun (at, i, accent, scale) ->
      render t mono !pos (at - !pos);
      pos := at;
      start_hit ~scale t i accent)
    now;
  render t mono !pos (n - !pos);
  let g = gain *. t.patch.volume in
  for i = 0 to n - 1 do
    (* (one float for the three: by mini-ml each g *. x a new block) *)
    let x = g *. Float.Array.get mono i in
    out.left.(i) <- x;
    out.right.(i) <- x;
    t.ring.(t.at) <- x;
    t.at <- (t.at + 1) mod 2048
  done

let instrument (t : t) : Instrument.t =
  {
    note_on = (fun key velocity -> Option.iter (fun who -> hit t who ~accent:(velocity > 0.8)) (of_key key));
    note_off = (fun _ -> ());
    set = (fun name x -> Option.iter (fun (k : knob) -> set_patch t (k.put t.patch x)) (List.find_opt (fun (k : knob) -> k.name = name) knobs));
    fill = fill t;
  }
