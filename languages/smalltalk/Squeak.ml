(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Squeak.mli *)

module M = St_memory
module I = St_interp

type system = Squeak | Quiet | Mini

let width = 800
let height = 600

type t = {
  vm : I.vm;
  (* the world's cycle, when it did not end in its frame's budget *)
  mutable running : I.process option;
  (* St_bitblt.changes when the picture was last taken *)
  mutable drawn : int;
}

(* the first things Smalltalk is told: a Display in colour, a world on
 * it, and what is on the screen when the machine starts. Each is
 * evaluated alone: a method has room for 64 literals. *)
(* (a place or a size is written {x y}, for a Display of 800 by 600:
 * [placed] makes it x @ y in the Display there is) *)
let start_squeak (quiet : bool) : string list = [
  {st|Smalltalk at: #Display put: (Form extent: {800 600} depth: 32).
Smalltalk at: #World put: (PasteUpMorph on: Display)|st};
  {st|| browser |
browser := Browser open.
browser window position: {8 8}; extent: {580 330}.
browser categoryList selectItem: 'Morphic-Basic'.
browser classList selectItem: #EllipseMorph.
browser protocolList selectItem: 'drawing'.
browser selectorList selectItem: #drawOn:|st};
  {st|| workspace return |
return := String with: (Character value: 13).
workspace := Workspace open.
workspace position: {8 346}; extent: {400 246}.
workspace submorphs first contents:
	'"Select a line, the right button: print it"', return,
	'3 + 4 * 2', return,
	'100 factorial printString size', return,
	'(1 to: 10) inject: 0 into: [:a :b | a + b]', return,
	'World color: (Color r: 3/5 g: 4/5 b: 3/5)', return,
	'World hand attachMorph: EllipseMorph new', return,
	'Transcript show: ''Hello, Squeak''; cr', return,
	'World inspect'|st};
  {st|Transcript open position: {416 446}; extent: {376 146}.
Transcript show: 'mini-squeak: everything here is a morph.'; cr.
World addMorph: (PartsBinMorph new position: {594 226}; yourself)|st};
  (* what moves by itself (the world's menu has it too) *)
  (if quiet then "nil" else "World addMorph: (BouncingAtomsMorph new position: {594 36}; yourself)");
  (* the first Etoy: a car, and its script already ticking (quiet: to be clicked) *)
  {st|| car script |
car := CarMorph new.
World addMorph: car.
car position: {610 345}.
script := ScriptEditorMorph on: car.
World addMorph: script.
script position: {416 350}.
script acceptDroppedMorph: (PhraseTileMorph target: car selector: #forward: label: 'forward by' argument: 4).
script acceptDroppedMorph: (PhraseTileMorph target: car selector: #turn: label: 'turn by' argument: 5).
Smalltalk at: #CarScript put: script|st};
  (if quiet then "nil" else "CarScript toggle");
]

(* MiniMorphic's: on the Blue Book's Display; the left button picks a
 * square up *)
let start_mini = [ "Smalltalk at: #World put: (WorldMorph bouncingAtoms: 50)" ]

(* a text's {x y} made the points of a Display of w by h: in proportion *)
let placed ((w, h) : int * int) (text : string) : string =
  let b = Buffer.create (String.length text) in
  let n = String.length text in
  let rec go (i : int) : unit =
    if i < n then
      if text.[i] = '{' then begin
        let close = String.index_from text i '}' in
        (match String.split_on_char ' ' (String.sub text (i + 1) (close - i - 1)) with
         | [ x; y ] -> Buffer.add_string b (Printf.sprintf "%d @ %d" (int_of_string x * w / width) (int_of_string y * h / height))
         | _ -> failwith "Squeak.placed");
        go (close + 1)
      end
      else begin Buffer.add_char b text.[i]; go (i + 1) end in
  go 0;
  Buffer.contents b

let start_sized (system : system) (host : I.host) (size : int * int) : t =
  let kernel, texts =
    match system with
    | Squeak -> (St_kernel.squeak, start_squeak false)
    | Quiet -> (St_kernel.squeak, start_squeak true)
    | Mini -> (St_kernel.mini_morphic, start_mini) in
  let vm = St_boot.boot host kernel in
  List.iter
    (fun (text : string) ->
      match I.evaluate_with vm ~budget:200_000_000 ~receiver:M.nil text with
      | Ok _ -> ()
      | Error e -> host.transcript ("mini-squeak: " ^ e ^ "\n"))
    (List.map (placed size) texts);
  { vm; running = None; drawn = -1 }

let start (system : system) (host : I.host) : t = start_sized system host (width, height)

let resume (host : I.host) (image : string) : t = { vm = St_image.load_vm host image; running = None; drawn = -1 }

let vm (t : t) : I.vm = t.vm

(* bytecodes a frame: a cycle of the world is a few tens of thousands;
 * a long computation is run on over the next frames *)
let budget = 2_000_000

(* a global's value *)
let global (vm : I.vm) (name : string) : M.oop option =
  match St_class.global (I.memory vm) name with Some a -> Some (M.fetch (I.memory vm) a 1) | None -> None

(* why the cycle stopped, said by Smalltalk itself, in its Transcript;
 * by the host if it cannot (MiniMorphic's kernel has no window for it) *)
let report (vm : I.vm) (why : string) : unit =
  let said =
    match global vm "Transcript" with
    | Some transcript -> (
        match I.call vm ~budget transcript "showError:" [ M.new_string (I.memory vm) why ] with Ok _ -> true | Error _ -> false)
    | None -> false in
  if not said then (I.host vm).transcript ("mini-squeak: " ^ why ^ "\n")

let cycle (t : t) ~(interrupt : bool) : unit =
  let p =
    match t.running with
    | Some p -> Some p
    | None -> (match global t.vm "World" with Some w -> Some (I.spawn t.vm w "doOneCycle" []) | None -> None) in
  match p with
  | None -> ()
  | Some p -> (
      if interrupt && t.running <> None then I.suspend p "Interrupted";
      I.run t.vm p ~budget;
      match p.state with
      | I.Runnable -> t.running <- Some p
      | I.Suspended why ->
          I.terminate t.vm p;
          report t.vm why;
          t.running <- None
      | I.Finished _ | I.Terminated -> t.running <- None)

let changed (t : t) : bool =
  let changes = St_bitblt.changes () in
  if changes = t.drawn then false else begin t.drawn <- changes; true end

let pixels (t : t) : (int * int * Bytes.t) option =
  match global t.vm "Display" with Some display -> St_colorblt.rgba (I.memory t.vm) display | None -> None

let bits32 (t : t) : (int * int * int * Bytes.t) option =
  match global t.vm "Display" with Some display -> St_colorblt.bits32 (I.memory t.vm) display | None -> None

let picture (t : t) : (int * int * Bytes.t) option = if changed t then pixels t else None
