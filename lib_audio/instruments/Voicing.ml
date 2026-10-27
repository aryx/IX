(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Voicing.mli *)

(* ix: the author's playground's libs/audio/instruments/Voicing.ml its optional arguments are said (docs/plans/plan_audio.md) *)

type priority = Low | High | Last
type event = Begin of int | Change of int | End | Nothing

(* the keys held, the last pressed first *)
type t = { priority : priority; retrigger : bool; mutable held : int list }

(* ix: priority (Last) and retrigger (false) were optional *)
let create ~(priority : priority) ~(retrigger : bool) () : t = { priority; retrigger; held = [] }

let sounding (t : t) : int option =
  match (t.held, t.priority) with
  | [], _ -> None
  | last :: _, Last -> Some last
  | keys, Low -> Some (List.fold_left min max_int keys)
  | keys, High -> Some (List.fold_left max min_int keys)

(* from what sounded before to what sounds now *)
let event (t : t) (before : int option) : event =
  match (before, sounding t) with
  | _, None -> if before = None then Nothing else End
  | None, Some n -> Begin n
  | Some b, Some n when b = n -> Nothing
  | Some _, Some n -> if t.retrigger then Begin n else Change n

let press (t : t) (key : int) : event =
  let before = sounding t in
  t.held <- key :: List.filter (( <> ) key) t.held;
  event t before

let release (t : t) (key : int) : event =
  let before = sounding t in
  t.held <- List.filter (( <> ) key) t.held;
  event t before

type glide = { mutable pitch : float; mutable target : float }

(* ix: note was optional: 60 *)
let glide ~(note : float) () : glide = { pitch = note; target = note }
let glide_to (g : glide) (note : int) : unit = g.target <- float_of_int note
let pitch (g : glide) : float = g.pitch
let frequency (pitch : float) : float = 440. *. Float.pow 2. ((pitch -. 69.) /. 12.)

(* ix: out a flat array, the pitch in a variable while it is filled: by
 * mini-ml a float stored in a float array or a mutable float field is
 * a new block and the write barrier (old: out a Signal.t, g.pitch
 * written each sample) *)
let fill_pitch (g : glide) ~(seconds : float) (out : Float.Array.t) : unit =
  let c = if seconds <= 0. then 1. else 1. -. exp (-1. /. (seconds *. float_of_int Signal.rate)) in
  let pitch = ref g.pitch and target = g.target in
  for i = 0 to Float.Array.length out - 1 do
    pitch := !pitch +. ((target -. !pitch) *. c);
    Float.Array.set out i !pitch
  done;
  g.pitch <- !pitch

let fill_frequency (g : glide) ~(seconds : float) (out : Float.Array.t) : unit =
  fill_pitch g ~seconds out;
  for i = 0 to Float.Array.length out - 1 do
    Float.Array.set out i (frequency (Float.Array.get out i))
  done
